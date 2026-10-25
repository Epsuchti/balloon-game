extends Station
## Aim with the stick, hold A to fire. Uses the magazine; refill it with an ammo crate from the hold.

const FIRE_DELAY := 0.16
var angle := -PI / 4.0
var _cooldown := 0.0


func _operate(slot: PlayerSlot, dt: float) -> void:
	if slot.aim.length() > 0.3:
		angle = lerp_angle(angle, slot.aim.angle(), minf(1.0, dt * 14.0))
	if slot.pressed(PlayerSlot.Btn.A) and _cooldown <= 0.0:
		if balloon.ammo > 0:
			_cooldown = FIRE_DELAY
			balloon.ammo -= 1
			var dir := Vector2.from_angle(angle)
			if balloon.run != null:
				balloon.run.spawn_bullet(global_position + Vector2(0, -9) + dir * 10.0, dir)
			Sfx.play("shoot", randf_range(0.9, 1.1), -12.0)
		elif slot.just_pressed(PlayerSlot.Btn.A):
			Sfx.play("empty")


func _idle(dt: float) -> void:
	_cooldown -= dt


func accepts(kind: String) -> bool:
	return kind == "ammo"


func _draw_station() -> void:
	var pivot := Vector2(0, -9)
	draw_rect(Rect2(-4, -6, 8, 6), Color("4a5a3a"))
	draw_rect(Rect2(-3, -9, 6, 3), Color("6a7a48"))
	draw_line(pivot, pivot + Vector2.from_angle(angle) * 10.0, Color("2a2a30"), 2.0)
	var fill := float(balloon.ammo) / Balloon.MAGAZINE
	draw_rect(Rect2(-3, -2, 6.0 * fill, 1), Color("f0c030"))
