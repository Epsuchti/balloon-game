extends Control
## Title screen: play, enter a level code, scoreboard, quit.

var _code_row: HBoxContainer
var _code_edit: LineEdit
var _error: Label


func _ready() -> void:
	Players.joining_enabled = false
	add_child(Backdrop.new())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)
	var title := UiKit.title("BALLOON CREW", 24)
	box.add_child(title)
	var sub := UiKit.label("Couch co-op ballooning for 1 to 8+ players", 11, UiKit.CREAM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_constant_override("outline_size", 3)
	box.add_child(sub)
	box.add_child(Control.new())
	var play := _button(box, "Play", func() -> void:
		if not Game.fixed_level:
			Game.use_random_level()
		Game.goto("setup"))
	_button(box, "Enter level code", _show_code)
	_code_row = HBoxContainer.new()
	_code_row.visible = false
	box.add_child(_code_row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "N-8F3K2Q"
	_code_edit.custom_minimum_size = Vector2(110, 0)
	_code_edit.max_length = 9
	_code_edit.text_submitted.connect(func(_t: String) -> void: _use_code())
	_code_row.add_child(_code_edit)
	var go := Button.new()
	go.text = "Fly it"
	go.pressed.connect(_use_code)
	_code_row.add_child(go)
	_error = Label.new()
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error.add_theme_color_override("font_color", Color("ff8060"))
	_error.visible = false
	box.add_child(_error)
	_button(box, "Scoreboard", func() -> void: Game.goto("scores"))
	_button(box, "Quit", func() -> void: get_tree().quit())
	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", 3)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(8, -20)
	for part: Array in [["A", "select"], ["stick", "move"], ["key:M", "music"], ["key:F11", "fullscreen"]]:
		hint.add_child(UiKit.Glyph.new(part[0]))
		var l := UiKit.label(part[1] + "   ", 8, UiKit.CREAM)
		l.add_theme_constant_override("outline_size", 3)
		hint.add_child(l)
	add_child(hint)
	add_child(Hero.new())
	play.grab_focus()


func _button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 22)
	b.pressed.connect(cb)
	box.add_child(b)
	return b


func _show_code() -> void:
	_code_row.visible = true
	_code_edit.grab_focus()


func _use_code() -> void:
	if Game.use_level_code(_code_edit.text):
		Game.goto("setup")
	else:
		_error.text = "That code doesn't look right. It's like N-8F3K2Q."
		_error.visible = true


class Hero:
	extends Control
	## A balloon drifting next to the title, and the Grumpus peeking up from the bottom corner.
	var _t := 0.0

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var env := Art.envelope_texture(1.0)
		var basket := Art.basket_back()
		var front := Art.basket_front()
		var p := Vector2(size.x * 0.14, size.y * 0.42 + sin(_t * 1.4) * 5.0).round()
		var s := 0.75
		draw_set_transform(p, sin(_t * 0.9) * 0.04, Vector2(s, s))
		var bottom := Balloon.ENVELOPE_CENTER.y + Balloon.ENVELOPE_RADII.y
		draw_texture(env, Vector2(-floorf(env.get_width() / 2.0), bottom - env.get_height() + 2.0))
		var rope := Color("5a4630")
		for x in [12.0, 6.0]:
			draw_line(Vector2(-x, bottom - 1), Vector2(-x * 3.8, Balloon.BASKET.position.y), rope, 1.0)
			draw_line(Vector2(x, bottom - 1), Vector2(x * 3.8, Balloon.BASKET.position.y), rope, 1.0)
		draw_texture(basket, Balloon.BASKET.position)
		draw_texture(front, Balloon.BASKET.position)
		draw_set_transform(Vector2.ZERO)
		var boss: Array[Texture2D] = Art.boss_frames()
		var peek := clampf(sin(_t * 0.5) * 3.0, 0.0, 1.0)
		var tex: Texture2D = boss[int(_t * 3.0) % 2]
		var bp := Vector2(size.x - 70.0, size.y - 10.0 - peek * 40.0).round()
		draw_texture(tex, bp)
