extends Station
## Hold A (or down) to pull the envelope in: less volume means less lift, so the balloon drops faster.

var _spin := 0.0


func _operate(slot: PlayerSlot, _dt: float) -> void:
	if slot.pressed(PlayerSlot.Btn.A) or slot.move.y > 0.5:
		balloon.shrinking = true


func _idle(dt: float) -> void:
	_spin += dt * (8.0 if balloon.shrinking else (-2.0 if balloon.envelope_size < 1.0 else 0.0))


func _draw_station() -> void:
	var c := Vector2(0, -7)
	draw_line(c, Vector2(0, -26), Color("5a4630"), 1.0)
	draw_rect(Rect2(-4, -11, 8, 8), Color("6a4a2a"))
	draw_rect(Rect2(-3, -10, 6, 6), Color("8a6a3a"))
	for i in 2:
		var a := _spin + i * PI / 2.0
		var d := Vector2(cos(a), sin(a)) * 3.0
		draw_line(c - d, c + d, Color("3a2a1a"), 1.0)
	draw_rect(Rect2(-1, -1, 2, 1), Color("3a2a1a"))
