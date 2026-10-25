class_name Station
extends Node2D
## A job on the balloon. Walk up and press A to take it, B to leave it free for someone else.
## Positioned at the operator's feet; unfolds with a short animation when it unlocks.

var role := 0
var balloon: Balloon
var operator: CrewMember
var blocked_by: Boarder
var unlocked := false
var _unfold := 1.0
var _t := 0.0


func set_unlocked(on: bool, animate: bool) -> void:
	if on == unlocked:
		return
	unlocked = on
	visible = on
	_unfold = 0.0 if animate else 1.0
	if on and animate:
		Sfx.play("unlock")


func tick(dt: float) -> void:
	_t += dt
	if unlocked and _unfold < 1.0:
		_unfold = minf(1.0, _unfold + dt / 0.6)
	_idle(dt)
	queue_redraw()


func operate(crew: CrewMember, dt: float) -> void:
	_operate(crew.slot, dt)


## Called every frame while someone mans the station.
func _operate(_slot: PlayerSlot, _dt: float) -> void:
	pass


## Called every frame whether or not someone mans the station.
func _idle(_dt: float) -> void:
	pass


func on_leave() -> void:
	pass


func accepts(_kind: String) -> bool:
	return false


func _draw_station() -> void:
	pass


func _draw() -> void:
	if not unlocked:
		return
	var t := _unfold - 1.0
	var s := 1.0 + 2.7 * t * t * t + 1.7 * t * t  # ease out with a little overshoot
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, s))
	_draw_station()
	draw_set_transform(Vector2.ZERO)
	var bob := 1.0 if int(_t * 3.0) % 2 == 0 else 0.0
	var carried := _carried_for_me()
	if carried != "":
		# Someone is carrying what this station needs: point at it with the item's icon.
		var tex := Art.sprite(carried)
		var y := -36.0 + bob * 2.0
		draw_texture(tex, Vector2(-floorf(tex.get_width() / 2.0), y - tex.get_height()))
		draw_colored_polygon(PackedVector2Array([Vector2(-3, y + 1), Vector2(3, y + 1), Vector2(0, y + 5)]), Color("ffe060"))
	elif operator == null and blocked_by == null and _idle_crew_near():
		var y := -18.0 + bob
		draw_colored_polygon(PackedVector2Array([Vector2(-2, y), Vector2(2, y), Vector2(0, y + 2)]), Color.WHITE)


func _carried_for_me() -> String:
	for c in balloon.crew:
		if c.carrying != null and accepts(c.carrying.kind):
			return c.carrying.kind
	return ""


func _idle_crew_near() -> bool:
	for c in balloon.crew:
		if c.station == null and absf(c.position.x - position.x) <= CrewMember.REACH and absf(c.position.y - position.y) <= 3.0:
			return true
	return false
