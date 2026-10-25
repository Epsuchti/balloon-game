class_name Boarder
extends Node2D
## An enemy that landed in the basket. Harpies peck at the envelope; goblins sit on a station so
## nobody can use it. Anyone can shove them overboard with the attack button.

const SPEED := 30.0
const PECK_DAMAGE := 2.0

var kind := "harpy"
var balloon: Balloon
var station: Station
var _target := Vector2.ZERO
var _t := 0.0
var _settled := false


func _ready() -> void:
	_target = Vector2(randf_range(-16.0, 16.0), -16.0)


func tick(dt: float) -> void:
	_t += dt
	if kind == "goblin":
		if station == null:
			station = _pick_station()
			if station != null:
				_target = station.position
	var to := _target - position
	if to.length() > 1.5:
		_settled = false
		position += to.limit_length(SPEED * dt)
	elif not _settled:
		_settled = true
		if station != null:
			if station.blocked_by == null:
				station.blocked_by = self
			else:
				station = null  # someone else got there first
	if _settled:
		if kind == "harpy":
			balloon.wear(PECK_DAMAGE * dt)
			if int(_t * 3.0) != int((_t - dt) * 3.0):
				Sfx.play("peck", randf_range(0.9, 1.2), -12.0)
	queue_redraw()


func _pick_station() -> Station:
	var free: Array[Station] = []
	for st in balloon.stations:
		if st.unlocked and st.blocked_by == null:
			free.append(st)
	return null if free.is_empty() else free[randi() % free.size()]


func release_station() -> void:
	if station != null and station.blocked_by == self:
		station.blocked_by = null
	station = null


func _draw() -> void:
	var frame := int(_t * (4.0 if _settled else 8.0)) % 2
	var tex := Art.sprite("%s_%d" % [kind, frame])
	var bob := 0.0
	if _settled and kind == "harpy":
		bob = -1.0 if int(_t * 6.0) % 2 == 0 else 0.0
	draw_texture(tex, Vector2(-floorf(tex.get_width() / 2.0), -tex.get_height() + bob))
