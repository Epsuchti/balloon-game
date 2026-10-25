extends Node
## Joins players by device and reads their input. Every gamepad is its own player; the keyboard
## has two layouts (KEYBOARD_1 / KEYBOARD_2). Bots, used by the tests, have ids at or below BOT_BASE.

signal player_joined(slot: PlayerSlot)
signal player_left(slot: PlayerSlot)
signal device_lost(slot: PlayerSlot)
signal device_back(slot: PlayerSlot)

const KEYBOARD_1 := -1
const KEYBOARD_2 := -2
const BOT_BASE := -100
const MAX_PLAYERS := 12
const LOST_TIMEOUT := 10.0
const DEADZONE := 0.25
const COLORS: Array[Color] = [
	Color("e04848"), Color("4878e0"), Color("48c060"), Color("e0c040"),
	Color("c060d0"), Color("40c8c8"), Color("f08838"), Color("f0a0c0"),
	Color("a0e040"), Color("e8e8e8"), Color("a07040"), Color("6060a0"),
]
const JOY_BUTTONS: Array[int] = [
	JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y,
	JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_START, JOY_BUTTON_BACK,
]
# Physical keys for the two keyboard layouts, in PlayerSlot.Btn order.
const KEY_MAPS := {
	-1: {
		"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D],
		"buttons": [[KEY_SPACE], [KEY_Q], [KEY_E], [KEY_R], [KEY_1], [KEY_3], [KEY_TAB], [KEY_QUOTELEFT]],
	},
	-2: {
		"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT],
		"buttons": [
			[KEY_PERIOD, KEY_KP_0], [KEY_SLASH, KEY_KP_PERIOD], [KEY_COMMA, KEY_KP_1], [KEY_SEMICOLON, KEY_KP_2],
			[KEY_BRACKETLEFT, KEY_KP_4], [KEY_BRACKETRIGHT, KEY_KP_6], [KEY_ENTER, KEY_KP_ENTER], [KEY_BACKSPACE, KEY_KP_ADD],
		],
	},
}

var players: Array[PlayerSlot] = []
var joining_enabled := false:
	set(v):
		joining_enabled = v
		_free_prev.clear()  # a button already held when joining opens must be released first
var remove_on_disconnect := false   # the setup screen drops unplugged players right away
var bot_inputs := {}                # device -> {"move": Vector2, "aim": Vector2, "buttons": Array}
var _next_id := 1
var _free_prev := {}                # device -> any button held last frame, for devices nobody owns


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _physics_process(dt: float) -> void:
	var kb_blocked := _keyboard_blocked()
	for slot in players:
		_read(slot, dt, kb_blocked)
	for slot in players.duplicate():
		if not slot.connected:
			slot.lost_time += dt
			if slot.lost_time >= LOST_TIMEOUT:
				remove(slot)
	if joining_enabled:
		_check_joins(kb_blocked)


func join(device: int) -> PlayerSlot:
	var slot := PlayerSlot.new()
	slot.id = _next_id
	_next_id += 1
	slot.device = device
	slot.color = _free_color()
	if device >= 0:
		slot.guid = Input.get_joy_guid(device)
		slot.device_name = Input.get_joy_name(device)
	elif device == KEYBOARD_1:
		slot.device_name = "Keyboard (WASD)"
	elif device == KEYBOARD_2:
		slot.device_name = "Keyboard (arrows)"
	else:
		slot.device_name = "Bot"
	# Read twice so the button that joined doesn't also count as a fresh press.
	_read(slot, 0.0, false)
	_read(slot, 0.0, false)
	players.append(slot)
	player_joined.emit(slot)
	return slot


func add_bot() -> PlayerSlot:
	var device := BOT_BASE - _next_id
	bot_inputs[device] = {}
	return join(device)


func remove(slot: PlayerSlot) -> void:
	if players.has(slot):
		players.erase(slot)
		bot_inputs.erase(slot.device)
		player_left.emit(slot)


func clear() -> void:
	for slot in players.duplicate():
		remove(slot)
	_next_id = 1


func slot_for_device(device: int) -> PlayerSlot:
	for slot in players:
		if slot.connected and slot.device == device:
			return slot
	return null


func _free_color() -> Color:
	for c in COLORS:
		var used := false
		for slot in players:
			if slot.color == c:
				used = true
		if not used:
			return c
	return Color.from_hsv(randf(), 0.6, 0.9)


func _keyboard_blocked() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


func _keys(list: Array) -> float:
	for k: int in list:
		if Input.is_physical_key_pressed(k):
			return 1.0
	return 0.0


func _read(slot: PlayerSlot, dt: float, kb_blocked: bool) -> void:
	var buttons: Array[bool] = []
	buttons.resize(PlayerSlot.BUTTON_COUNT)
	buttons.fill(false)
	var move := Vector2.ZERO
	var aim := Vector2.ZERO
	var d := slot.device
	if not slot.connected:
		pass
	elif d <= BOT_BASE:
		var b: Dictionary = bot_inputs.get(d, {})
		move = b.get("move", Vector2.ZERO)
		aim = b.get("aim", move)
		var bb: Array = b.get("buttons", [])
		for i in mini(bb.size(), PlayerSlot.BUTTON_COUNT):
			buttons[i] = bb[i]
	elif d < 0:
		if not kb_blocked:
			var map: Dictionary = KEY_MAPS[d]
			move = Vector2(_keys(map["right"]) - _keys(map["left"]), _keys(map["down"]) - _keys(map["up"]))
			aim = move
			for i in PlayerSlot.BUTTON_COUNT:
				buttons[i] = _keys(map["buttons"][i]) > 0.0
	else:
		move = Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		if move.length() < DEADZONE:
			move = Vector2.ZERO
		var dpad := Vector2(
			float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_LEFT)),
			float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP)))
		if dpad != Vector2.ZERO:
			move = dpad
		aim = Vector2(Input.get_joy_axis(d, JOY_AXIS_RIGHT_X), Input.get_joy_axis(d, JOY_AXIS_RIGHT_Y))
		if aim.length() < 0.35:
			aim = move
		for i in PlayerSlot.BUTTON_COUNT:
			buttons[i] = Input.is_joy_button_pressed(d, JOY_BUTTONS[i])
	slot.move = move.limit_length(1.0)
	slot.aim = aim
	slot.set_buttons(buttons, dt)


func _check_joins(kb_blocked: bool) -> void:
	if players.size() >= MAX_PLAYERS:
		return
	for d in Input.get_connected_joypads():
		if slot_for_device(d) != null:
			continue
		var any := false
		for b in JOY_BUTTONS:
			if Input.is_joy_button_pressed(d, b):
				any = true
		if any and not _free_prev.get(d, true):
			_free_prev[d] = any
			join(d)
		else:
			_free_prev[d] = any
	if kb_blocked:
		return
	for d in [KEYBOARD_1, KEYBOARD_2]:
		if slot_for_device(d) != null:
			continue
		var any := false
		for keys: Array in KEY_MAPS[d]["buttons"]:
			if _keys(keys) > 0.0:
				any = true
		if any and not _free_prev.get(d, true):
			_free_prev[d] = any
			join(d)
		else:
			_free_prev[d] = any


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		var guid := Input.get_joy_guid(device)
		for slot in players:
			if not slot.connected and slot.guid == guid:
				slot.device = device
				slot.connected = true
				slot.lost_time = 0.0
				device_back.emit(slot)
				return
		_free_prev[device] = true
	else:
		var slot := slot_for_device(device)
		if slot == null:
			return
		if remove_on_disconnect:
			remove(slot)
			return
		slot.connected = false
		slot.lost_time = 0.0
		slot.clear_input()
		device_lost.emit(slot)
