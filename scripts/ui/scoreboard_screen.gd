extends Control
## Every flight so far. Pick one to fly the exact same level again and try to beat it.

const COLS := [["#", 18], ["Team", 120], ["Gold", 40], ["Time", 40], ["Crew", 32], ["Level", 90], ["", 60]]


func _ready() -> void:
	Players.joining_enabled = false
	add_child(Backdrop.new())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var head := UiKit.title("SCOREBOARD", 16)
	box.add_child(head)
	box.add_child(_row(COLS.map(func(c: Array) -> String: return c[0]), Color("c0c0d0")))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var first: Control = null
	var ranked := Scores.ranked()
	for i in ranked.size():
		var e := ranked[i]
		var landed: bool = e.get("landed", false)
		var t := float(e.get("time", 0.0))
		var d := int(e.get("difficulty", 1))
		var s := int(e.get("seed", 0))
		var row := _row([
			str(i + 1), String(e.get("team", "?")),
			str(int(e.get("gold", 0))) if landed else "crash",
			"%d:%02d" % [int(t) / 60, int(t) % 60], str(int(e.get("crew", 1))),
			LevelCode.encode(s, d) + " " + Difficulty.NAMES[d].substr(0, 1), ""],
			Color.WHITE if landed else Color("a09090"))
		var replay := Button.new()
		replay.text = "Replay"
		replay.add_theme_font_size_override("font_size", 8)
		replay.pressed.connect(func() -> void:
			Game.use_level(s, d)
			Game.goto("setup"))
		row.get_child(row.get_child_count() - 1).add_child(replay)
		list.add_child(row)
		if first == null:
			first = replay
	if ranked.is_empty():
		var empty := Label.new()
		empty.text = "No flights yet. Go fly!"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func() -> void: Game.goto("menu"))
	box.add_child(back)
	if first != null:
		first.grab_focus()
	else:
		back.grab_focus()


func _row(cells: Array, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	for i in COLS.size():
		var holder := HBoxContainer.new()
		holder.custom_minimum_size = Vector2(COLS[i][1], 0)
		var l := Label.new()
		l.text = cells[i]
		l.clip_text = true
		l.custom_minimum_size = Vector2(COLS[i][1], 0)
		l.add_theme_color_override("font_color", color)
		if cells[i] != "":
			holder.add_child(l)
		row.add_child(holder)
	return row


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.goto("menu")
