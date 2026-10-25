extends Station
## Aim with the stick, press A to cast. The hook catches falling drops and parachuting crewmates
## and reels them into the basket. Press A again to reel in early.

enum State { IDLE, OUT, REEL }
const LINE_MAX := 230.0
const CAST_SPEED := 280.0
const REEL_SPEED := 180.0
const CATCH_RADIUS := 12.0

var state := State.IDLE
var angle := PI * 0.7
var hook := Vector2.ZERO          # global
var caught: Node2D = null
var _dir := Vector2.ZERO


func tip() -> Vector2:
	return to_global(Vector2(-24, -14))


func _operate(slot: PlayerSlot, _dt: float) -> void:
	if slot.aim.length() > 0.3:
		angle = slot.aim.angle()
	if slot.just_pressed(PlayerSlot.Btn.A):
		if state == State.IDLE:
			state = State.OUT
			hook = tip()
			_dir = Vector2.from_angle(angle)
			Sfx.play("cast")
		elif state == State.OUT:
			state = State.REEL


func _idle(dt: float) -> void:
	match state:
		State.IDLE:
			hook = tip()
		State.OUT:
			hook += _dir * CAST_SPEED * dt
			var run := balloon.run
			if run != null:
				var c: Node2D = run.find_catch(hook, CATCH_RADIUS)
				if c != null:
					caught = c
					c.set("hooked", true)
					state = State.REEL
					Sfx.play("catch")
				elif run.terrain.is_solid_at(hook):
					state = State.REEL
			if hook.distance_to(tip()) > LINE_MAX or operator == null:
				state = State.REEL
		State.REEL:
			hook = hook.move_toward(tip(), REEL_SPEED * dt)
			if int(_t * 16.0) != int((_t - dt) * 16.0):
				Sfx.play("reel", 1.0, -14.0)
			if caught != null and not is_instance_valid(caught):
				caught = null
			if caught != null:
				caught.global_position = hook
			if hook.distance_to(tip()) < 4.0:
				if caught != null and balloon.run != null:
					balloon.run.deliver_catch(caught)
				caught = null
				state = State.IDLE


func _draw_station() -> void:
	var local_tip := to_local(tip())
	draw_rect(Rect2(-2, -7, 4, 3), Color("6a4a2a"))
	draw_line(Vector2(0, -6), local_tip, Color("8a6a3a"), 1.0)
	if state != State.IDLE:
		var h := to_local(hook)
		draw_line(local_tip, h, Color(0.9, 0.9, 0.9, 0.8), 1.0)
		draw_rect(Rect2(h.x - 1.0, h.y - 1.0, 2, 3), Color("c0c0c8"))
	elif operator != null:
		for i in range(1, 5):
			var p := local_tip + Vector2.from_angle(angle) * i * 6.0
			draw_rect(Rect2(p.x, p.y, 1, 1), Color(1, 1, 1, 0.6))
