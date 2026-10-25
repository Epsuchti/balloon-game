class_name SupplyItem
extends Node2D
## A fuel can or ammo crate in the basket. Lies in the hold until someone carries it to the burner or turret.

var kind := "fuel"
var balloon: Balloon
var carrier: CrewMember
var vel := Vector2.ZERO


func tick(dt: float) -> void:
	queue_redraw()
	if carrier != null:
		position = carrier.position + Vector2(0, -11)
		return
	var prev_y := position.y
	vel.y = minf(vel.y + 400.0 * dt, 300.0)
	vel.x = move_toward(vel.x, 0.0, 120.0 * dt)
	position += vel * dt
	position.x = clampf(position.x, -42.0, 42.0)
	if absf(position.x) <= Balloon.DECK_HALF and prev_y <= Balloon.DECK_Y and position.y >= Balloon.DECK_Y:
		position.y = Balloon.DECK_Y
		vel = Vector2.ZERO
	elif position.y >= Balloon.FLOOR_Y:
		position.y = Balloon.FLOOR_Y
		vel = Vector2.ZERO


## True when the tank or magazine this item refills is running low, so the item should call attention.
func needed() -> bool:
	if kind == "fuel":
		return balloon.fuel < Balloon.TANK * 0.35
	return balloon.station_count > Roles.TURRET and balloon.ammo < Balloon.MAGAZINE * 0.25


func _draw() -> void:
	var tex := Art.sprite(kind)
	draw_texture(tex, Vector2(-floorf(tex.get_width() / 2.0), -tex.get_height()))
	if carrier == null and needed() and int(Time.get_ticks_msec() / 250) % 2 == 0:
		var y := -tex.get_height() - 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(-2, y), Vector2(2, y), Vector2(0, y + 2)]), Color("ffe060"))
