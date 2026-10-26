class_name FloatText
extends Node2D
## A little "+5" that rises and fades.

var text := ""
var color := Color.WHITE
var _t := 0.0


func _process(dt: float) -> void:
	_t += dt
	position.y -= 18.0 * dt
	modulate.a = clampf(1.5 - _t, 0.0, 1.0)
	if _t > 1.5:
		queue_free()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-12, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 24, 8, 2, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(-12, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 24, 8, color)
