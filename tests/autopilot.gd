class_name Autopilot
extends RefCounted
## A four-bot crew that flies a level: the burner holds the tunnel's height, the propeller pushes
## on, the fisher hooks the supplies lying on the ground or stuck to the ceiling, and the
## shrinker doubles as the runner: it fetches fuel cans from the hold when the tank runs
## low (and repair kits when the repair station runs out), fixes stations nobody mans, patches the hull at the repair kit and shoves boarders overboard.
## Used by the tests to prove a level can be finished and landed.

var run: Node
var slots: Array[PlayerSlot] = []   # burner, shrinker, propeller, fisher
var _tries := {}   # pickup -> casts at it, so one behind a rock isn't tried forever
var _runner := "man"
var _fetch := "fuel"   # what the "fuel" job fetches from the hold: fuel or a repair kit
var _target: Station
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
	if absf(dx) >= 260.0 and slots.size() > 3:
		target_y = _fishing_height(c, target_y)
	var err := c.y - target_y
	if absf(dx) >= 260.0 and absf(err) > 40.0:
		push = 0.35  # wait for the burner to catch up before pressing on
	var burn := (err > 0.0 and b.velocity.y > -30.0) or b.velocity.y > b.landing_speed * 0.5
	var shrink := err < -40.0 and b.velocity.y < 20.0
	_man(b, slots[0], Roles.BURNER, Vector2.ZERO, burn)
	_man(b, slots[2], Roles.PROPELLER, Vector2(clampf(push, -1.0, 1.0), 0), false)
	_run_shrinker(b, shrink)
	if slots.size() > 3:
		_fish(b, slots[3])


## Height to fly at so the fisher can reach the next supply ahead the crew is short of that lies too
## far below or above the way through; target_y (the tunnel's middle) when there is none.
func _fishing_height(c: Vector2, target_y: float) -> float:
	for p: Pickup in run.pickups.get_children():
		if p.hooked or _tries.get(p, 0) >= 2 or not _needs(run.balloon, p.kind):
			continue
		var ahead := p.global_position.x - c.x
		if ahead < -30.0 or ahead > 260.0 or absf(p.global_position.y - target_y) < 170.0:
			continue
		return p.global_position.y + (190.0 if p.on_ceiling else -130.0)
	return target_y


## Whether the crew is short enough of this kind of supply to go out of the way for it.
func _needs(b: Balloon, kind: String) -> bool:
	match kind:
		"fuel":
			return b.fuel + b.count_items("fuel") * Balloon.CAN_FUEL < 70.0
		"kit":
			return b.patches + b.count_items("kit") * Balloon.KIT_PATCH < 40.0
		"ammo":
			return b.ammo + b.count_items("ammo") * Balloon.CRATE_AMMO < 15
	return false


## The fisher: casts at the nearest pickup in reach, fuel first, then repair kits and ammo.
func _fish(b: Balloon, slot: PlayerSlot) -> void:
	var me := b.crew_for(slot)
	var st: FishingRod = b.stations[Roles.FISHING]
	if me == null or me.station != st or st.broken or st.state != FishingRod.State.IDLE:
		_man(b, slot, Roles.FISHING, Vector2.ZERO, false)
		return
	var tip := st.tip()
	var best: Pickup = null
	var best_score := INF
	for p: Pickup in run.pickups.get_children():
		var d := p.global_position.distance_to(tip)
		if p.hooked or d > FishingRod.LINE_MAX * 0.9 or _tries.get(p, 0) >= 2:
			continue
		var want := {"fuel": 400.0, "kit": 200.0, "ammo": 100.0}
		if b.hull < 60.0 and b.patches + b.count_items("kit") * Balloon.KIT_PATCH < 40.0:
			want["kit"] = 600.0  # the hull needs kits more than the tank needs fuel
		var score: float = d - want.get(p.kind, 0.0)
		if score < best_score:
			best = p
			best_score = score
	if best == null:
		_input_for(slot, Vector2.ZERO, false, false)
		return
	var aim := (best.global_position - tip).normalized()
	var cast := _tick % 2 == 0
	if cast:
		_tries[best] = _tries.get(best, 0) + 1
	var buttons: Array[bool] = [cast, false, false, false, false, false, false, false]
	Players.bot_inputs[slot.device] = {"move": Vector2.ZERO, "aim": aim, "buttons": buttons}


## A bot that stays at its station: fixes it when it breaks and takes it back after a boarder leaves.
func _man(b: Balloon, slot: PlayerSlot, role: int, move: Vector2, a: bool) -> void:
	var me := b.crew_for(slot)
	var st: Station = b.stations[role]
	if me == null:
		_input_for(slot, Vector2.ZERO, false, false)
	elif me.station == null:
		var d := st.position.x - me.position.x
		_press(slot, Vector2(clampf(d / 6.0, -1.0, 1.0), 0), PlayerSlot.Btn.X, absf(d) < 3.0 and _tick % 2 == 0)
	elif st.broken:
		_input_for(slot, Vector2.ZERO, true, false)
	else:
		_input_for(slot, move, a, false)


func _run_shrinker(b: Balloon, shrink: bool) -> void:
	var slot := slots[1]
	var me := b.crew_for(slot)
	if me == null:
		_input_for(slot, Vector2.ZERO, false, false)
		return
	var pulse := _tick % 2 == 0   # A must be released between presses
	var want: Station = _target if _runner == "fix" or _runner == "goto" else null
	if _runner == "turret":
		want = b.stations[Roles.TURRET]
	if _runner != "man" and me.station != null and me.station != want:
		_input_for(slot, Vector2.ZERO, false, pulse)  # took the wrong station on the way: leave it
		return
	if me.carrying != null and _runner != "fuel" and _runner != "to_burner":
		_input_for(slot, Vector2.ZERO, false, pulse)  # picked something up by accident: drop it
		return
	if _runner != "man" and me.station == null and _boarder(b) != null:
		_runner = "shove"  # boarders first: they peck the hull or sit on a station
	match _runner:
		"man":
			if me.station == null:
				_target = b.stations[Roles.SHRINKER]
				_runner = "goto"
				return
			if me.station.broken:
				_input_for(slot, Vector2.ZERO, true, false)
				return
			var job := _next_job(b)
			if job != "":
				_input_for(slot, Vector2.ZERO, false, true)  # leave the station
				_runner = job
			else:
				_input_for(slot, Vector2.ZERO, shrink, false)
		"fuel":
			if me.carrying != null:
				if me.carrying.kind == _fetch:
					_runner = "to_burner"
				else:
					_input_for(slot, Vector2.ZERO, false, pulse)  # wrong item, drop it
				return
			var item := _nearest_item(b, me, _fetch)
			if item == null:
				_back(b)
				return
			if _walk(slot, me, Vector2(item.position.x, Balloon.FLOOR_Y)):
				_press(slot, Vector2.ZERO, PlayerSlot.Btn.Y, pulse)
		"to_burner":
			if me.carrying == null:
				_back(b)
				return
			var to: Station = b.stations[Roles.BURNER if _fetch == "fuel" else Roles.REPAIR]
			if _walk(slot, me, to.position):
				_press(slot, Vector2.ZERO, PlayerSlot.Btn.Y, pulse)
		"shove":
			var bd := _boarder(b)
			if bd == null:
				_back(b)
				return
			var y := Balloon.DECK_Y if bd.position.y < 6.0 else Balloon.FLOOR_Y
			var spot := Vector2(bd.position.x - signf(bd.position.x) * 6.0, y)
			if _walk(slot, me, spot):
				var buttons: Array[bool] = [false, false, pulse, false, false, false, false, false]
				Players.bot_inputs[slot.device] = {"move": Vector2.ZERO, "buttons": buttons}
		"turret":
			var st: Station = b.stations[Roles.TURRET]
			var foe := _nearest_enemy(b)
			if me.station == st:
				if foe == null or b.ammo <= 0 or _urgent(b):
					_input_for(slot, Vector2.ZERO, false, true)
					_back(b)
				elif st.broken:
					_input_for(slot, Vector2.ZERO, true, false)
				else:
					var aim := (foe.global_position - st.global_position).normalized()
					var buttons: Array[bool] = [true, false, false, false, false, false, false, false]
					Players.bot_inputs[slot.device] = {"move": Vector2.ZERO, "aim": aim, "buttons": buttons}
			elif foe == null or st.operator != null:
				_back(b)
			elif _walk(slot, me, st.position):
				_press(slot, Vector2.ZERO, PlayerSlot.Btn.X, pulse)
		"fix":
			if me.station == _target:
				var done := not _target.broken and (_target.role != Roles.REPAIR or b.hull >= 90.0 or b.patches <= 0.0 or _urgent(b))
				if done:
					_input_for(slot, Vector2.ZERO, false, true)
					_back(b)
				else:
					_input_for(slot, Vector2.ZERO, true, false)
			elif _target.operator != null and _target.operator != me:
				_back(b)
			elif _walk(slot, me, _target.position):
				_press(slot, Vector2.ZERO, PlayerSlot.Btn.X, pulse)
		"goto":
			var job := _next_job(b)
			if job != "" and me.station == null:
				_runner = job
			elif me.station == _target:
				_runner = "man"
			elif _walk(slot, me, _target.position):
				_press(slot, Vector2.ZERO, PlayerSlot.Btn.X, pulse)


func _next_job(b: Balloon) -> String:
	if _boarder(b) != null:
		return "shove"
	if b.fuel < 30.0 and b.count_items("fuel") > 0:
		_fetch = "fuel"
		return "fuel"
	if b.hull < 70.0 and b.patches < Balloon.KIT_PATCH and b.count_items("kit") > 0:
		_fetch = "kit"
		return "fuel"
	for role in [Roles.SHRINKER, Roles.REPAIR, Roles.PROPELLER2, Roles.LAMP, Roles.TURRET, Roles.FISHING]:
		var st: Station = b.stations[role]
		if st.broken and (st.operator == null or role == Roles.SHRINKER):
			_target = st
			return "fix"
	if b.ammo > 0 and _nearest_enemy(b) != null:
		return "turret"
	if b.hull < 50.0 and b.patches > 0.0:
		_target = b.stations[Roles.REPAIR]
		return "fix"
	return ""


## Something that should pull the runner off a long job (patching the hull, shooting).
func _urgent(b: Balloon) -> bool:
	if _boarder(b) != null or (b.fuel < 30.0 and b.count_items("fuel") > 0):
		return true
	for role in [Roles.SHRINKER, Roles.REPAIR]:
		if b.stations[role].broken and b.stations[role].operator == null:
			return true
	return false


func _nearest_enemy(b: Balloon) -> Node2D:
	var boss: Boss = run.boss
	if is_instance_valid(boss) and boss.alive() and boss.global_position.distance_to(b.center()) < 240.0:
		return boss
	var best: Enemy = null
	for e: Enemy in run.enemies.get_children():
		var d := e.global_position.distance_to(b.center())
		if not e.dying and d < 160.0 and (best == null or d < best.global_position.distance_to(b.center())):
			best = e
	return best


func _back(b: Balloon) -> void:
	_target = b.stations[Roles.SHRINKER]
	_runner = "goto"


## Walks towards a spot in the basket, dropping through the deck or jumping up to it on the way.
## Returns true once standing there (and has not set any input).
func _walk(slot: PlayerSlot, me: CrewMember, spot: Vector2) -> bool:
	var pulse := _tick % 2 == 0
	var on_deck := me.on_ground and absf(me.position.y - Balloon.DECK_Y) < 0.5
	var on_floor := me.on_ground and absf(me.position.y - Balloon.FLOOR_Y) < 0.5
	var want_deck := spot.y < 6.0
	if want_deck and on_floor:
		# Jump up to the deck from under its middle.
		_input_for(slot, Vector2(clampf(-me.position.x / 6.0, -1.0, 1.0), 0), absf(me.position.x) < 6.0 and pulse, false)
		return false
	if not want_deck and on_deck:
		_input_for(slot, Vector2(0, 1), pulse, false)  # drop through the deck
		return false
	var d := spot.x - me.position.x
	if absf(d) < 3.0 and me.on_ground:
		return true
	_input_for(slot, Vector2(clampf(d / 6.0, -1.0, 1.0), 0), false, false)
	return false


func _boarder(b: Balloon) -> Boarder:
	return null if b.boarders.is_empty() else b.boarders[0]


func _nearest_item(b: Balloon, me: CrewMember, kind: String) -> SupplyItem:
	var best: SupplyItem = null
	for it in b.items:
		if it.kind == kind and it.carrier == null:
			if best == null or absf(it.position.x - me.position.x) < absf(best.position.x - me.position.x):
				best = it
	return best


func _press(slot: PlayerSlot, move: Vector2, button: int, down: bool) -> void:
	var buttons: Array[bool] = [false, false, false, false, false, false, false, false]
	buttons[button] = down
	Players.bot_inputs[slot.device] = {"move": move, "buttons": buttons}


func _input_for(slot: PlayerSlot, move: Vector2, a: bool, b_button: bool) -> void:
	var buttons: Array[bool] = [a, b_button, false, false, false, false, false, false]
	Players.bot_inputs[slot.device] = {"move": move, "buttons": buttons}
