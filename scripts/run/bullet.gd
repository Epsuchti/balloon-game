class_name Bullet
extends Node2D
## A turret shot. Chips away at tiles, hurts enemies and the boss, pops grumble balls and knocks
## boarders out of the basket. Hits are checked along the whole path flown this frame, so fast
## shots can't skip past a target.

const SPEED := 280.0
var vel := Vector2.ZERO
var run: Node
var _life := 1.4


func _physics_process(dt: float) -> void:
	_life -= dt
	if _life <= 0.0:
		queue_free()
		return
	for i in 2:
		var from := global_position
		position += vel * dt * 0.5
		if _hit_target(from, global_position):
			queue_free()
			return
		var t: Terrain = run.terrain
		var cell := t.cell_at(global_position)
		if t.data.is_solid(cell.x, cell.y):
			t.damage_cell(cell, 1.0)
			Sfx.play("ping", randf_range(0.8, 1.3), -20.0)
			run.burst(global_position, Color("c0a080"), 4)
			queue_free()
			return


func _hit_target(from: Vector2, to: Vector2) -> bool:
	var boss: Boss = run.boss
	if boss != null and boss.alive() and _near(boss.global_position, from, to, Boss.RADIUS):
		boss.hit(1)
		return true
	for ball in run.bullets.get_children():
		if ball is Boss.GrumbleBall and _near(ball.global_position, from, to, 6.0):
			ball.shot()
			return true
	for e: Enemy in run.enemies.get_children():
		if not e.dying and _near(e.global_position, from, to, e.radius + 3.0):
			e.hit(1)
			return true
	var b: Balloon = run.balloon
	for bd in b.boarders:
		if _near(bd.global_position + Vector2(0, -6) * Balloon.SCALE, from, to, 6.0 * Balloon.SCALE):
			b.shove_boarder(bd, Vector2(signf(vel.x), -0.5))
			Sfx.play("hit", 1.4, -10.0)
			return true
	return false


func _near(p: Vector2, from: Vector2, to: Vector2, r: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(p, from, to).distance_to(p) < r


func _draw() -> void:
	draw_line(Vector2.ZERO, -vel.normalized() * 4.0, Color("ffe060"), 1.0)
