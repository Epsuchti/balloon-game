class_name Balloon
extends CharacterBody2D
## The hot-air balloon. Moves with simple forces (lift, thrust, drag, wind) and owns everything in
## the basket: crew, stations, supplies and boarders, all simulated in the basket's local space.
## Lift = envelope heat x envelope size - gravity.

signal landed(speed: float)
signal crashed(reason: String)

const BASKET := Rect2(-48, -18, 96, 38)
const ENVELOPE_CENTER := Vector2(0, -64)
const ENVELOPE_RADII := Vector2(44, 36)
const CENTER_OFFSET := Vector2(0, -40)  # basket origin -> middle of the balloon's 96x120 box
const FLOOR_Y := 16.0
const DECK_Y := -2.0
const DECK_HALF := 36.0
const RAIL_TOP := 4.0
const RAIL_X := 45.0      # inner face of the rails; rails are 3 px thick
const HOLD_X := 9.0

const GRAVITY := 60.0
const LIFT := 120.0
const DRAG := 0.8
const THRUST := 50.0
const RESTITUTION := 0.35
const SAFE_IMPACT := 28.0     # px/s; slower bumps do no damage
const IMPACT_DAMAGE := 0.5    # hull per px/s above that
const MAX_HULL := 100.0
const TANK := 100.0
const MAGAZINE := 40
const BURN_HEAT := 0.4
const BURN_FUEL := 7.0
const COOLING := 0.07
const MAX_ITEMS := 14
const CAN_FUEL := 50.0
const CRATE_AMMO := 20

const STATION_SPOTS := [
	[Roles.BURNER, Vector2(0, DECK_Y)],
	[Roles.SHRINKER, Vector2(-15, DECK_Y)],
	[Roles.PROPELLER, Vector2(38, FLOOR_Y)],
	[Roles.TURRET, Vector2(17, DECK_Y)],
	[Roles.FISHING, Vector2(-24, FLOOR_Y)],
	[Roles.REPAIR, Vector2(24, FLOOR_Y)],
	[Roles.LAMP, Vector2(-30, DECK_Y)],
	[Roles.PROPELLER2, Vector2(-38, FLOOR_Y)],
]
const STATION_SCRIPTS := {
	Roles.BURNER: preload("res://scripts/balloon/stations/burner.gd"),
	Roles.SHRINKER: preload("res://scripts/balloon/stations/shrinker.gd"),
	Roles.PROPELLER: preload("res://scripts/balloon/stations/propeller.gd"),
	Roles.TURRET: preload("res://scripts/balloon/stations/turret.gd"),
	Roles.FISHING: preload("res://scripts/balloon/stations/fishing_rod.gd"),
	Roles.REPAIR: preload("res://scripts/balloon/stations/repair_kit.gd"),
	Roles.LAMP: preload("res://scripts/balloon/stations/lamp.gd"),
	Roles.PROPELLER2: preload("res://scripts/balloon/stations/propeller.gd"),
}

var run: Node        # the Run that owns this flight
var terrain: Terrain
var heat := 0.5
var envelope_size := 1.0
var thrust := 0.0
var hull := MAX_HULL
var fuel := TANK
var ammo := 30
var self_heal := true
var frozen := false
var landing_speed := 40.0
var lamp_angle := 0.0
var station_count := 0
# Set by stations every frame.
var burning := false
var shrinking := false
var thrust_input := 0.0
var since_damage := 10.0
var hit_flash := 0.0

var stations: Array[Station] = []
var crew: Array[CrewMember] = []
var items: Array[SupplyItem] = []
var boarders: Array[Boarder] = []

var _front: Node2D
var _glow: PointLight2D
var _lamp: PointLight2D
var _night := 0.0
var _time := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var box := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BASKET.size
	box.shape = rect
	box.position = BASKET.get_center()
	add_child(box)
	var env := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 36.0
	env.shape = circle
	env.position = ENVELOPE_CENTER
	add_child(env)
	for spot: Array in STATION_SPOTS:
		var st: Station = STATION_SCRIPTS[spot[0]].new()
		st.role = spot[0]
		st.position = spot[1]
		st.balloon = self
		add_child(st)
		stations.append(st)
	_front = Front.new()
	_front.z_index = 1
	add_child(_front)
	_glow = PointLight2D.new()
	_glow.texture = Art.glow_texture()
	_glow.texture_scale = 2.2
	_glow.color = Color(1.0, 0.85, 0.6)
	_glow.energy = 0.0
	_glow.position = Vector2(0, -10)
	add_child(_glow)
	_lamp = PointLight2D.new()
	_lamp.texture = Art.cone_texture()
	_lamp.texture_scale = 1.6
	_lamp.color = Color(1.0, 0.95, 0.75)
	_lamp.energy = 0.0
	_lamp.position = stations[Roles.LAMP].position + Vector2(0, -12)
	add_child(_lamp)


## Middle of the balloon's bounding box, in world space.
func center() -> Vector2:
	return global_position + CENTER_OFFSET


func set_station_count(n: int, animate: bool) -> void:
	station_count = n
	for st in stations:
		st.set_unlocked(st.role < n, animate)


func set_night(amount: float) -> void:
	_night = amount


func _physics_process(dt: float) -> void:
	_time += dt
	burning = false
	shrinking = false
	thrust_input = 0.0
	hit_flash = maxf(0.0, hit_flash - dt)
	if not frozen:
		for c in crew.duplicate():
			c.tick(dt)
		for b in boarders.duplicate():
			b.tick(dt)
	for st in stations:
		st.tick(dt)
	for it in items.duplicate():
		it.tick(dt)
	_simulate(dt)
	_glow.energy = _night * 0.9 + (0.3 * _night if burning else 0.0)
	_lamp.enabled = station_count > Roles.LAMP
	_lamp.energy = _night * 1.6
	_lamp.rotation = lamp_angle
	queue_redraw()


func _simulate(dt: float) -> void:
	if frozen:
		velocity = Vector2.ZERO
		return
	if burning and fuel > 0.0:
		heat = minf(1.0, heat + BURN_HEAT * dt)
		fuel = maxf(0.0, fuel - BURN_FUEL * dt)
	heat = maxf(0.0, heat - heat * COOLING * dt)
	envelope_size = move_toward(envelope_size, 0.6 if shrinking else 1.0, (0.5 if shrinking else 0.25) * dt)
	thrust = move_toward(thrust, clampf(thrust_input, -2.0, 2.0), 2.0 * dt)
	var accel := Vector2(thrust * THRUST, GRAVITY - heat * envelope_size * LIFT)
	if run != null:
		accel += run.wind_at(center())
	velocity += accel * dt
	velocity -= velocity * DRAG * dt
	_move(dt)
	since_damage += dt
	if self_heal and since_damage > 3.0:
		hull = minf(MAX_HULL, hull + 1.5 * dt)


func _move(dt: float) -> void:
	var motion := velocity * dt
	for i in 3:
		var col := move_and_collide(motion)
		if col == null:
			break
		var n := col.get_normal()
		var vn := velocity.dot(n)
		if vn < 0.0:
			_impact(col, n, -vn, dt)
			if frozen:
				return
			velocity -= (1.0 + RESTITUTION) * vn * n
			velocity -= velocity.project(n.orthogonal()) * 0.1
		motion = col.get_remainder().slide(n)


func _impact(col: KinematicCollision2D, n: Vector2, speed: float, dt: float) -> void:
	if terrain == null:
		return
	var cell := terrain.cell_at(col.get_position() - n * 2.0)
	var m := terrain.material_at(cell)
	if m == Tiles.PLATFORM and n.y < -0.6:
		frozen = true
		velocity = Vector2.ZERO
		if speed <= landing_speed:
			landed.emit(speed)
		else:
			crashed.emit("Crash landing")
		return
	if speed > SAFE_IMPACT:
		take_damage((speed - SAFE_IMPACT) * IMPACT_DAMAGE)
	if speed > 30.0:
		knock_crew(-n * speed * 1.4 + Vector2(0, -40))
	if m == Tiles.DIRT:
		# Ramming dirt slowly digs through it, and costs a little hull.
		terrain.damage_cell(cell, 1.5 * dt + speed * 0.03)
		hull -= 0.8 * dt
		since_damage = 0.0


func take_damage(amount: float) -> void:
	if frozen or amount <= 0.0:
		return
	hull -= amount
	since_damage = 0.0
	hit_flash = 0.15
	if run != null:
		run.on_balloon_hit(amount)
	if hull <= 0.0:
		hull = 0.0
		frozen = true
		crashed.emit("Balloon destroyed")


## Small, steady damage (a pecking harpy) without the hit effects.
func wear(amount: float) -> void:
	if frozen:
		return
	hull -= amount
	since_damage = 0.0
	if hull <= 0.0:
		hull = 0.0
		frozen = true
		crashed.emit("Balloon destroyed")


func repair(amount: float) -> void:
	hull = minf(MAX_HULL, hull + amount)


func knock_crew(impulse: Vector2) -> void:
	for c in crew:
		c.knock(impulse * randf_range(0.7, 1.2))


# --- Crew ---

func spawn_crew(slot: PlayerSlot, role := Roles.ROAM) -> CrewMember:
	var c := CrewMember.new()
	c.slot = slot
	c.balloon = self
	c.position = Vector2(randf_range(-HOLD_X, HOLD_X), FLOOR_Y)
	add_child(c)
	move_child(_front, -1)
	crew.append(c)
	if role >= 0 and role < station_count:
		var st := stations[role]
		if st.operator == null and st.blocked_by == null:
			c.take_station(st)
	return c


func crew_for(slot: PlayerSlot) -> CrewMember:
	for c in crew:
		if c.slot == slot:
			return c
	return null


func remove_crew(slot: PlayerSlot) -> void:
	var c := crew_for(slot)
	if c == null:
		return
	c.leave_station()
	c.drop_carried(false)
	crew.erase(c)
	c.queue_free()


func crew_fell(c: CrewMember) -> void:
	c.leave_station()
	c.drop_carried(true)
	crew.erase(c)
	if run != null:
		run.crew_fell(c.slot, c.global_position, c.vel + velocity)
	c.queue_free()


# --- Supplies ---

func add_item(kind: String) -> void:
	if items.size() >= MAX_ITEMS:
		refill(kind)
		return
	var it := SupplyItem.new()
	it.kind = kind
	it.balloon = self
	it.position = Vector2(randf_range(-HOLD_X + 2.0, HOLD_X - 2.0), FLOOR_Y - 12.0)
	add_child(it)
	move_child(_front, -1)
	items.append(it)


func remove_item(it: SupplyItem) -> void:
	items.erase(it)
	it.queue_free()


func count_items(kind: String) -> int:
	var n := 0
	for it in items:
		if it.kind == kind:
			n += 1
	return n


## Puts a fuel can or ammo crate into the tank/magazine. Returns false if it's already full.
func refill(kind: String) -> bool:
	if kind == "fuel":
		if fuel >= TANK - 1.0:
			return false
		fuel = minf(TANK, fuel + CAN_FUEL)
		return true
	if kind == "ammo":
		if ammo >= MAGAZINE:
			return false
		ammo = mini(MAGAZINE, ammo + CRATE_AMMO)
		return true
	return false


# --- Boarders ---

func add_boarder(kind: String, from_global: Vector2) -> void:
	var b := Boarder.new()
	b.kind = kind
	b.balloon = self
	var side := 1.0 if to_local(from_global).x >= 0.0 else -1.0
	b.position = Vector2(side * 52.0, -10.0)
	add_child(b)
	move_child(_front, -1)
	boarders.append(b)


func shove_boarder(b: Boarder, dir: Vector2) -> void:
	boarders.erase(b)
	b.release_station()
	if run != null:
		run.spawn_shoved(b.kind, b.global_position, dir.normalized() * 140.0 + velocity)
	b.queue_free()


# --- Drawing ---

func _draw() -> void:
	var tex := Art.envelope_texture(envelope_size)
	var size := tex.get_size()
	var bottom := ENVELOPE_CENTER.y + ENVELOPE_RADII.y
	var flash := Color(1, 0.5, 0.5) if hit_flash > 0.0 else Color.WHITE
	draw_texture(tex, Vector2(-floorf(size.x / 2.0), bottom - size.y + 2.0), flash)
	var rope := Color("5a4630")
	var mouth := bottom - 1.0
	draw_line(Vector2(-12, mouth), Vector2(-46, BASKET.position.y), rope, 1.0)
	draw_line(Vector2(12, mouth), Vector2(46, BASKET.position.y), rope, 1.0)
	draw_line(Vector2(-6, mouth), Vector2(-22, BASKET.position.y), rope, 1.0)
	draw_line(Vector2(6, mouth), Vector2(22, BASKET.position.y), rope, 1.0)
	draw_texture(Art.basket_back(), BASKET.position)
	# Gold piles up in the hold.
	var coins := mini(run.gold / 5 if run != null else 0, 14)
	for i in coins:
		var cx := -8.0 + (i % 7) * 2.5
		var cy := FLOOR_Y - 2.0 - int(i / 7) * 2.0
		draw_rect(Rect2(cx, cy, 2, 2), Color("f0c030"))


class Front:
	extends Node2D
	## Rails, floor and deck plank, drawn over the crew.
	func _draw() -> void:
		draw_texture(Art.basket_front(), Balloon.BASKET.position)
