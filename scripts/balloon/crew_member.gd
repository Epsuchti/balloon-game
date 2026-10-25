class_name CrewMember
extends Node2D
## A player inside the basket, simulated in the basket's local space. Runs and jumps around,
## takes stations (A), leaves them (B), carries supplies, and shoves boarders (X).
## The basket has open edges: jump over a rail and you fall out.

const SPEED := 55.0
const ACCEL := 700.0
const AIR_ACCEL := 350.0
const GRAVITY := 420.0
const JUMP_SPEED := 150.0
const REACH := 7.0
const HALF_W := 3.0

var slot: PlayerSlot
var balloon: Balloon
var vel := Vector2.ZERO
var on_ground := false
var facing := 1
var station: Station
var carrying: SupplyItem
var waving := false
var _frames: Array[Texture2D] = []
var _anim := 0.0
var _drop_through := 0.0
var _shove_anim := 0.0


func _ready() -> void:
	_frames = Art.crew_frames(slot.color)


func tick(dt: float) -> void:
	_anim += dt
	_shove_anim = maxf(0.0, _shove_anim - dt)
	waving = not slot.connected
	if station != null:
		position = station.position
		vel = Vector2.ZERO
		on_ground = true
		if waving or slot.just_pressed(PlayerSlot.Btn.B) or station.blocked_by != null or not station.unlocked:
			leave_station()
		else:
			station.operate(self, dt)
			queue_redraw()
			return
	var input_x := 0.0
	if not waving:
		input_x = slot.move.x
		if slot.just_pressed(PlayerSlot.Btn.A):
			if slot.move.y > 0.6 and _on_deck():
				_drop_through = 0.25  # down + A always drops through the deck
			elif not _interact() and on_ground:
				vel.y = -JUMP_SPEED
				on_ground = false
				Sfx.play("jump", randf_range(0.9, 1.1), -14.0)
		if slot.just_pressed(PlayerSlot.Btn.X):
			_shove()
		if slot.just_pressed(PlayerSlot.Btn.B) and carrying != null:
			drop_carried(false)
	_physics(input_x, dt)
	queue_redraw()


func _physics(input_x: float, dt: float) -> void:
	vel.x = move_toward(vel.x, input_x * SPEED, (ACCEL if on_ground else AIR_ACCEL) * dt)
	if input_x > 0.1:
		facing = 1
	elif input_x < -0.1:
		facing = -1
	vel.y = minf(vel.y + GRAVITY * dt, 300.0)
	_drop_through = maxf(0.0, _drop_through - dt)
	var prev := position
	var inner := Balloon.RAIL_X - HALF_W
	position.x += vel.x * dt
	if absf(prev.x) <= inner + 0.01 and position.y > Balloon.RAIL_TOP and absf(position.x) > inner:
		position.x = signf(position.x) * inner
		vel.x = 0.0
	position.y += vel.y * dt
	on_ground = false
	if vel.y >= 0.0:
		var ax := absf(position.x)
		if ax <= Balloon.DECK_HALF + 2.0 and prev.y <= Balloon.DECK_Y + 0.01 and position.y >= Balloon.DECK_Y and _drop_through <= 0.0:
			_land(Balloon.DECK_Y)
		elif ax > inner and ax < Balloon.RAIL_X + 3.0 + HALF_W and prev.y <= Balloon.RAIL_TOP + 0.01 and position.y >= Balloon.RAIL_TOP:
			_land(Balloon.RAIL_TOP)
		elif ax <= Balloon.RAIL_X + 3.0 and prev.y <= Balloon.FLOOR_Y + 0.01 and position.y >= Balloon.FLOOR_Y:
			_land(Balloon.FLOOR_Y)
	if absf(position.x) - HALF_W > Balloon.RAIL_X + 3.0 or position.y > 40.0:
		balloon.crew_fell(self)


func _land(y: float) -> void:
	position.y = y
	vel.y = 0.0
	on_ground = true


func _on_deck() -> bool:
	return on_ground and absf(position.y - Balloon.DECK_Y) < 0.5


func _near(p: Vector2) -> bool:
	return absf(p.x - position.x) <= REACH and absf(p.y - position.y) <= 3.0


func _interact() -> bool:
	if carrying != null:
		for st in balloon.stations:
			if st.unlocked and _near(st.position) and st.accepts(carrying.kind):
				if balloon.refill(carrying.kind):
					balloon.remove_item(carrying)
					carrying = null
					Sfx.play("refill")
				else:
					Sfx.play("empty")
				return true
		return false
	for st in balloon.stations:
		if st.unlocked and st.operator == null and st.blocked_by == null and _near(st.position):
			take_station(st)
			return true
	for it in balloon.items:
		if it.carrier == null and absf(it.position.x - position.x) <= REACH and absf(it.position.y - position.y) <= 6.0:
			carrying = it
			it.carrier = self
			Sfx.play("pickup")
			return true
	return false


func take_station(st: Station) -> void:
	station = st
	st.operator = self
	position = st.position
	vel = Vector2.ZERO
	Sfx.play("take")


func leave_station() -> void:
	if station != null:
		if slot.connected:
			Sfx.play("leave")
		station.operator = null
		station.on_leave()
		station = null


func drop_carried(lost: bool) -> void:
	if carrying == null:
		return
	carrying.carrier = null
	if lost:
		balloon.remove_item(carrying)
	else:
		carrying.position = position + Vector2(0, -6)
		carrying.vel = Vector2(facing * 30.0, -40.0)
		Sfx.play("drop")
	carrying = null


func knock(impulse: Vector2) -> void:
	if station != null:
		return
	vel += impulse
	on_ground = false


func _shove() -> void:
	_shove_anim = 0.2
	for b in balloon.boarders:
		var d := b.position - (position + Vector2(0, -5))
		if absf(d.x) < 12.0 and absf(d.y) < 14.0:
			var dir := signf(d.x) if absf(d.x) > 0.5 else float(facing)
			balloon.shove_boarder(b, Vector2(dir, -0.6))
			Sfx.play("shove")
			return


func _draw() -> void:
	var f := 0
	if waving:
		f = 4 + int(_anim * 4.0) % 2
	elif station != null:
		f = 6
	elif not on_ground:
		f = 3
	elif absf(vel.x) > 5.0:
		f = 1 + int(_anim * 8.0) % 2
	if _shove_anim > 0.0:
		f = 6
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	draw_texture(_frames[f], Vector2(-3, -10))
	draw_set_transform(Vector2.ZERO)
	if waving:
		# Blinking "!" while their controller is unplugged.
		if int(_anim * 3.0) % 2 == 0:
			draw_rect(Rect2(-0.5, -17, 1, 4), Color.WHITE)
			draw_rect(Rect2(-0.5, -12, 1, 1), Color.WHITE)
	elif station == null:
		# A small marker in the player's color so everyone can find themselves.
		draw_rect(Rect2(-1, -13, 2, 1), slot.color)
