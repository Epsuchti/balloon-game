class_name Chute
extends Node2D
## A crew member who fell out of the basket, drifting down under a small parachute. The fisher
## can hook them; otherwise they respawn in the basket after a while and the crew loses some gold.

var slot: PlayerSlot
var run: Node
var vel := Vector2.ZERO
var limit := 8.0
var timer := 0.0
var hooked := false
var _frames: Array[Texture2D] = []


func _ready() -> void:
	_frames = Art.crew_frames(slot.color)


func _physics_process(dt: float) -> void:
	queue_redraw()
	if hooked:
		return
	timer += dt
	vel.x = move_toward(vel.x, sin(timer * 1.5) * 12.0, 60.0 * dt)
	vel.y = move_toward(vel.y, 28.0, 120.0 * dt)
	var next := position + vel * dt
	if run.terrain.is_solid_at(next + Vector2(0, 1)):
		vel = Vector2.ZERO
	else:
		position = next
	if timer >= limit:
		run.respawn_chute(self)


func _draw() -> void:
	var c := slot.color
	draw_rect(Rect2(-8, -24, 16, 2), c)
	draw_rect(Rect2(-6, -26, 12, 2), c)
	draw_rect(Rect2(-3, -27, 6, 1), c.lightened(0.3))
	draw_line(Vector2(-8, -22), Vector2(-2, -10), Color(1, 1, 1, 0.6), 1.0)
	draw_line(Vector2(8, -22), Vector2(2, -10), Color(1, 1, 1, 0.6), 1.0)
	draw_texture(_frames[3], Vector2(-3, -10))
	# Time left before they respawn.
	var left := 1.0 - timer / limit
	draw_rect(Rect2(-6, 2, 12, 1), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-6, 2, 12.0 * left, 1), Color.WHITE)
