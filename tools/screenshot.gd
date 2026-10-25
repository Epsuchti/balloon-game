extends Node
## Flies a run with simple bot pilots and saves screenshots. Needs a display (e.g. xvfb-run):
##   xvfb-run godot --path . res://tools/screenshot.tscn -- <crew> <seconds,...> <out_prefix>
## Use "menu", "setup", "controls" or "scores" instead of a crew size to capture that screen.

var _shots: Array[float] = []
var _prefix := "shot"
var _run: Node
var _t := 0.0
var _slots: Array[PlayerSlot] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var crew := int(args[0]) if args.size() > 0 else 3
	for s in (args[1] if args.size() > 1 else "2,6").split(","):
		_shots.append(float(s))
	_prefix = args[2] if args.size() > 2 else "shot"
	Players.clear()
	Game.register_root(self)
	if args.size() > 0 and args[0] in ["menu", "setup", "scores", "controls"]:
		if args[0] == "setup" or args[0] == "controls":
			Game.goto(args[0])
			for i in 4:
				_slots.append(Players.add_bot())
			_slots[1].ready = true
			_slots[2].pops = 7
		else:
			Game.goto(args[0])
		return
	for i in crew:
		var s := Players.add_bot()
		s.role = i if i < Roles.station_count(crew) else Roles.ROAM
		_slots.append(s)
	Game.level_seed = 4242
	Game.difficulty = Difficulty.NORMAL
	_run = load("res://scripts/run/run.gd").new()
	add_child(_run)
	if args.size() > 3 and args[3] == "night":
		_run.night = 1.0


func _physics_process(dt: float) -> void:
	_t += dt
	if _run == null:
		for s in _slots:
			Players.bot_inputs[s.device] = {"move": Vector2(sin(_t * 2.0 + s.id), cos(_t * 1.3 + s.id * 2.0)),
				"buttons": [int(_t * 5.0 + s.id) % 4 == 0, false, false, false, false, false, false, false]}
		_shoot()
		return
	var b: Balloon = _run.balloon
	for s in _slots:
		var input := {"move": Vector2.ZERO, "buttons": [false, false, false, false, false, false, false, false]}
		match s.role:
			Roles.BURNER:
				input["buttons"][0] = b.velocity.y > -5.0 and b.center().y > _target_y()
			Roles.PROPELLER:
				input["move"] = Vector2(1, 0)
			Roles.TURRET:
				input["move"] = Vector2(1, -0.4)
				input["aim"] = Vector2(1, -0.4)
				input["buttons"][0] = int(_t * 2.0) % 3 == 0
			Roles.FISHING:
				input["aim"] = Vector2(-0.3, 1)
				input["buttons"][0] = int(_t) % 4 == 0
			Roles.ROAM:
				input["move"] = Vector2(sin(_t + s.id), 0)
		Players.bot_inputs[s.device] = input
	_shoot()


func _shoot() -> void:
	if not _shots.is_empty() and _t >= _shots[0]:
		var at: float = _shots.pop_front()
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s_%02d.png" % [_prefix, int(at)])
		print("saved shot at ", at)
		if _shots.is_empty():
			get_tree().quit()


func _target_y() -> float:
	var lvl: LevelData = _run.level
	var x := clampi(int((_run.balloon.center().x + 60.0) / Tiles.SIZE), 0, lvl.width - 1)
	return lvl.path[x] * Tiles.SIZE
