extends Node2D
## One flight. Builds the level from Game.level_seed + Game.difficulty, spawns the crew and runs
## until the balloon lands, crashes or runs out of fuel. Players can join and leave at any time:
## crew size decides which stations and mechanics are active, and never changes the level itself.

const OUT_OF_FUEL_GRACE := 12.0
const RESPAWN_PENALTY := 5
const NIGHT_COLOR := Color(0.08, 0.08, 0.16)
const ZOOM := 0.9         # a bit more of the cave around the (big) balloon
const ZOOM_OUT := 0.7     # about 22% further out while drops fall
const START_SUPPLIES: Array[String] = ["fuel", "fuel", "ammo"]

var level: LevelData
var terrain: Terrain
var balloon: Balloon
var camera: Camera2D
var hud: Hud
var enemies: Node2D
var bullets: Node2D
var drops: Node2D
var pickups: Node2D
var chutes: Node2D
var effects: Node2D
var gold := 0
var elapsed := 0.0
var max_crew := 0
var cur_segment := 0
var finished := false
var night := 0.0
var out_of_fuel := 0.0
var result := {}

var _enemies_from := 1 << 30   # first segment where enemies may spawn
var _spawned := PackedByteArray()
var _canvas_mod: CanvasModulate
var _background: Sprite2D
var _shake := 0.0
var _zoom := ZOOM
var _paused_menu: Control


func _ready() -> void:
	level = LevelGenerator.generate(Game.level_seed, Game.difficulty)
	_build_world()
	Players.remove_on_disconnect = false
	Players.joining_enabled = true
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	if Players.players.is_empty():
		Players.join(Players.KEYBOARD_1)  # started straight into a run (e.g. from the editor)
	_update_crew_size(true)
	for slot in Players.players:
		if balloon.crew_for(slot) == null:
			balloon.spawn_crew(slot, slot.role)
	for kind in START_SUPPLIES:
		balloon.add_item(kind)


func _exit_tree() -> void:
	if Players.player_joined.is_connected(_on_player_joined):
		Players.player_joined.disconnect(_on_player_joined)
		Players.player_left.disconnect(_on_player_left)


func _build_world() -> void:
	_background = Sprite2D.new()
	_background.texture = Art.cave_wall()
	_background.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_background.region_enabled = true
	_background.centered = false
	_background.z_index = -10
	add_child(_background)

	terrain = Terrain.new()
	terrain.setup(level)
	terrain.tile_broken.connect(_on_tile_broken)
	add_child(terrain)

	_add_wind_visuals()
	_add_platform_flag()

	pickups = _layer("Pickups")
	for p: Dictionary in level.pickups:
		var pk := Pickup.new()
		pk.kind = p["kind"]
		pk.run = self
		pk.position = p["pos"]
		pickups.add_child(pk)
	_spawned.resize(level.spawns.size())

	balloon = Balloon.new()
	balloon.run = self
	balloon.terrain = terrain
	balloon.landing_speed = Difficulty.LANDING_SPEED[level.difficulty]
	balloon.position = level.start_position() - Balloon.CENTER_OFFSET
	balloon.landed.connect(_on_landed)
	balloon.crashed.connect(_on_crashed)
	add_child(balloon)

	enemies = _layer("Enemies")
	drops = _layer("Drops")
	chutes = _layer("Chutes")
	bullets = _layer("Bullets")
	effects = _layer("Effects")

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(level.size_px().x)
	camera.limit_bottom = int(level.size_px().y)
	camera.position = balloon.center()
	add_child(camera)
	camera.make_current()
	camera.reset_smoothing()

	_canvas_mod = CanvasModulate.new()
	add_child(_canvas_mod)

	hud = Hud.new()
	hud.run = self
	add_child(hud)


func _layer(layer_name: String) -> Node2D:
	var n := Node2D.new()
	n.name = layer_name
	add_child(n)
	return n


func _add_wind_visuals() -> void:
	for z: Dictionary in level.wind_zones:
		var rect: Rect2 = z["rect"]
		var force: Vector2 = z["force"]
		var p := CPUParticles2D.new()
		p.position = rect.get_center()
		p.amount = 40
		p.lifetime = 2.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = rect.size / 2.0
		p.direction = force.normalized()
		p.spread = 8.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = force.length() * 2.0
		p.initial_velocity_max = force.length() * 3.0
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.0
		p.color = Color(1, 1, 1, 0.35)
		add_child(p)


func _add_platform_flag() -> void:
	var flag := PlatformFlag.new()
	var r := level.platform_px()
	flag.position = Vector2(r.get_center().x, r.position.y)
	flag.width = r.size.x
	add_child(flag)


# --- Main loop ---

func _physics_process(dt: float) -> void:
	_check_pause()
	if not finished:
		elapsed += dt
	cur_segment = level.segment_at_px(balloon.center().x)
	_activate_spawns()
	_update_night(dt)
	_update_camera(dt)
	if not finished:
		_check_fuel(dt)


func _update_camera(dt: float) -> void:
	var look := (balloon.velocity * 0.6).limit_length(90.0)
	camera.position = balloon.center() + look
	var want := ZOOM
	if max_crew >= 5:
		for d: Drop in drops.get_children():
			if d.falling() or d.hooked:
				want = ZOOM_OUT
		if chutes.get_child_count() > 0:
			want = ZOOM_OUT
	# 20-30% zoom-out over about 0.3 s; overlapping drops share one zoom-out.
	_zoom = move_toward(_zoom, want, dt * (ZOOM - ZOOM_OUT) / 0.3)
	camera.zoom = Vector2(_zoom, _zoom)
	_shake = maxf(0.0, _shake - dt * 30.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	var view := get_viewport_rect().size / _zoom
	var cam_center := camera.get_screen_center_position()
	_background.position = (cam_center - view / 2.0).floor()
	_background.region_rect = Rect2(_background.position * 0.5, view + Vector2(2, 2))
	_background.scale = Vector2.ONE


func _update_night(dt: float) -> void:
	var seg: Dictionary = level.segments[cur_segment]
	var target := 1.0 if max_crew >= 7 and seg["night"] else 0.0
	night = move_toward(night, target, dt / 10.0)  # fades over about 10 s
	_canvas_mod.color = Color.WHITE.lerp(NIGHT_COLOR, night)
	balloon.set_night(night)


func _check_fuel(dt: float) -> void:
	var has_fuel := balloon.fuel > 0.0 or balloon.count_items("fuel") > 0
	if not has_fuel:
		for d: Drop in drops.get_children():
			if d.kind == "fuel":
				has_fuel = true
	_supply_hints()
	if has_fuel:
		out_of_fuel = 0.0
		return
	out_of_fuel += dt
	if out_of_fuel >= OUT_OF_FUEL_GRACE:
		_finish(false, "Out of fuel")


var _hinted := {}


## Tell the crew how to refill, once per tank/magazine running low.
func _supply_hints() -> void:
	var low_fuel := balloon.fuel < Balloon.TANK * 0.35 and balloon.count_items("fuel") > 0
	var low_ammo := balloon.station_count > Roles.TURRET and balloon.ammo < Balloon.MAGAZINE * 0.25 \
		and balloon.count_items("ammo") > 0
	if low_fuel and not _hinted.get("fuel", false):
		hud.message("Fuel low! Pick up a fuel can in the hold (A), carry it to the burner, press A", Color("f08838"))
	if low_ammo and not _hinted.get("ammo", false):
		hud.message("Ammo low! Carry an ammo crate from the hold to the turret and press A", Color("a0c050"))
	_hinted["fuel"] = low_fuel
	_hinted["ammo"] = low_ammo


func _activate_spawns() -> void:
	var bx := balloon.center().x
	for i in level.spawns.size():
		if _spawned[i] == 1:
			continue
		var sp: Dictionary = level.spawns[i]
		var pos: Vector2 = sp["pos"]
		if pos.x - bx > 420.0:
			continue
		_spawned[i] = 1
		if pos.x - bx < -200.0:
			continue
		if max_crew >= 4:
			if sp["segment"] >= _enemies_from:
				spawn_enemy(sp["kind"], pos)
		else:
			# No enemies with fewer than 4 players: their spots hold gold and fuel instead.
			var pk := Pickup.new()
			pk.kind = "fuel" if i % 5 == 0 else "gold"
			pk.run = self
			pk.position = pos
			pickups.add_child(pk)


func wind_at(pos: Vector2) -> Vector2:
	var f := Vector2.ZERO
	for z: Dictionary in level.wind_zones:
		var r: Rect2 = z["rect"]
		if r.has_point(pos):
			f += z["force"]
	return f


# --- Crew ---

func _on_player_joined(slot: PlayerSlot) -> void:
	if finished or balloon.crew_for(slot) != null:
		return
	Sfx.play("join")
	hud.message("%s joined the crew!" % slot.label(), slot.color)
	balloon.spawn_crew(slot, Roles.ROAM)
	_update_crew_size(false)


func _on_player_left(slot: PlayerSlot) -> void:
	balloon.remove_crew(slot)
	for c: Chute in chutes.get_children():
		if c.slot == slot:
			c.queue_free()
	if not finished:
		hud.message("%s left. Their station stays." % slot.label(), slot.color)


func _update_crew_size(initial: bool) -> void:
	var n := Players.players.size()
	if n <= max_crew:
		return
	var old := max_crew
	max_crew = n
	var count := Roles.station_count(max_crew)
	var old_count := Roles.station_count(old) if old > 0 else 0
	balloon.set_station_count(count, not initial)
	balloon.self_heal = max_crew < 6
	if old < 4 and max_crew >= 4:
		_enemies_from = 0 if initial else cur_segment + 1
	if not initial:
		for r in range(old_count, count):
			hud.message("New station: %s! %s" % [Roles.NAMES[r], Roles.UNLOCKS[r]], Color("f0c040"))


func crew_fell(slot: PlayerSlot, pos: Vector2, vel: Vector2) -> void:
	var c := Chute.new()
	c.slot = slot
	c.run = self
	c.position = pos
	c.vel = Vector2(vel.x * 0.5, minf(vel.y, 0.0))
	c.limit = 8.0 if max_crew >= 5 else 3.0
	chutes.add_child(c)
	Sfx.play("fall")
	hud.message("%s fell out!" % slot.label(), slot.color)


func respawn_chute(c: Chute) -> void:
	var lost := mini(gold, RESPAWN_PENALTY)
	gold -= lost
	if lost > 0:
		float_text(balloon.center(), "-%d" % lost, Color("ff6060"))
	if Players.players.has(c.slot) and balloon.crew_for(c.slot) == null:
		balloon.spawn_crew(c.slot)
	c.queue_free()


# --- Fishing ---

## Something the hook can grab near pos: a falling drop or a parachuting crewmate.
func find_catch(pos: Vector2, radius: float) -> Node2D:
	for d: Drop in drops.get_children():
		if d.falling() and d.global_position.distance_to(pos) < radius:
			return d
	for c: Chute in chutes.get_children():
		if not c.hooked and (c.global_position + Vector2(0, -8)).distance_to(pos) < radius + 4.0:
			return c
	return null


func deliver_catch(obj: Node2D) -> void:
	if obj is Drop:
		var d := obj as Drop
		collect(d.kind, d.amount, d.global_position)
		d.queue_free()
	elif obj is Chute:
		var c := obj as Chute
		if Players.players.has(c.slot) and balloon.crew_for(c.slot) == null:
			balloon.spawn_crew(c.slot)
		hud.message("%s was reeled back in!" % c.slot.label(), c.slot.color)
		c.queue_free()


# --- Loot, enemies, effects ---

func collect(kind: String, amount: int, pos: Vector2) -> void:
	match kind:
		"gold":
			gold += amount
			Sfx.play("coin", randf_range(0.95, 1.1))
			float_text(pos, "+%d" % amount, Color("f0c030"))
		"fuel", "ammo":
			balloon.add_item(kind)
			Sfx.play("refill", 1.2)
			float_text(pos, "+" + ("fuel" if kind == "fuel" else "ammo"), Color("a0e0ff"))


func spawn_enemy(kind: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.kind = kind
	e.run = self
	e.position = pos
	enemies.add_child(e)
	return e


func spawn_bullet(pos: Vector2, dir: Vector2) -> void:
	var b := Bullet.new()
	b.run = self
	b.position = pos
	b.vel = dir * Bullet.SPEED + balloon.velocity
	bullets.add_child(b)


func spawn_shoved(kind: String, pos: Vector2, vel: Vector2) -> void:
	var e := spawn_enemy(kind, pos)
	e.shoved(vel)
	enemy_killed(e)


func enemy_killed(e: Enemy) -> void:
	burst(e.global_position, Color("a080c0"), 8)
	var table: Dictionary = Enemy.STATS[e.kind]["drops"]
	var r := randf()
	for kind: String in table:
		r -= table[kind]
		if r <= 0.0:
			spawn_drop(kind, e.global_position, Enemy.STATS[e.kind]["gold"] if kind == "gold" else 0)
			return


func spawn_drop(kind: String, pos: Vector2, amount: int) -> void:
	var d := Drop.new()
	d.kind = kind
	d.amount = amount
	d.run = self
	d.position = pos
	d.floating = max_crew < 5
	drops.add_child(d)


func drop_lost(d: Drop) -> void:
	burst(d.global_position, Color("c0a080"), 5)


func explosion(pos: Vector2, radius: float, damage: float) -> void:
	Sfx.play("boom")
	burst(pos, Color("ffa030"), 24)
	terrain.damage_circle(pos, radius, 20.0)
	var d := pos.distance_to(balloon.center())
	if d < 60.0:
		balloon.take_damage(damage * (1.0 - d / 90.0))
		balloon.knock_crew((balloon.center() - pos).normalized() * 70.0 + Vector2(0, -50))
	_shake = maxf(_shake, 6.0)


func on_balloon_hit(amount: float) -> void:
	_shake = maxf(_shake, minf(6.0, 1.0 + amount * 0.3))
	if amount > 3.0:
		Sfx.play("hit", 0.8)


func _on_tile_broken(cell: Vector2i, mat: int) -> void:
	var pos := terrain.to_global(terrain.map_to_local(cell))
	burst(pos, Art.TILE_COLORS[mat][0], 5)
	Sfx.play("break", randf_range(0.8, 1.2), -16.0)
	# Some broken tiles hold a gold nugget, decided by the level so replays match.
	if mat == Tiles.DIRT or mat == Tiles.STONE:
		var h := hash(Vector3i(cell.x, cell.y, level.level_seed))
		if h % 100 < 7:
			spawn_drop("gold", pos, 3)


func burst(pos: Vector2, color: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.gravity = Vector2(0, 200)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.emitting = true
	p.finished.connect(p.queue_free)
	effects.add_child(p)


func float_text(pos: Vector2, text: String, color: Color) -> void:
	var f := FloatText.new()
	f.text = text
	f.color = color
	f.position = pos
	effects.add_child(f)


# --- End of the run ---

func _on_landed(speed: float) -> void:
	Sfx.play("land")
	burst(balloon.world_of(Vector2(0, 20)), Color("f0c040"), 30)
	_finish(true, "Landed at %d px/s" % roundi(speed))


func _on_crashed(reason: String) -> void:
	Sfx.play("crash")
	burst(balloon.center(), Color("ff6030"), 40)
	_finish(false, reason)


func _finish(landed: bool, reason: String) -> void:
	if finished:
		return
	finished = true
	balloon.frozen = true
	result = Scores.add({
		"team": Game.team_name, "gold": gold if landed else 0, "collected": gold,
		"time": snappedf(elapsed, 0.1), "crew": max_crew, "difficulty": level.difficulty,
		"seed": level.level_seed, "landed": landed, "reason": reason,
	})
	get_tree().create_timer(1.5).timeout.connect(hud.show_results.bind(result))


# --- Pause ---

func _check_pause() -> void:
	if finished or get_tree().paused:
		return
	var want := Input.is_physical_key_pressed(KEY_ESCAPE)
	for slot in Players.players:
		if slot.just_pressed(PlayerSlot.Btn.START):
			want = true
	if want:
		hud.show_pause()


class PlatformFlag:
	extends Node2D
	## Flag pole and stripes on the landing platform.
	var width := 144.0
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var x := width / 2.0 - 10.0
		draw_rect(Rect2(x, -40, 2, 40), Color("d0d0d8"))
		var wave := 1.0 if int(_t * 4.0) % 2 == 0 else 0.0
		for i in 4:
			for j in 3:
				var c := Color.WHITE if (i + j) % 2 == 0 else Color("202020")
				draw_rect(Rect2(x + 2 + i * 3, -40 + j * 3 + (wave if i % 2 == 1 else 0.0), 3, 3), c)
		for i in range(int(-width / 2.0) + 4, int(width / 2.0) - 4, 12):
			draw_rect(Rect2(i, -1, 6, 1), Color("f0c040"))
