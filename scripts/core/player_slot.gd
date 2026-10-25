class_name PlayerSlot
extends RefCounted
## One joined player: their device, color, chosen role and this frame's input.

enum Btn { A, B, X, Y, LB, RB, START, BACK }
const BUTTON_COUNT := 8

var id := 0
var device := 0
var guid := ""
var device_name := ""
var color := Color.WHITE
var role := Roles.ROAM
var connected := true
var lost_time := 0.0
var pops := 0          # balloons popped in the setup mini game
var ready := false     # pressed Start on the setup screen

var move := Vector2.ZERO
var aim := Vector2.ZERO
var _down: Array[bool] = []
var _prev: Array[bool] = []
var _held: Array[float] = []


func _init() -> void:
	_down.resize(BUTTON_COUNT)
	_down.fill(false)
	_prev.resize(BUTTON_COUNT)
	_prev.fill(false)
	_held.resize(BUTTON_COUNT)
	_held.fill(0.0)


func set_buttons(state: Array[bool], dt: float) -> void:
	for i in BUTTON_COUNT:
		_prev[i] = _down[i]
		_down[i] = state[i]
		_held[i] = _held[i] + dt if state[i] else 0.0


func pressed(b: int) -> bool:
	return _down[b]


func just_pressed(b: int) -> bool:
	return _down[b] and not _prev[b]


func just_released(b: int) -> bool:
	return _prev[b] and not _down[b]


func held_for(b: int) -> float:
	return _held[b]


func clear_input() -> void:
	move = Vector2.ZERO
	aim = Vector2.ZERO
	_down.fill(false)
	_prev.fill(false)
	_held.fill(0.0)


func label() -> String:
	return "P%d" % id
