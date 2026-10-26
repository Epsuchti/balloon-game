class_name Hud
extends CanvasLayer
## In-run HUD: gold, time, hull, fuel, ammo, level progress, messages, plus the pause and results panels.

var run: Node
var _root: Control
var _bars: Control
var _msg: Label
var _msg_time := 0.0
var _warn: Label
var _hint: Label
var _pause: PanelContainer
var _results: PanelContainer
var _queue: Array[Array] = []
var _pause_age := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_bars = Bars.new()
	_bars.run = run
	_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bars)
	_msg = _label(12, HORIZONTAL_ALIGNMENT_CENTER)
	_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_msg.offset_left = -230
	_msg.offset_right = 230
	_msg.offset_top = 56
	_msg.offset_bottom = 96
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warn = _label(16, HORIZONTAL_ALIGNMENT_CENTER)
	_warn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_warn.position = Vector2(-200, -60)
	_warn.size = Vector2(400, 20)
	_warn.add_theme_color_override("font_color", Color("ff6040"))
	_hint = _label(8, HORIZONTAL_ALIGNMENT_RIGHT)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(-306, -14)
	_hint.size = Vector2(300, 12)
	_hint.text = "New player? Press any button to join"
	_hint.modulate.a = 0.7


func _label(font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


func message(text: String, color := Color.WHITE) -> void:
	_queue.append([text, color])


func _process(dt: float) -> void:
	_bars.queue_redraw()
	_msg_time -= dt
	if _msg_time <= 0.0 and not _queue.is_empty():
		var m: Array = _queue.pop_front()
		_msg.text = m[0]
		_msg.add_theme_color_override("font_color", m[1])
		_msg_time = 2.0 + _msg.text.length() * 0.03
	_msg.modulate.a = clampf(_msg_time * 2.0, 0.0, 1.0)
	if run.out_of_fuel > 0.0 and not run.finished:
		_warn.text = "Out of fuel! Find some in %d s" % ceili(run.OUT_OF_FUEL_GRACE - run.out_of_fuel)
	else:
		_warn.text = ""
	if _pause != null:
		_pause_age += dt
		var resume := false
		for slot in Players.players:
			if slot.just_pressed(PlayerSlot.Btn.START):
				resume = true
		if resume and _pause_age > 0.25:
			hide_pause()


func _unhandled_key_input(event: InputEvent) -> void:
	if _pause != null and _pause_age > 0.25 and event is InputEventKey and event.pressed \
			and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		hide_pause()
		get_viewport().set_input_as_handled()


func show_pause() -> void:
	if _pause != null:
		return
	get_tree().paused = true
	Sfx.play("pause")
	_pause_age = 0.0
	_pause = _panel("Paused")
	var box: VBoxContainer = _pause.get_child(0)
	_button(box, "Resume", hide_pause)
	_button(box, "Restart level", func() -> void: Game.goto("run"))
	_button(box, "Quit to menu", func() -> void:
		Players.clear()
		Game.goto("menu"))
	box.get_child(1).grab_focus()


func hide_pause() -> void:
	if _pause != null:
		_pause.queue_free()
		_pause = null
	get_tree().paused = false


func show_results(entry: Dictionary) -> void:
	if _results != null:
		return
	var landed: bool = entry.get("landed", false)
	_results = _panel("Landed!" if landed else String(entry.get("reason", "Crashed")))
	var box: VBoxContainer = _results.get_child(0)
	var stats := Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t := float(entry.get("time", 0.0))
	stats.text = "%s\nGold: %d%s\nTime: %d:%02d   Crew: %d   %s\nLevel code: %s" % [
		Game.team_name, int(entry.get("gold", 0)),
		"" if landed else " (collected %d, a crash scores 0)" % int(entry.get("collected", 0)),
		int(t) / 60, int(t) % 60, int(entry.get("crew", 0)), Difficulty.NAMES[int(entry.get("difficulty", 1))],
		LevelCode.encode(int(entry.get("seed", 0)), int(entry.get("difficulty", 1)))]
	box.add_child(stats)
	var best := Scores.best_for(int(entry.get("seed", 0)), int(entry.get("difficulty", 1)))
	if landed and best == int(entry.get("gold", 0)):
		var nb := Label.new()
		nb.text = "Best score on this level!"
		nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nb.add_theme_color_override("font_color", Color("f0c040"))
		box.add_child(nb)
	var first := _button(box, "Fly this level again", func() -> void: Game.goto("run"))
	_button(box, "New level", func() -> void:
		Game.use_random_level()
		Game.goto("setup"))
	_button(box, "Scoreboard", func() -> void: Game.goto("scores"))
	_button(box, "Menu", func() -> void:
		Players.clear()
		Game.goto("menu"))
	first.grab_focus()


func _panel(title: String) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var head := UiKit.title(title.to_upper(), 14)
	box.add_child(head)
	panel.tree_exiting.connect(center.queue_free)
	return panel


func _button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	box.add_child(b)
	return b


class Bars:
	extends Control
	## Drawn HUD elements: stat bars, progress strip, landing speed readout.
	var run: Node

	func _draw() -> void:
		var b: Balloon = run.balloon
		var font := ThemeDB.fallback_font
		var w := size.x
		# Top-left: gold and time.
		draw_rect(Rect2(4, 4, 118, 50), Color(0.08, 0.06, 0.12, 0.75))
		draw_texture(Art.sprite("gold"), Vector2(9, 9))
		_text(font, Vector2(18, 15), "%d" % run.gold, 12, Color("f0c030"))
		var t: float = run.elapsed
		_text(font, Vector2(70, 15), "%d:%02d" % [int(t) / 60, int(t) % 60], 10, Color.WHITE)
		_bar(Vector2(8, 22), "Hull", b.hull / Balloon.MAX_HULL, Color("e04848"), "+%d" % b.count_items("kit"))
		_bar(Vector2(8, 31), "Fuel", b.fuel / Balloon.TANK, Color("f08838"), "+%d" % b.count_items("fuel"))
		_bar(Vector2(8, 40), "Ammo", float(b.ammo) / Balloon.MAGAZINE, Color("a0c050"), "+%d" % b.count_items("ammo"))
		# Top-center: progress to the landing platform.
		var lvl: LevelData = run.level
		var px := w / 2.0 - 120.0
		draw_rect(Rect2(px, 8, 240, 4), Color(0.08, 0.06, 0.12, 0.75))
		for s in lvl.segments.size():
			var seg: Dictionary = lvl.segments[s]
			if seg["night"] and run.max_crew >= 7:
				draw_rect(Rect2(px + 240.0 * s / lvl.segments.size(), 8, 240.0 / lvl.segments.size(), 4), Color(0.2, 0.2, 0.5, 0.8))
		var prog := clampf(b.center().x / lvl.platform_px().get_center().x, 0.0, 1.0)
		draw_rect(Rect2(px, 8, 240.0 * prog, 4), Color("6ec3f0"))
		draw_rect(Rect2(px + 238, 4, 2, 10), Color("f0c040"))
		draw_rect(Rect2(px + 240.0 * prog - 2.0, 5, 4, 8), Color.WHITE)
		# Boss health under the progress strip.
		var boss: Boss = run.boss
		if is_instance_valid(boss) and boss.alive():
			draw_rect(Rect2(px + 40, 18, 160, 14), Color(0.08, 0.06, 0.12, 0.8))
			draw_rect(Rect2(px + 44, 27, 152, 3), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(px + 44, 27, 152.0 * boss.hp / boss.max_hp, 3), Color("e05050"))
			_text(font, Vector2(px + 44, 25), Boss.NAME, 8, Color("f4f1ea"))
		# Top-right: level and crew.
		draw_rect(Rect2(w - 124, 4, 120, 30), Color(0.08, 0.06, 0.12, 0.75))
		_text(font, Vector2(w - 118, 15), "%s  %s" % [LevelCode.encode(lvl.level_seed, lvl.difficulty), Difficulty.NAMES[lvl.difficulty]], 8, Color.WHITE)
		var broken := 0
		for st in b.stations:
			if st.broken:
				broken += 1
		_text(font, Vector2(w - 118, 27), "Crew %d" % Players.players.size(), 8, Color("c0c0d0"))
		if broken > 0:
			_text(font, Vector2(w - 70, 27), "%d broken!" % broken, 8, Color("ff7050"))
		# Landing speed when close to the platform.
		var plat := lvl.platform_px()
		if absf(b.center().x - plat.get_center().x) < 260.0 and not run.finished:
			var vs := maxf(0.0, b.velocity.y)
			var ok := vs <= b.landing_speed
			_text(font, Vector2(w / 2.0 - 60.0, size.y - 20.0), "Descent %d / max %d" % [roundi(vs), roundi(b.landing_speed)],
				12, Color("80f080") if ok else Color("ff6060"))

	func _bar(pos: Vector2, label: String, fill: float, color: Color, extra := "") -> void:
		var font := ThemeDB.fallback_font
		_text(font, pos + Vector2(0, 7), label, 8, Color("c0c0d0"))
		draw_rect(Rect2(pos.x + 30, pos.y + 1, 60, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(pos.x + 30, pos.y + 1, 60.0 * clampf(fill, 0.0, 1.0), 6), color)
		if extra != "":
			_text(font, pos + Vector2(94, 7), extra, 8, Color.WHITE)

	func _text(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, Color(0, 0, 0, 0.8))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
