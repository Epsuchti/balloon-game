extends Station
## Hold A to patch the hull; it never heals by itself. Patching uses up repair kits: bring kits
## from the hold (Y) to stock the station, each one good for Balloon.KIT_PATCH hull. When this
## station "breaks", the envelope has sprung a leak that wears the hull down until someone fixes it.

const RATE := 10.0
const LEAK := 0.8
var _working := false
var _warned := false


func _operate(slot: PlayerSlot, dt: float) -> void:
	var want := slot.pressed(PlayerSlot.Btn.A) and balloon.hull < Balloon.MAX_HULL
	_working = want and balloon.patches > 0.0
	if _working:
		var amount := minf(RATE * dt, balloon.patches)
		balloon.patches -= amount
		balloon.repair(amount)
	if want and balloon.patches <= 0.0 and not _warned:
		_warned = true
		Sfx.play("empty")
		if balloon.run != null:
			balloon.run.float_text(global_position + Vector2(0, -30), "Need a repair kit!", Color("ff8080"))
	elif not want:
		_warned = false


func accepts(kind: String) -> bool:
	return kind == "kit"


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
	# How many kits' worth of patches are left: one pip per kit, the last one partly used.
	var kits := balloon.patches / Balloon.KIT_PATCH
	for i in int(Balloon.MAX_PATCHES / Balloon.KIT_PATCH):
		var fill := clampf(kits - i, 0.0, 1.0)
		var r := Rect2(-5 + i * 4, -11, 3, 3)
		draw_rect(r, Color(0.1, 0.08, 0.13, 0.8))
		if fill > 0.0:
			draw_rect(Rect2(r.position.x, r.end.y - 3.0 * fill, 3, 3.0 * fill), Color("f0f0f0"))
	if balloon.patches <= 0.0 and int(_t * 3.0) % 2 == 0:
		draw_rect(Rect2(-5, -11, 7, 3), Color(1, 0.3, 0.3, 0.6))
	if _working and int(_t * 12.0) % 2 == 0:
		draw_rect(Rect2(randf_range(-6, 6), randf_range(-14, -8), 1, 1), Color("ffe060"))
