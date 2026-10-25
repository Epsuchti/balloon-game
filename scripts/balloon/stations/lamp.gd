extends Station
## Aim the flashlight cone with the stick. Night sections are dark without it.


func _operate(slot: PlayerSlot, dt: float) -> void:
	if slot.aim.length() > 0.3:
		balloon.lamp_angle = lerp_angle(balloon.lamp_angle, slot.aim.angle(), minf(1.0, dt * 10.0))


func _draw_station() -> void:
	draw_rect(Rect2(-1, -16, 2, 10), Color("4a4a52"))
	var head := Vector2(0, -12) + Vector2.from_angle(balloon.lamp_angle) * 2.0
	draw_rect(Rect2(head.x - 2.0, head.y - 2.0, 5, 4), Color("f0d060"))
	draw_rect(Rect2(head.x - 1.0, head.y - 1.0, 3, 2), Color("fff8c0"))
