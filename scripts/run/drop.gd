class_name Drop
extends Node2D
## An item dropped by an enemy or a broken tile. With a fisher (5+ players) it falls and has to be
## hooked before it hits the ground. With fewer players it floats up to the basket by itself.

var kind := "gold"
var amount := 0
var run: Node
var floating := false
var hooked := false
var vel := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	vel = Vector2(randf_range(-25.0, 25.0), -50.0)


func falling() -> bool:
	return not floating and not hooked


func _physics_process(dt: float) -> void:
	_t += dt
	queue_redraw()
	if hooked:
		return
	var b: Balloon = run.balloon
	if floating:
		var to := b.global_position - global_position
		vel = vel.lerp(to.normalized() * 38.0, minf(1.0, dt * 1.5))
		position += vel * dt
	else:
		vel.y = minf(vel.y + 70.0 * dt, 60.0)
		vel.x = move_toward(vel.x, 0.0, 10.0 * dt)
		position += vel * dt
		if run.terrain.is_solid_at(global_position):
			run.drop_lost(self)
			queue_free()
			return
	if Balloon.BASKET.grow(4.0).has_point(b.local_of(global_position)):
		run.collect(kind, amount, global_position)
		queue_free()
	elif _t > 45.0:
		queue_free()


func _draw() -> void:
	var tex := Art.sprite("nugget" if kind == "gold" and amount <= 3 else kind)
	draw_texture(tex, -(tex.get_size() / 2.0).floor())
	if falling() and int(_t * 6.0) % 2 == 0:
		draw_rect(Rect2(-1, -8, 2, 2), Color(1, 1, 1, 0.8))
