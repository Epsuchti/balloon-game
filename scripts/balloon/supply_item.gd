class_name SupplyItem
extends Node2D
## A fuel can or ammo crate in the basket. Lies in the hold until someone carries it to the burner or turret.

var kind := "fuel"
var balloon: Balloon
var carrier: CrewMember
var vel := Vector2.ZERO


func tick(dt: float) -> void:
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


func _draw() -> void:
	var tex := Art.sprite(kind)
	draw_texture(tex, Vector2(-floorf(tex.get_width() / 2.0), -tex.get_height()))
