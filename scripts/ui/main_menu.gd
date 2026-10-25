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
	var title := Label.new()
	title.text = "Balloon Crew"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Couch co-op ballooning for 1 to 8+ players"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	box.add_child(_error)
	_button(box, "Scoreboard", func() -> void: Game.goto("scores"))
	_button(box, "Quit", func() -> void: get_tree().quit())
	var hint := Label.new()
	hint.text = "Gamepads: A to select. Keyboard: arrows + Enter."
	hint.add_theme_font_size_override("font_size", 8)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(8, -16)
	add_child(hint)
	play.grab_focus()


func _button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 0)
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
