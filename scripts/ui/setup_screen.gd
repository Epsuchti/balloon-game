extends Control
## Crew setup. Any button on a controller joins; each player picks a starting station with the
## shoulder buttons while popping balloons with their own crosshair. Everyone presses Start to go,
## or one player holds Start for a countdown.

const HOLD_TO_LEAVE := 1.0
const HOLD_TO_START := 1.0
const COUNTDOWN := 3.0
const CROSSHAIR_SPEED := 220.0

var _cards: HBoxContainer
var _info: Label
var _status: Label
var _team: LineEdit
var _overlay: MiniGame
var _countdown := -1.0
var _starting := false
var _age := 0.0


func _ready() -> void:
	add_child(Backdrop.new())
	Players.remove_on_disconnect = true
	Players.joining_enabled = true
	Players.player_joined.connect(_on_joined)
	Players.player_left.connect(_on_left)
	for slot in Players.players:
		slot.ready = false

	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 8
	add_child(top)
	var title := Label.new()
	title.text = "Join the crew!"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(title)
	var team_row := HBoxContainer.new()
	team_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(team_row)
	var tl := Label.new()
	tl.text = "Team:"
	team_row.add_child(tl)
	_team = LineEdit.new()
	_team.text = Game.team_name
	_team.custom_minimum_size = Vector2(140, 0)
	_team.max_length = 24
	_team.focus_mode = Control.FOCUS_CLICK
	_team.text_changed.connect(func(t: String) -> void: Game.team_name = t)
	_team.text_submitted.connect(func(_t: String) -> void: _team.release_focus())
	team_row.add_child(_team)
	var reroll := Button.new()
	reroll.text = "Random name"
	reroll.focus_mode = Control.FOCUS_NONE
	reroll.pressed.connect(func() -> void:
		Game.team_name = Game.random_team_name()
		_team.text = Game.team_name)
	team_row.add_child(reroll)
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_info)

	_overlay = MiniGame.new()
	_overlay.screen = self
	add_child(_overlay)

	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 4)
	_cards.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_cards.offset_top = -112
	_cards.offset_bottom = -40
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_top = -36
	_status.offset_bottom = -22
	_status.add_theme_font_size_override("font_size", 12)
	add_child(_status)
	var help := Label.new()
	help.text = "Any button: join   LB/RB: pick station   A: pop balloons   Y: random stations   " \
		+ "Back: difficulty   hold B: leave   Start: ready (hold to start now)   Esc: menu"
	help.add_theme_font_size_override("font_size", 7)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -16
	help.offset_bottom = -4
	add_child(help)
	_rebuild_cards()


func _exit_tree() -> void:
	Players.player_joined.disconnect(_on_joined)
	Players.player_left.disconnect(_on_left)
	Players.remove_on_disconnect = false


func _on_joined(slot: PlayerSlot) -> void:
	Sfx.play("join")
	slot.role = _first_free_role(slot)
	_overlay.crosshairs[slot.id] = Vector2(120 + randf() * 400.0, 160 + randf() * 40.0)
	_rebuild_cards()


func _on_left(slot: PlayerSlot) -> void:
	_overlay.crosshairs.erase(slot.id)
	_fix_roles()
	_rebuild_cards()


func _station_count() -> int:
	return Roles.station_count(Players.players.size())


func _role_taken(role: int, by: PlayerSlot) -> bool:
	if role < 0:
		return false
	for s in Players.players:
		if s != by and s.role == role:
			return true
	return false


func _first_free_role(slot: PlayerSlot) -> int:
	for r in _station_count():
		if not _role_taken(r, slot):
			return r
	return Roles.ROAM


func _fix_roles() -> void:
	for s in Players.players:
		if s.role >= _station_count():
			s.role = _first_free_role(s)


func _cycle_role(slot: PlayerSlot, dir: int) -> void:
	var options: Array[int] = [Roles.ROAM]
	for r in _station_count():
		options.append(r)
	var i := options.find(slot.role)
	for step in options.size():
		i = (i + dir + options.size()) % options.size()
		if not _role_taken(options[i], slot):
			slot.role = options[i]
			Sfx.play("tick")
			return


func _random_roles() -> void:
	var roles: Array[int] = []
	for r in _station_count():
		roles.append(r)
	roles.shuffle()
	var order := Players.players.duplicate()
	order.shuffle()
	for i in order.size():
		order[i].role = roles[i] if i < roles.size() else Roles.ROAM
	Sfx.play("unlock")


func _physics_process(dt: float) -> void:
	_age += dt
	if _starting:
		return
	var holding_start := false
	for slot in Players.players.duplicate():
		if _age < 0.2:
			break
		if slot.just_pressed(PlayerSlot.Btn.LB):
			_cycle_role(slot, -1)
		if slot.just_pressed(PlayerSlot.Btn.RB):
			_cycle_role(slot, 1)
		if slot.just_pressed(PlayerSlot.Btn.Y):
			_random_roles()
		if slot.just_pressed(PlayerSlot.Btn.BACK):
			Game.difficulty = Difficulty.next(Game.difficulty)
			Sfx.play("tick", 0.8)
		if slot.just_pressed(PlayerSlot.Btn.START):
			slot.ready = not slot.ready
			Sfx.play("tick", 1.5 if slot.ready else 0.9)
		if slot.held_for(PlayerSlot.Btn.START) > HOLD_TO_START:
			holding_start = true
		if slot.held_for(PlayerSlot.Btn.B) > HOLD_TO_LEAVE:
			Players.remove(slot)
			continue
		_overlay.steer(slot, dt)
	if holding_start:
		if _countdown < 0.0:
			_countdown = COUNTDOWN
		_countdown -= dt
		if _countdown <= 0.0:
			_start()
	else:
		_countdown = -1.0
	var everyone_ready := not Players.players.is_empty()
	for slot in Players.players:
		everyone_ready = everyone_ready and slot.ready
	if everyone_ready:
		_start()
	_refresh()


func _start() -> void:
	_starting = true
	Game.team_name = _team.text.strip_edges() if _team.text.strip_edges() != "" else Game.random_team_name()
	if not Game.fixed_level:
		Game.use_random_level()
	Sfx.play("land")
	get_tree().create_timer(0.4).timeout.connect(func() -> void: Game.goto("controls"))


func _refresh() -> void:
	var level := "random level" if not Game.fixed_level else "level %s" % Game.level_code()
	var best := Scores.best_for(Game.level_seed, Game.difficulty) if Game.fixed_level else -1
	_info.text = "Difficulty: %s   ·   %s%s" % [Difficulty.NAMES[Game.difficulty], level,
		("   ·   best %d gold" % best) if best >= 0 else ""]
	var n := Players.players.size()
	if n == 0:
		_status.text = "Press any button on a controller (or Space / Enter on the keyboard) to join"
	elif _countdown >= 0.0:
		_status.text = "Lift-off in %d..." % ceili(_countdown)
	else:
		var ready := 0
		for s in Players.players:
			if s.ready:
				ready += 1
		_status.text = "%d of %d ready. Press Start when you're set." % [ready, n]
	for i in _cards.get_child_count():
		var card: PlayerCard = _cards.get_child(i)
		card.refresh()


func _rebuild_cards() -> void:
	for c in _cards.get_children():
		c.queue_free()
	for slot in Players.players:
		var card := PlayerCard.new()
		card.slot = slot
		_cards.add_child(card)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		Players.clear()
		Game.goto("menu")


class PlayerCard:
	extends PanelContainer
	var slot: PlayerSlot
	var _name: Label
	var _role: Label
	var _extra: Label

	func _ready() -> void:
		custom_minimum_size = Vector2(72, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.08, 0.14, 0.88)
		style.border_color = slot.color
		style.set_border_width_all(2)
		style.border_width_top = 6
		style.set_content_margin_all(4)
		add_theme_stylebox_override("panel", style)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 1)
		add_child(box)
		_name = _label(box, 10)
		_extra = _label(box, 7)
		_extra.text = slot.device_name
		_extra.clip_text = true
		_role = _label(box, 9)
		var roles := RoleStrip.new()
		roles.slot = slot
		box.add_child(roles)
		_extra = _label(box, 8)

	func _label(box: Container, font_size: int) -> Label:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", font_size)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(64, 0)
		box.add_child(l)
		return l

	func refresh() -> void:
		_name.text = slot.label() + ("  READY" if slot.ready else "")
		_name.add_theme_color_override("font_color", Color("80f080") if slot.ready else Color.WHITE)
		_role.text = "< %s >" % Roles.name_of(slot.role)
		var leaving := slot.held_for(PlayerSlot.Btn.B)
		_extra.text = "Leaving..." if leaving > 0.2 else "Popped: %d" % slot.pops
		get_child(0).get_child(3).queue_redraw()


class RoleStrip:
	extends Control
	## One square per station: this player's pick is bright, stations others took are greyed out.
	var slot: PlayerSlot

	func _ready() -> void:
		custom_minimum_size = Vector2(64, 5)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var count := Roles.station_count(Players.players.size())
		var x0 := (size.x - count * 7.0) / 2.0
		for r in count:
			var taken := false
			for s in Players.players:
				if s != slot and s.role == r:
					taken = true
			var c := Color(0.3, 0.3, 0.35) if taken else Color(0.7, 0.7, 0.8)
			if slot.role == r:
				c = slot.color
			draw_rect(Rect2(x0 + r * 7.0, 0, 5, 4), c)


class MiniGame:
	extends Control
	## Pop-the-balloons: every player steers a crosshair in their color.
	var screen: Control
	var crosshairs := {}            # slot id -> Vector2
	var _balloons: Array[Dictionary] = []
	var _confetti: Array[Dictionary] = []
	var _spawn := 0.0
	var _t := 0.0

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func steer(slot: PlayerSlot, dt: float) -> void:
		var p: Vector2 = crosshairs.get(slot.id, size / 2.0)
		p += slot.move * 220.0 * dt
		p = p.clamp(Vector2(4, 70), Vector2(size.x - 4, size.y - 120))
		crosshairs[slot.id] = p
		if slot.just_pressed(PlayerSlot.Btn.A):
			for b in _balloons:
				if (b["pos"] as Vector2).distance_to(p) < 10.0:
					slot.pops += 1
					Sfx.play("pop", randf_range(0.8, 1.3))
					for i in 10:
						_confetti.append({"pos": b["pos"], "vel": Vector2.from_angle(randf() * TAU) * randf_range(30, 90),
							"color": b["color"], "life": 0.6})
					_balloons.erase(b)
					break

	func _process(dt: float) -> void:
		_t += dt
		_spawn -= dt
		if _spawn <= 0.0 and _balloons.size() < 14:
			_spawn = 0.6
			_balloons.append({"pos": Vector2(randf_range(20, size.x - 20), size.y - 110),
				"speed": randf_range(20, 40), "phase": randf() * TAU, "color": Color.from_hsv(randf(), 0.65, 0.95)})
		for b in _balloons.duplicate():
			var pos: Vector2 = b["pos"]
			pos.y -= float(b["speed"]) * dt
			pos.x += sin(_t * 1.5 + float(b["phase"])) * 10.0 * dt
			b["pos"] = pos
			if pos.y < 60.0:
				_balloons.erase(b)
		for c in _confetti.duplicate():
			c["life"] = float(c["life"]) - dt
			c["pos"] = (c["pos"] as Vector2) + (c["vel"] as Vector2) * dt
			c["vel"] = (c["vel"] as Vector2) + Vector2(0, 120) * dt
			if c["life"] <= 0.0:
				_confetti.erase(c)
		queue_redraw()

	func _draw() -> void:
		for b in _balloons:
			var p: Vector2 = (b["pos"] as Vector2).round()
			var col: Color = b["color"]
			draw_rect(Rect2(p.x - 4, p.y - 5, 8, 8), col)
			draw_rect(Rect2(p.x - 3, p.y - 6, 6, 1), col)
			draw_rect(Rect2(p.x - 3, p.y + 3, 6, 1), col)
			draw_rect(Rect2(p.x - 3, p.y - 4, 2, 2), col.lightened(0.4))
			draw_line(p + Vector2(0, 4), p + Vector2(sin(_t * 3.0 + p.x) * 2.0, 12), Color(1, 1, 1, 0.7), 1.0)
		for c in _confetti:
			var p: Vector2 = c["pos"]
			draw_rect(Rect2(p.x, p.y, 2, 2), c["color"])
		for slot in Players.players:
			if not crosshairs.has(slot.id):
				continue
			var p: Vector2 = (crosshairs[slot.id] as Vector2).round()
			var col := slot.color
			draw_rect(Rect2(p.x - 7, p.y, 5, 1), col)
			draw_rect(Rect2(p.x + 3, p.y, 5, 1), col)
			draw_rect(Rect2(p.x, p.y - 7, 1, 5), col)
			draw_rect(Rect2(p.x, p.y + 3, 1, 5), col)
			draw_string(ThemeDB.fallback_font, p + Vector2(6, -5), slot.label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, col)
