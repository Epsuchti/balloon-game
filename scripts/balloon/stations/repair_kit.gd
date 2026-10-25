extends Station
## Hold A to patch the hull; it never heals by itself. When this station "breaks", the envelope
## has sprung a leak that wears the hull down until someone fixes it here.

const RATE := 10.0
const LEAK := 0.8
var _working := false


func _operate(slot: PlayerSlot, dt: float) -> void:
	_working = slot.pressed(PlayerSlot.Btn.A) and balloon.hull < Balloon.MAX_HULL
	if _working:
		balloon.repair(RATE * dt)


func on_leave() -> void:
	_working = false


func _broken(dt: float) -> void:
	balloon.wear(LEAK * dt)


func _idle(_dt: float) -> void:
	if operator == null:
		_working = false


func _draw_station() -> void:
	draw_rect(Rect2(-4, -5, 8, 5), Color("c03030"))
	draw_rect(Rect2(-2, -7, 4, 2), Color("802020"))
	draw_rect(Rect2(-1, -4, 2, 3), Color.WHITE)
	draw_rect(Rect2(-2, -3, 4, 1), Color.WHITE)
	if _working and int(_t * 12.0) % 2 == 0:
		draw_rect(Rect2(randf_range(-6, 6), randf_range(-14, -8), 1, 1), Color("ffe060"))
