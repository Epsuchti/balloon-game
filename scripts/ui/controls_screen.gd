extends Control
## Shown after everyone is ready: how to move, what each station does and how to refill fuel and
## ammo. Every player presses A to confirm they've got it (B to take it back); then the flight starts.
## Holding B before confirming goes back to the crew setup, like Esc.

const HOLD_TO_GO_BACK := 1.0

const STATIONS := [
	"Hold A (or up) to heat and climb. Uses fuel.",
	"Hold A (or down) to pull the envelope in and sink.",
	"Push right (or hold A) to fly right. Broken: no flying right!",
	"Aim with the stick, hold A to fire. Uses ammo.",
	"Aim, A to cast. Hooks loot and fallen crewmates.",
	"Hold A to patch the hull. Uses repair kits.",
	"Aim the light at night (7+ players).",
	"Push left (or hold A) to fly left. Broken: no flying left!",
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
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	root.add_child(UiKit.title("HOW TO FLY", 16))

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 6)
	root.add_child(cols)

	var move := UiKit.card(cols, "MOVING AROUND", Color("6ec3f0"))
	UiKit.row(move, ["stick", "dpad"], "Walk around the basket")
	UiKit.row(move, ["A"], "Jump. At a station: use it")
	UiKit.row(move, ["X"], "Take a station, shove a boarder")
	UiKit.row(move, ["Y"], "Pick up, pour in or drop an item")
	UiKit.row(move, ["B"], "Leave the station")
	UiKit.row(move, ["dpad", "+", "A"], "Drop down through the deck")
	UiKit.row(move, ["Start"], "Pause")
	move.add_child(HSeparator.new())
	_keys(move, "Keys 1", [["WASD", "move"], ["Space", "A"], ["E", "X"], ["R", "Y"], ["Q", "B"]])
	_keys(move, "Keys 2", [["Arrows", "move"], [".", "A"], [",", "X"], [";", "Y"], ["/", "B"]])
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	move.add_child(spacer)
	move.add_child(UiKit.label("Open sides! Jump over a rail and you fall out.", 9, Color("ff9070"), true))

	var st := UiKit.card(cols, "STATIONS", Color("f08838"))
	st.get_parent().get_parent().get_parent().size_flags_stretch_ratio = 1.15
	st.add_theme_constant_override("separation", 0)
	for r in Roles.COUNT:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		var icon := UiKit.StationIcon.new(r)
		h.add_child(icon)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", -3)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text.add_child(UiKit.label(Roles.NAMES[r], 9, UiKit.GOLD))
		text.add_child(UiKit.label(STATIONS[r], 8, UiKit.MUTED, true))
		h.add_child(text)
		st.add_child(h)

	var sup := UiKit.card(cols, "KEEP HER FLYING", Color("80d070"))
	sup.add_theme_constant_override("separation", 8)
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", -4)
	items.add_child(UiKit.ItemIcon.new("fuel"))
	items.add_child(UiKit.ItemIcon.new("ammo"))
	items.add_child(UiKit.ItemIcon.new("kit"))
	_tip(sup, items, "Fuel, ammo and repair kits wait in the hold. Press Y to pick one up, carry it to the burner, turret or repair kit station and press Y again. Arrows show the way.")
	_tip(sup, Warn.new(), "Smoke and a red ! mean a station broke. Take it with X and hold A until it's fixed.")
	_tip(sup, UiKit.StationIcon.new(Roles.REPAIR), "The balloon never heals by itself. Patch it at the repair kit; each kit patches a third of the hull. Collect more on the way or fish them up.")
	_tip(sup, BossIcon.new(), "Beware the Grumpus! Man the turret and shoot it down for gold.")
	_tip(sup, UiKit.ItemIcon.new("gold"), "Land softly on the flag platform. Gold only counts if you land!")

	_chips = HBoxContainer.new()
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("separation", 6)
	root.add_child(_chips)
	_status = UiKit.label("", 10, UiKit.CREAM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_constant_override("outline_size", 3)
	root.add_child(_status)


## A line of keycaps with what each one does.
func _keys(parent: Container, heading: String, keys: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	var l := UiKit.label(heading, 8, UiKit.MUTED)
	l.custom_minimum_size = Vector2(30, 0)
	h.add_child(l)
	for k: Array in keys:
		h.add_child(UiKit.Glyph.new("key:" + k[0]))
		h.add_child(UiKit.label(k[1] + " ", 8, UiKit.CREAM))
	parent.add_child(h)


func _tip(parent: Container, icon: Control, text: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(34, 0)
	holder.add_child(icon)
	h.add_child(holder)
	var l := UiKit.label(text, 8, UiKit.CREAM, true)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	parent.add_child(h)


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
			Sfx.play("confirm")
		elif slot.just_pressed(PlayerSlot.Btn.B) and _confirmed.has(slot.id):
			_confirmed.erase(slot.id)
			Sfx.play("leave")
		elif slot.held_for(PlayerSlot.Btn.B) > HOLD_TO_GO_BACK and not _confirmed.has(slot.id):
			Game.goto("setup")
			return
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
		_status.text = "Each player: press A when you've got it (%d to go). Hold B or Esc: back" % waiting


func _refresh_chips() -> void:
	if _chips.get_child_count() != Players.players.size():
		for c in _chips.get_children():
			c.queue_free()
		for slot in Players.players:
			var chip := Chip.new()
			chip.slot = slot
			_chips.add_child(chip)
	for chip in _chips.get_children():
		if chip is Chip:
			chip.ok = _confirmed.has(chip.slot.id)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		Game.goto("setup")


class Chip:
	extends Control
	## A player's pill at the bottom: "P1 [A]" blinking until they confirm, then "P1 OK!" in their colour.
	var slot: PlayerSlot
	var ok := false
	var _t := 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(54, 16)

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var font := UiKit.body_font()
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 3))
		draw_rect(Rect2(r.position + Vector2(0, 2), r.size), UiKit.INK)
		draw_rect(r, slot.color if ok else Color(0.16, 0.12, 0.22))
		draw_rect(r, slot.color, false, 1.0)
		var col := UiKit.INK if ok else UiKit.CREAM
		draw_string(font, Vector2(6, 12), slot.label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)
		if ok:
			draw_string(font, Vector2(size.x - 24, 12), "OK!", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)
		elif int(_t * 2.5) % 2 == 0:
			var c := Vector2(size.x - 12, size.y / 2.0 - 0.5)
			draw_circle(c + Vector2(0, 1), 5.0, UiKit.INK)
			draw_circle(c, 5.0, UiKit.BUTTON_COLORS["A"])
			draw_string(font, c + Vector2(-2.5, 3), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiKit.INK)


class Warn:
	extends Control
	## The red warning sign a broken station shows.
	func _init() -> void:
		custom_minimum_size = Vector2(14, 14)

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(7, 1), Vector2(13, 12), Vector2(1, 12)]), Color("ff4030"))
		draw_rect(Rect2(6.5, 4, 1, 4), Color.WHITE)
		draw_rect(Rect2(6.5, 9, 1, 1), Color.WHITE)


class BossIcon:
	extends Control
	## A small Grumpus.
	func _init() -> void:
		custom_minimum_size = Vector2(24, 21)

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.375, 0.375))
		draw_texture(Art.boss_frames()[0], Vector2.ZERO)
