class_name Bullet
extends Node2D
## A turret shot. Chips away at tiles and hurts enemies.

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
		position += vel * dt * 0.5
		var t: Terrain = run.terrain
		var cell := t.cell_at(global_position)
		if t.data.is_solid(cell.x, cell.y):
			t.damage_cell(cell, 1.0)
			run.burst(global_position, Color("c0a080"), 4)
			queue_free()
			return
		for e: Enemy in run.enemies.get_children():
			if not e.dying and e.global_position.distance_to(global_position) < e.radius + 2.0:
				e.hit(1)
				queue_free()
				return


func _draw() -> void:
	draw_line(Vector2.ZERO, -vel.normalized() * 4.0, Color("ffe060"), 1.0)
