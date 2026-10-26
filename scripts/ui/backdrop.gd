class_name Backdrop
extends Control
## Sky with drifting clouds, hills and a few balloons, for the menu screens.

var _t := 0.0
var _clouds: Array[Vector3] = []   # x, y, width
var _balloons: Array[Vector4] = [] # x, y, speed, hue


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 7:
		_clouds.append(Vector3(randf() * 700.0, randf_range(20.0, 160.0), randf_range(30.0, 70.0)))
	for i in 5:
		_balloons.append(Vector4(randf() * 640.0, randf_range(40.0, 300.0), randf_range(3.0, 9.0), randf()))


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var bands := 12
	for i in bands:
		var c := Color("6ec3f0").lerp(Color("f6d8a8"), float(i) / bands)
		draw_rect(Rect2(0, h * i / bands, w, h / bands + 1.0), c)
	draw_rect(Rect2(w - 110, 40, 24, 24), Color("fff2b0"))
	for c in _clouds:
		var x := fposmod(c.x + _t * 6.0, w + 120.0) - 100.0
		draw_rect(Rect2(x, c.y, c.z, 8), Color(1, 1, 1, 0.85))
		draw_rect(Rect2(x + c.z * 0.2, c.y - 6, c.z * 0.5, 6), Color(1, 1, 1, 0.85))
	for b in _balloons:
		var y := fposmod(b.y - _t * b.z, h + 60.0) - 30.0
		var x := b.x + sin(_t * 0.5 + b.w * 10.0) * 10.0
		var col := Color.from_hsv(b.w, 0.6, 0.9)
		draw_rect(Rect2(x - 5, y - 6, 10, 8), col)
		draw_rect(Rect2(x - 4, y - 8, 8, 2), col)
		draw_rect(Rect2(x - 3, y + 2, 6, 2), col.darkened(0.2))
		draw_rect(Rect2(x - 2, y + 6, 4, 3), Color("8a5a34"))
	for layer in 2:
		var col := Color("5a8a5a") if layer == 0 else Color("3e6a44")
		var base := h - 50.0 + layer * 25.0
		var step := 4
		for x in range(0, int(w) + step, step):
			var hh := sin(x * 0.012 + layer * 2.0) * 18.0 + sin(x * 0.031 + layer) * 8.0
			draw_rect(Rect2(x, base - hh, step, h - base + hh), col)
