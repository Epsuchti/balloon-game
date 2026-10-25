extends Control
## Shown after everyone is ready: how to move, what each station does and how to refill fuel and
## ammo. Every player presses A to confirm they've got it (B to take it back); then the flight starts.

const GAMEPAD := [
	["Move", "Left stick / D-pad"],
	["Jump", "A"],
	["Take a station", "Walk up to it, A"],
	["Leave a station", "B"],
	["Pick up / use item", "A"],
	["Drop item", "B"],
	["Shove a boarder", "X"],
	["Drop through deck", "Down + A"],
	["Pause", "Start"],
]
const STATIONS := [
	"Burner: hold A (or up) to heat the balloon and climb. Uses fuel.",
	"Shrinker: hold A (or down) to pull the balloon in and sink faster.",
	"Propeller: push left / right to fly sideways.",
	"Shooter turret: aim with the stick, hold A to fire. Uses ammo.",
	"Fishing rod: aim, A to cast. Hooks falling loot and crewmates who fell out.",
	"Repair kit: hold A to patch the balloon.",
	"Lamp: aim the light with the stick when it gets dark.",
	"Second propeller: push left / right, works with the first one.",
]

var _status: Label
var _chips: HBoxContainer
var _confirmed := {}   # slot id -> true
var _age := 0.0
var _starting := false


func _ready() -> void:
	add_child(Backdrop.new())
	Players.joining_enabled = true
	Players.remove_on_disconnect = true
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	var title := Label.new()
	title.text = "How to fly"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 6)
	root.add_child(cols)

	var move := _column(cols, "Moving around")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	move.add_child(grid)
	for row: Array in GAMEPAD:
		_text(grid, row[0], 9, Color("c0c0d0"))
		_text(grid, row[1], 9, Color("ffe060"))
	_text(move, "Keyboard 1: WASD to move, Space = A, Q = B, E = X, Tab = Start", 8, Color("c0c0d0"), true)
	_text(move, "Keyboard 2: arrows to move, . = A, / = B, , = X, Enter = Start", 8, Color("c0c0d0"), true)
	_text(move, "Careful: the basket has open sides. Jump over a rail and you fall out!", 8, Color("ff9070"), true)

	var st := _column(cols, "Stations")
	var count := Roles.station_count(Players.players.size())
	for r in count:
		_text(st, STATIONS[r], 8, Color.WHITE, true)
	if count < Roles.COUNT:
		_text(st, "More stations unfold as more players join, even mid-flight.", 8, Color("c0c0d0"), true)

	var sup := _column(cols, "Fuel, ammo and winning")
	for line: String in [
		"The burner runs on fuel (and the turret on ammo). When they run low, refill them:",
		"1. Walk to the hold, the crate at the bottom middle of the basket.",
		"2. Press A on a fuel can or ammo crate to pick it up.",
		"3. Carry it to the burner (fuel) or turret (ammo). An arrow shows where.",
		"4. Press A there to pour it in.",
		"Fly through pickups to collect gold, fuel and ammo.",
		"Land softly on the platform with the flag at the end. Gold only counts if you land!",
	]:
		_text(sup, line, 8, Color.WHITE, true)

	_chips = HBoxContainer.new()
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("separation", 4)
	root.add_child(_chips)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 11)
	root.add_child(_status)


func _column(parent: Container, heading: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	_text(box, heading, 11, Color("f0c040"))
	return box


func _text(parent: Container, text: String, font_size: int, color: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 2)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(150, 0)
	parent.add_child(l)
	return l


func _exit_tree() -> void:
	Players.remove_on_disconnect = false


func _physics_process(dt: float) -> void:
	_age += dt
	if _starting:
		return
	for slot in Players.players:
		if _age < 0.3:
			break
		if slot.just_pressed(PlayerSlot.Btn.A) and not _confirmed.has(slot.id):
			_confirmed[slot.id] = true
			Sfx.play("tick", 1.5)
		elif slot.just_pressed(PlayerSlot.Btn.B) and _confirmed.has(slot.id):
			_confirmed.erase(slot.id)
			Sfx.play("tick", 0.9)
	_refresh_chips()
	var waiting := 0
	for slot in Players.players:
		if not _confirmed.has(slot.id):
			waiting += 1
	if Players.players.is_empty():
		_status.text = "Press any button to join"
	elif waiting == 0:
		_status.text = "Everyone's got it. Lift-off!"
		_starting = true
		Sfx.play("land")
		get_tree().create_timer(0.6).timeout.connect(func() -> void: Game.goto("run"))
	else:
		_status.text = "Each player: press A when you've got it (%d to go). Esc: back" % waiting


func _refresh_chips() -> void:
	if _chips.get_child_count() != Players.players.size():
		for c in _chips.get_children():
			c.queue_free()
		for slot in Players.players:
			var l := Label.new()
			l.add_theme_font_size_override("font_size", 10)
			l.set_meta("slot", slot)
			_chips.add_child(l)
	for l: Label in _chips.get_children():
		if l.is_queued_for_deletion() or not l.has_meta("slot"):
			continue
		var slot: PlayerSlot = l.get_meta("slot")
		var ok := _confirmed.has(slot.id)
		l.text = "  %s: %s  " % [slot.label(), "got it" if ok else "press A"]
		l.add_theme_color_override("font_color", slot.color if ok else Color(0.7, 0.7, 0.75))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		Game.goto("setup")
