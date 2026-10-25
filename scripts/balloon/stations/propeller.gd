extends Station
## Push left/right to spin the propeller. Thrust ramps up over about half a second (in Balloon).
## The second propeller sits on the other side of the basket.

var _phase := 0.0


var _whir := 0.0


func _operate(slot: PlayerSlot, dt: float) -> void:
	balloon.thrust_input += slot.move.x
	_whir -= dt * absf(slot.move.x)
	if _whir <= 0.0 and absf(slot.move.x) > 0.3:
		_whir = 0.12
		Sfx.play("whir", 0.8 + absf(balloon.thrust) * 0.3, -14.0)


func _idle(dt: float) -> void:
	_phase += dt * absf(balloon.thrust) * 25.0 + dt * 2.0


func _draw_station() -> void:
	var side := 1.0 if position.x > 0.0 else -1.0
	draw_rect(Rect2(-4, -8, 8, 8), Color("5a5a66"))
	draw_rect(Rect2(-4, -8, 8, 1), Color("8a8a96"))
	draw_rect(Rect2(-2, -6, 4, 2), Color("f0c030"))
	var hub := Vector2(side * 16.0, -5.0)
	draw_line(Vector2(side * 4.0, -5.0), hub, Color("3a3a44"), 2.0)
	var blade := absf(sin(_phase)) * 6.0 + 1.0
	draw_rect(Rect2(hub.x - 1.0, hub.y - blade, 2, blade * 2.0), Color("c8c8d0"))
	draw_rect(Rect2(hub.x - 1.0, hub.y - 1.0, 2, 2), Color("3a3a44"))
