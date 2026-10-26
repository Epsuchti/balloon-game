extends Station
## Hold A (or up) to heat the envelope. Burns fuel; refill the tank with a fuel can from the hold.

var _flame := 0.0
var _was_burning := false


func _operate(slot: PlayerSlot, _dt: float) -> void:
	if slot.pressed(PlayerSlot.Btn.A) or slot.move.y < -0.5:
		balloon.burning = true


func _idle(dt: float) -> void:
	var on := balloon.burning and balloon.fuel > 0.0
	if on and not _was_burning:
		Sfx.play("burn", randf_range(0.9, 1.1), -12.0)
	_was_burning = on
	_flame = move_toward(_flame, 1.0 if on else 0.0, dt * 8.0)


func accepts(kind: String) -> bool:
	return kind == "fuel"


func _draw_station() -> void:
	draw_rect(Rect2(-1, -20, 2, 13), Color("4a4a52"))
	draw_rect(Rect2(-5, -22, 10, 3), Color("70707a"))
	draw_rect(Rect2(-5, -22, 10, 1), Color("9a9aa4"))
	draw_rect(Rect2(-4, -7, 8, 7), Color("b03a2a"))
	draw_rect(Rect2(-4, -7, 8, 1), Color("d05a4a"))
	draw_rect(Rect2(-3, -4, 6.0 * balloon.fuel / Balloon.TANK, 1), Color("f0c030"))
	if _flame > 0.0:
		var h := (6.0 + sin(_t * 30.0) * 1.5) * _flame
		draw_rect(Rect2(-3, -22 - h, 6, h), Color("f07a20"))
		draw_rect(Rect2(-1.5, -22 - h * 0.7, 3, h * 0.7), Color("ffe060"))
