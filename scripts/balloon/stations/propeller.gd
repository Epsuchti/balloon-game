extends Station
## Each propeller only pushes one way: the one on the right side of the basket pulls the balloon
## right, the one on the left pulls it left. Push the stick that way (or hold A) to spin it. When one
## breaks down, the balloon can't fly that way until it's fixed. Thrust ramps up in Balloon.

var _phase := 0.0
var _whir := 0.0


## +1 for the right propeller, -1 for the left one.
func dir() -> float:
	return 1.0 if role == Roles.PROPELLER else -1.0


func _operate(slot: PlayerSlot, dt: float) -> void:
	var push := maxf(0.0, slot.move.x * dir())
	if slot.pressed(PlayerSlot.Btn.A):
		push = 1.0
	balloon.thrust_input += push * dir()
	_whir -= dt * push
	if _whir <= 0.0 and push > 0.3:
		_whir = 0.12
		Sfx.play("whir", 0.8 + absf(balloon.thrust) * 0.3, -14.0)


func _idle(dt: float) -> void:
	var spin := maxf(0.0, balloon.thrust * dir())
	_phase += 0.0 if broken else dt * spin * 25.0 + dt * 2.0


func _draw_station() -> void:
	var side := dir()
	draw_rect(Rect2(-4, -8, 8, 8), Color("5a5a66"))
	draw_rect(Rect2(-4, -8, 8, 1), Color("8a8a96"))
	# An arrow on the housing: the way this propeller pulls.
	var arrow := Color("f0c030") if not broken else Color("806040")
	draw_rect(Rect2(-2, -5, 3, 1), arrow)
	draw_colored_polygon(PackedVector2Array([Vector2(side * 3.0, -4.5), Vector2(side * 1.0, -6.5), Vector2(side * 1.0, -2.5)]), arrow)
	var hub := Vector2(side * 16.0, -5.0)
	draw_line(Vector2(side * 4.0, -5.0), hub, Color("3a3a44"), 2.0)
	var blade := absf(sin(_phase)) * 6.0 + 1.0
	draw_rect(Rect2(hub.x - 1.0, hub.y - blade, 2, blade * 2.0), Color("c8c8d0"))
	draw_rect(Rect2(hub.x - 1.0, hub.y - 1.0, 2, 2), Color("3a3a44"))
