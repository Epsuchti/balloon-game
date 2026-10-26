class_name Pickup
extends Node2D
## A pickup placed in the level by the generator, lying on the ground or stuck to the ceiling
## (see Run.place_pickup). The fishing rod hooks it; the balloon can also scrape it up by flying into it.

var kind := "gold"
var run: Node
var hooked := false   # on the fishing hook: the rod moves it now
var on_ceiling := false  # stuck to the ceiling (drawn upside down) instead of lying on the ground
var _t := randf() * TAU


func _physics_process(dt: float) -> void:
	_t += dt
	queue_redraw()
	if hooked:
		return
	var b: Balloon = run.balloon
	var local := b.local_of(global_position)
	if b.touches(local, 6.0) or Balloon.BASKET.grow(3.0).has_point(local):
		run.collect(kind, 5 if kind == "gold" else 0, global_position)
		queue_free()


func _draw() -> void:
	var tex := Art.sprite(kind)
	if on_ceiling and not hooked:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, -1))
	draw_texture(tex, -(tex.get_size() / 2.0).floor())
	if int(_t * 2.0) % 3 == 0:
		draw_rect(Rect2(3, -5, 1, 1), Color.WHITE)
