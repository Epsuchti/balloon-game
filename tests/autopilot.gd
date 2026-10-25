class_name Autopilot
extends RefCounted
## A three-bot crew that flies a level: the burner holds the tunnel's height, the propeller pushes
## on, and the shrinker doubles as the runner who fetches fuel cans from the hold when the tank runs low.
## Used by the tests to prove a level can be finished and landed.

var run: Node
var slots: Array[PlayerSlot] = []   # burner, shrinker, propeller
var _runner := "man"
var _tick := 0


func _init(r: Node, s: Array[PlayerSlot]) -> void:
	run = r
	slots = s


func step() -> void:
	_tick += 1
	var b: Balloon = run.balloon
	var lvl: LevelData = run.level
	var plat := lvl.platform_px()
	var c := b.center()
	var dx := plat.get_center().x - c.x
	var ahead := clampi(int((c.x + clampf(dx, -80.0, 80.0)) / Tiles.SIZE), 0, lvl.width - 1)
	var target_y := lvl.path[ahead] * Tiles.SIZE
	var push := 1.0
	if absf(dx) < 260.0:
		push = clampf(dx / 80.0, -1.0, 1.0) - b.velocity.x / 60.0
		if absf(dx) < 40.0:
			target_y = plat.position.y + 80.0  # aim below the platform so it settles down
	var err := c.y - target_y
	if absf(dx) >= 260.0 and absf(err) > 40.0:
		push = 0.35  # wait for the burner to catch up before pressing on
	var burn := (err > 0.0 and b.velocity.y > -30.0) or b.velocity.y > b.landing_speed * 0.5
	var shrink := err < -40.0 and b.velocity.y < 20.0
	_input_for(slots[0], Vector2.ZERO, burn, false)
	_input_for(slots[2], Vector2(clampf(push, -1.0, 1.0), 0), false, false)
	_run_shrinker(b, shrink)


func _run_shrinker(b: Balloon, shrink: bool) -> void:
	var slot := slots[1]
	var me := b.crew_for(slot)
	if me == null:
		_input_for(slot, Vector2.ZERO, false, false)
		return
	var pulse := _tick % 2 == 0   # A must be released between presses
	var on_deck := me.on_ground and absf(me.position.y - Balloon.DECK_Y) < 0.5
	var on_floor := me.on_ground and absf(me.position.y - Balloon.FLOOR_Y) < 0.5
	match _runner:
		"man":
			if me.station == null:
				_runner = "back"
			elif b.fuel < 30.0 and b.count_items("fuel") > 0:
				_input_for(slot, Vector2.ZERO, false, true)
				_runner = "to_hold"
			else:
				_input_for(slot, Vector2.ZERO, shrink, false)
		"to_hold":
			if me.carrying != null:
				if me.carrying.kind == "fuel":
					_runner = "to_burner"
				else:
					_input_for(slot, Vector2.ZERO, false, pulse)  # wrong item, drop it
				return
			if on_deck:
				_input_for(slot, Vector2(0, 1), pulse, false)  # drop through the deck
				return
			var target := _nearest_fuel(b, me)
			if target == null:
				_runner = "back"
				return
			var d := target.position.x - me.position.x
			_input_for(slot, Vector2(clampf(d / 6.0, -1.0, 1.0), 0), on_floor and absf(d) < 3.0 and pulse, false)
		"to_burner":
			if me.carrying == null:
				_runner = "back"
				return
			var d := -me.position.x
			_input_for(slot, Vector2(clampf(d / 6.0, -1.0, 1.0), 0), absf(d) < 3.0 and pulse, false)
		"back":
			var st: Station = b.stations[Roles.SHRINKER]
			var d := st.position.x - me.position.x
			if on_floor:
				# Jump up to the deck from under its middle.
				_input_for(slot, Vector2(clampf(-me.position.x / 6.0, -1.0, 1.0), 0), absf(me.position.x) < 6.0 and pulse, false)
			else:
				_input_for(slot, Vector2(clampf(d / 6.0, -1.0, 1.0), 0), on_deck and absf(d) < 3.0 and pulse, false)
			if me.station != null:
				_runner = "man"


func _nearest_fuel(b: Balloon, me: CrewMember) -> SupplyItem:
	var best: SupplyItem = null
	for it in b.items:
		if it.kind == "fuel" and it.carrier == null:
			if best == null or absf(it.position.x - me.position.x) < absf(best.position.x - me.position.x):
				best = it
	return best


func _input_for(slot: PlayerSlot, move: Vector2, a: bool, b_button: bool) -> void:
	var buttons: Array[bool] = [a, b_button, false, false, false, false, false, false]
	Players.bot_inputs[slot.device] = {"move": move, "buttons": buttons}
