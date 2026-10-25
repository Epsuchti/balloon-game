class_name Station
extends Node2D
## A job on the balloon. Walk up and press A to take it, B to leave it free for someone else.
## Positioned at the operator's feet; unfolds with a short animation when it unlocks.
## Stations break down now and then (see Run's pressure director): a broken station does nothing
## (or worse) until someone takes it and holds A for FIX_TIME seconds.

const FIX_TIME := 1.6

var role := 0
var balloon: Balloon
var operator: CrewMember
var blocked_by: Boarder
var unlocked := false
var broken := false
var fix := 0.0          # 0..1 while being fixed
var fixing := false
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
	if operator == null:
		fixing = false
	if broken:
		_broken(dt)
	_idle(dt)
	queue_redraw()


func operate(crew: CrewMember, dt: float) -> void:
	if broken:
		fixing = crew.slot.pressed(PlayerSlot.Btn.A)
		if fixing:
			if int((fix + dt / FIX_TIME) * 6.0) != int(fix * 6.0):
				Sfx.play("wrench", randf_range(0.9, 1.15), -12.0)
			fix += dt / FIX_TIME
			if fix >= 1.0:
				repair_breakdown()
		return
	_operate(crew.slot, dt)


func break_down() -> void:
	if broken:
		return
	broken = true
	fix = 0.0
	on_leave()
	Sfx.play("alarm")


func repair_breakdown() -> void:
	broken = false
	fix = 0.0
	fixing = false
	Sfx.play("fixed")
	if balloon.run != null:
		balloon.run.float_text(global_position + Vector2(0, -30), "Fixed!", Color("80f080"))


## Called every frame while someone mans the station.
func _operate(_slot: PlayerSlot, _dt: float) -> void:
	pass


## Called every frame whether or not someone mans the station.
func _idle(_dt: float) -> void:
	pass


## Called every frame while the station is broken, for breakdowns that do harm on their own.
func _broken(_dt: float) -> void:
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
	if broken:
		_draw_broken(bob)
	elif carried != "":
		# Someone is carrying what this station needs: point at it with the item's icon.
		var tex := Art.sprite(carried)
		var y := -36.0 + bob * 2.0
		draw_texture(tex, Vector2(-floorf(tex.get_width() / 2.0), y - tex.get_height()))
		draw_colored_polygon(PackedVector2Array([Vector2(-3, y + 1), Vector2(3, y + 1), Vector2(0, y + 5)]), Color("ffe060"))
	if not broken and carried == "" and operator == null and blocked_by == null and _idle_crew_near():
		var y := -18.0 + bob
		draw_colored_polygon(PackedVector2Array([Vector2(-2, y), Vector2(2, y), Vector2(0, y + 2)]), Color.WHITE)


func _draw_broken(bob: float) -> void:
	# Smoke puffs, a blinking warning sign and the fix progress.
	for i in 3:
		var age := fmod(_t * 0.8 + i / 3.0, 1.0)
		var p := Vector2(sin(_t * 2.0 + i * 2.1) * 3.0 + (i - 1) * 2.0, -10.0 - age * 16.0)
		var sz := 2.0 + age * 3.0
		draw_rect(Rect2(p - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Color(0.55, 0.55, 0.6, 0.7 * (1.0 - age)))
	var y := -34.0 + bob
	if int(_t * 4.0) % 2 == 0 or fixing:
		draw_colored_polygon(PackedVector2Array([Vector2(0, y - 7), Vector2(5, y + 2), Vector2(-5, y + 2)]), Color("ff4030"))
		draw_rect(Rect2(-0.5, y - 4, 1, 3), Color.WHITE)
		draw_rect(Rect2(-0.5, y, 1, 1), Color.WHITE)
	if fix > 0.0:
		draw_rect(Rect2(-8, y + 4, 16, 3), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-7, y + 5, 14.0 * fix, 1), Color("80f080"))


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
