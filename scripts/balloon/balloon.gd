class_name Balloon
extends CharacterBody2D
## The hot-air balloon. Moves with simple forces (lift, thrust, drag, wind) and owns everything in
## the basket: crew, stations, supplies and boarders, all simulated in the basket's local space.
## Lift = envelope heat x envelope size - gravity.
## Everything inside is laid out in "rig" units and drawn SCALE times bigger; use local_of() to turn a
## world position into rig units.

signal landed(speed: float)
signal crashed(reason: String)
signal wreck_exploded   # the deflated balloon hit the ground (see start_wreck)

const SCALE := 1.5
const BASKET := Rect2(-48, -18, 96, 38)
const ENVELOPE_CENTER := Vector2(0, -64)
const ENVELOPE_RADII := Vector2(44, 36)
const CENTER_OFFSET := Vector2(0, -40) * SCALE  # basket origin -> middle of the balloon's box (world px)
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
const IMPACT_DAMAGE := 1.0    # hull per px/s above that
const MAX_HULL := 100.0
const TANK := 100.0
const MAGAZINE := 40
const BURN_HEAT := 0.4
const BURN_FUEL := 8.0
const COOLING := 0.07
const MAX_ITEMS := 14
const CAN_FUEL := 35.0
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
var rig: Node2D      # holds everything in the basket, scaled by SCALE
var terrain: Terrain
var heat := 0.5
var envelope_size := 1.0
var thrust := 0.0
var hull := MAX_HULL
var fuel := TANK
var ammo := 30
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
var wrecking := false   # deflating and falling after a lost run
var exploded := false
var _deflate := 0.0
var _wreck_t := 0.0
var _smoke: CPUParticles2D
var _black_smoke: CPUParticles2D

var stations: Array[Station] = []
var crew: Array[CrewMember] = []
var items: Array[SupplyItem] = []
var boarders: Array[Boarder] = []

var _envelope_shape: CircleShape2D
var _envelope_box: CollisionShape2D
var _basket_box: CollisionShape2D
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
	_basket_box = box
	var rect := RectangleShape2D.new()
	rect.size = BASKET.size * SCALE
	box.shape = rect
	box.position = BASKET.get_center() * SCALE
	add_child(box)
	_envelope_box = CollisionShape2D.new()
	_envelope_shape = CircleShape2D.new()
	_envelope_box.shape = _envelope_shape
	add_child(_envelope_box)
	_fit_envelope_shape()
	rig = Node2D.new()
	rig.scale = Vector2(SCALE, SCALE)
	add_child(rig)
	for spot: Array in STATION_SPOTS:
		var st: Station = STATION_SCRIPTS[spot[0]].new()
		st.role = spot[0]
		st.position = spot[1]
		st.balloon = self
		rig.add_child(st)
		stations.append(st)
	_front = Front.new()
	_front.z_index = 1
	rig.add_child(_front)
	_glow = PointLight2D.new()
	_glow.texture = Art.glow_texture()
	_glow.texture_scale = 2.2
	_glow.color = Color(1.0, 0.85, 0.6)
	_glow.energy = 0.0
	_glow.position = Vector2(0, -10)
	rig.add_child(_glow)
	_lamp = PointLight2D.new()
	_lamp.texture = Art.cone_texture()
	_lamp.texture_scale = 1.6
	_lamp.color = Color(1.0, 0.95, 0.75)
	_lamp.energy = 0.0
	_lamp.position = stations[Roles.LAMP].position + Vector2(0, -12)
	rig.add_child(_lamp)
	_smoke = _make_smoke(Color(0.75, 0.75, 0.78, 0.55), 10)
	_black_smoke = _make_smoke(Color(0.4, 0.37, 0.4, 0.8), 16)


func _make_smoke(color: Color, amount: int) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 1.8
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(20, 14)
	p.direction = Vector2.UP
	p.spread = 25.0
	p.gravity = Vector2(0, -25)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 20.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	p.position = ENVELOPE_CENTER * SCALE
	add_child(p)
	return p


## Middle of the balloon's bounding box, in world space.
func center() -> Vector2:
	return global_position + CENTER_OFFSET


## How much the drawn envelope is scaled for the current envelope_size (it shrinks to 72%).
func envelope_factor() -> float:
	return lerpf(0.72, 1.0, clampf((envelope_size - 0.6) / 0.4, 0.0, 1.0))


## Centre and radii of the envelope in rig units. The bottom (where the ropes hang) stays put.
func envelope_center() -> Vector2:
	return Vector2(0, ENVELOPE_CENTER.y + ENVELOPE_RADII.y * (1.0 - envelope_factor()))


func envelope_radii() -> Vector2:
	return ENVELOPE_RADII * envelope_factor()


## True if a circle of this radius at a rig-unit position touches the basket or the envelope.
func touches(local: Vector2, radius: float) -> bool:
	if BASKET.grow(radius).has_point(local):
		return true
	return ((local - envelope_center()) / (envelope_radii() + Vector2(radius, radius))).length() <= 1.0


func _fit_envelope_shape() -> void:
	var r := 36.0 * envelope_factor() * SCALE
	if absf(_envelope_shape.radius - r) > 0.25:
		_envelope_shape.radius = r
		_envelope_box.position = envelope_center() * SCALE


## A world position in rig units, to compare with BASKET, ENVELOPE_CENTER and the crew.
func local_of(world_pos: Vector2) -> Vector2:
	return rig.to_local(world_pos)


## A rig-unit position in world space.
func world_of(rig_pos: Vector2) -> Vector2:
	return rig.to_global(rig_pos)


func set_station_count(n: int, animate: bool) -> void:
	station_count = n
	for st in stations:
		st.set_unlocked(st.role < n, animate)


func set_night(amount: float) -> void:
	_night = amount


func _physics_process(dt: float) -> void:
	_time += dt
	_smoke.emitting = not wrecking and hull < MAX_HULL * 0.6
	_black_smoke.emitting = hull < MAX_HULL * 0.3 or wrecking  # the wreck keeps smoking
	if wrecking:
		_wreck(dt)
		queue_redraw()
		return
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
	_lamp.energy = 0.0 if stations[Roles.LAMP].broken else _night * 1.6
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
	_fit_envelope_shape()
	thrust = move_toward(thrust, clampf(thrust_input, -2.0, 2.0), 2.0 * dt)
	var accel := Vector2(thrust * THRUST, GRAVITY - heat * envelope_size * LIFT)
	if run != null:
		accel += run.wind_at(center())
	velocity += accel * dt
	velocity -= velocity * DRAG * dt
	_move(dt)
	since_damage += dt


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
	elif speed > 12.0 and since_damage > 0.3:
		Sfx.play("bump", randf_range(0.9, 1.1), -10.0)
	if speed > 30.0:
		knock_crew(-n * speed * 1.4 + Vector2(0, -40))
	if m == Tiles.DIRT:
		# Ramming dirt slowly digs through it, and costs a little hull.
		terrain.damage_cell(cell, 1.5 * dt + speed * 0.03)
		hull -= 0.8 * dt
		since_damage = 0.0


## After a lost run: the envelope deflates, the balloon drops like a stone and blows up where it
## lands. wreck_exploded fires then (or after a few seconds if it never hits anything).
func start_wreck() -> void:
	if wrecking:
		return
	wrecking = true
	frozen = false
	_wreck_t = 0.0
	for st in stations:
		st.on_leave()
	_envelope_box.set_deferred("disabled", true)  # the limp envelope can't hold us off the ground
	# Rest on the basket's floor boards, not on the margin below them that keeps flights forgiving.
	var wreck_rect := Rect2(BASKET.position.x, BASKET.position.y, BASKET.size.x, FLOOR_Y + 2.0 - BASKET.position.y)
	_basket_box.set_deferred("position", wreck_rect.get_center() * SCALE)
	var shape := RectangleShape2D.new()
	shape.size = wreck_rect.size * SCALE
	_basket_box.set_deferred("shape", shape)
	Sfx.play("fall", 0.6, -4.0)


func _wreck(dt: float) -> void:
	if exploded:
		# The charred wreck settles into whatever the blast left of the ground.
		velocity.y += GRAVITY * 2.0 * dt
		if move_and_collide(velocity * dt) != null:
			velocity = Vector2.ZERO
		return
	_wreck_t += dt
	_deflate = minf(1.0, _deflate + dt / 1.6)
	envelope_size = 1.0
	heat = 0.0
	# The collapsing envelope sheds scraps of fabric as it tears.
	if run != null and _deflate < 0.95 and randf() < dt * 7.0:
		var a := randf() * TAU
		var at := world_of(ENVELOPE_CENTER + Vector2(cos(a) * 30.0, sin(a) * 18.0 + 20.0 * _deflate))
		var out := Vector2(cos(a), sin(a) - 0.5) * randf_range(30.0, 70.0)
		run.spawn_scrap(at, out + velocity * 0.5, Color("d94a3a") if randf() < 0.65 else Color("f3e3c3"), Vector2(3, 2))
	velocity.y += GRAVITY * (1.0 + 3.0 * _deflate) * dt
	velocity.x *= 1.0 - 0.8 * dt
	var col := move_and_collide(velocity * dt)
	if (col != null and _wreck_t > 0.9) or _wreck_t > 6.0:
		_explode()
	elif col != null:
		velocity = Vector2.ZERO  # already on the ground: finish deflating first


func _explode() -> void:
	exploded = true
	_deflate = 1.0
	velocity = Vector2.ZERO
	# The crew are thrown clear; what's left of the balloon stays where it fell, burnt and smoking.
	for c in crew:
		c.visible = false
	for b in boarders:
		b.visible = false
	for it in items:
		it.visible = false
	rig.modulate = Color(0.35, 0.3, 0.3)
	if run != null:
		var at := world_of(Vector2(0, 0))
		run.big_explosion(at)
		for i in 10:
			var v := Vector2.from_angle(randf_range(-PI * 0.9, -PI * 0.1)) * randf_range(80.0, 180.0)
			run.spawn_scrap(at + Vector2(randf_range(-20, 20), randf_range(-8, 4)), v,
					Color("8a5a34") if i % 2 == 0 else Color("5a3a20"), Vector2(6, 2))
		for i in 8:
			var v := Vector2.from_angle(randf_range(-PI, 0.0)) * randf_range(50.0, 140.0)
			run.spawn_scrap(world_of(ENVELOPE_CENTER + Vector2(randf_range(-30, 30), 40)), v,
					Color("d94a3a") if i % 3 else Color("f3e3c3"), Vector2(3, 2))
	Sfx.play("crash")
	wreck_exploded.emit()


func take_damage(amount: float) -> void:
	if frozen or wrecking or amount <= 0.0:
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
	if frozen or wrecking:
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
	rig.add_child(c)
	rig.move_child(_front, -1)
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
	rig.add_child(it)
	rig.move_child(_front, -1)
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
	var side := 1.0 if local_of(from_global).x >= 0.0 else -1.0
	b.position = Vector2(side * 52.0, -10.0)
	rig.add_child(b)
	rig.move_child(_front, -1)
	boarders.append(b)
	Sfx.play("board")


func shove_boarder(b: Boarder, dir: Vector2) -> void:
	boarders.erase(b)
	b.release_station()
	if run != null:
		run.spawn_shoved(b.kind, b.global_position, dir.normalized() * 140.0 + velocity)
	b.queue_free()


# --- Drawing ---

func _draw() -> void:
	var bottom := ENVELOPE_CENTER.y + ENVELOPE_RADII.y
	var tex := Art.envelope_texture(envelope_size)
	var size := tex.get_size()
	var flash := Color(1, 0.5, 0.5) if hit_flash > 0.0 and not wrecking else Color.WHITE
	var wear_tint := lerpf(1.0, 0.7, clampf(1.0 - hull / MAX_HULL, 0.0, 1.0))
	flash = flash * Color(wear_tint, wear_tint, wear_tint)
	if exploded:
		flash = Color(0.3, 0.26, 0.26)
	if _deflate > 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(SCALE, SCALE))
		_draw_collapsing(tex, bottom, flash)
	else:
		draw_set_transform(Vector2(0, bottom * SCALE), 0.0, Vector2(SCALE, SCALE))
		draw_texture(tex, Vector2(-floorf(size.x / 2.0), -size.y + 2.0), flash)
		_draw_tears(size, bottom)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(SCALE, SCALE))
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


## The deflating envelope as a sheet of cloth: the crown falls in onto the mouth, the sides
## billow out and droop over the ropes, and the loose fabric ripples until it lies still.
func _draw_collapsing(tex: Texture2D, bottom: float, tint: Color) -> void:
	const N := 8
	var size := tex.get_size()
	var d := _deflate
	var k := d * d * (3.0 - 2.0 * d)
	var still := 0.0 if exploded else 1.0
	var pts := []
	for j in N + 1:
		var v := float(j) / N  # 0 at the crown, 1 at the mouth
		var row := []
		for i in N + 1:
			var u := float(i) / N
			var p := Vector2((u - 0.5) * size.x, bottom + 2.0 - size.y * (1.0 - v))
			p.y += (1.0 - v) * size.y * 0.78 * k
			p.x += (u - 0.5) * size.x * 0.45 * k * (0.4 + v * 0.6)
			p.y += pow(absf(u - 0.5) * 2.0, 2.0) * 22.0 * k * v
			var wave := k * (1.0 - v) * still
			p.y += sin(_time * 11.0 + u * 7.0) * 3.0 * wave
			p.x += sin(_time * 8.0 + v * 5.0 + u * 3.0) * 2.0 * wave
			row.append(p)
		pts.append(row)
	for j in N:
		for i in N:
			var quad := PackedVector2Array([pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i]])
			var uvs := PackedVector2Array([Vector2(float(i) / N, float(j) / N), Vector2(float(i + 1) / N, float(j) / N),
					Vector2(float(i + 1) / N, float(j + 1) / N), Vector2(float(i) / N, float(j + 1) / N)])
			# Folds catch the light unevenly.
			var shade := 1.0 - k * (0.25 * absf(sin(i * 1.7 + j * 0.9)) + 0.1 * (1.0 - float(j) / N))
			var c := tint * Color(shade, shade, shade)
			draw_polygon(quad, PackedColorArray([c, c, c, c]), uvs, tex)


## Rips and patches on the envelope; more of them the more the hull is damaged.
func _draw_tears(size: Vector2, _bottom: float) -> void:
	var dmg := clampf(1.0 - hull / MAX_HULL, 0.0, 1.0)
	var count := int(dmg * TEARS.size() + 0.3)
	var ink := Color("2a1a1a")
	for i in mini(count, TEARS.size()):
		var t: Vector2 = TEARS[i]
		var p := Vector2(t.x * size.x * 0.4, -size.y * (0.55 - t.y * 0.4)).round()
		if i % 3 == 2:
			# A patch sewn on.
			draw_rect(Rect2(p.x - 2, p.y - 2, 5, 4), Color("c8b48a"))
			draw_rect(Rect2(p.x - 2, p.y - 2, 5, 4), ink, false, 1.0)
		else:
			# A dark rip.
			draw_line(p + Vector2(-2, -1), p + Vector2(0, 1), ink, 1.0)
			draw_line(p + Vector2(0, 1), p + Vector2(2, -1), ink, 1.0)
			draw_rect(Rect2(p.x - 1, p.y - 1, 2, 2), Color(0.1, 0.05, 0.05, 0.8))


const TEARS := [
	Vector2(-0.5, -0.3), Vector2(0.45, 0.1), Vector2(0.0, -0.6), Vector2(-0.3, 0.45),
	Vector2(0.6, -0.4), Vector2(-0.7, 0.05), Vector2(0.25, 0.55), Vector2(-0.1, 0.15),
]


class Front:
	extends Node2D
	## Rails, floor and deck plank, drawn over the crew.
	func _draw() -> void:
		draw_texture(Art.basket_front(), Balloon.BASKET.position)
		# Cracked planks as the hull takes damage.
		var b := get_parent().get_parent() as Balloon
		var dmg := clampf(1.0 - b.hull / Balloon.MAX_HULL, 0.0, 1.0)
		var crack := Color("3a2414")
		var spots := [Vector2(-30, 10), Vector2(20, 13), Vector2(-8, 8), Vector2(36, 9), Vector2(-40, 14)]
		for i in mini(int(dmg * 6.0), spots.size()):
			var p: Vector2 = spots[i]
			draw_line(p, p + Vector2(3, 2), crack, 1.0)
			draw_line(p + Vector2(3, 2), p + Vector2(5, 1), crack, 1.0)
			draw_line(p + Vector2(3, 2), p + Vector2(3, 4), crack, 1.0)
