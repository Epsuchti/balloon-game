class_name Pickup
extends Node2D
## A pickup placed in the level by the generator. The balloon collects it by flying through it.

var kind := "gold"
var run: Node
var hooked := false   # on the fishing hook: the rod moves it now
var _base := Vector2.ZERO
var _t := randf() * TAU


func _ready() -> void:
	_base = position


func _physics_process(dt: float) -> void:
	_t += dt
	queue_redraw()
	if hooked:
		return
	position = _base + Vector2(0, roundf(sin(_t * 2.0) * 2.0))
	var b: Balloon = run.balloon
	var local := b.local_of(global_position)
	if b.touches(local, 6.0):
		run.collect(kind, 5 if kind == "gold" else 0, global_position)
		queue_free()
	queue_redraw()


func _draw() -> void:
	var tex := Art.sprite(kind)
	draw_texture(tex, -(tex.get_size() / 2.0).floor())
	if int(_t * 2.0) % 3 == 0:
		draw_rect(Rect2(3, -5, 1, 1), Color.WHITE)
