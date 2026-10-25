extends Node
## Headless tests. Run with (--fixed-fps makes the flights run as fast as possible):
##   godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
## Exits with code 1 if any check fails.

var _failures := 0
var _checks := 0


func _ready() -> void:
	await get_tree().process_frame
	_test_level_code()
	_test_roles()
	_test_generator()
	_test_terrain()
	_test_scores()
	await _test_run_smoke(1, 300)
	await _test_run_smoke(8, 900)
	await _test_breakdown()
	await _test_screens()
	await _test_autopilot(Difficulty.EASY, 777)
	await _test_autopilot(Difficulty.NORMAL, 777)
	print("\n%d checks, %d failed" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + what)


func _test_level_code() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var s := rng.randi() & LevelCode.SEED_MASK
		var d := i % 3
		var code := LevelCode.encode(s, d)
		var back := LevelCode.decode(code)
		check(back.get("seed", -1) == s and back.get("difficulty", -1) == d, "level code roundtrip %s" % code)
	check(LevelCode.decode("n-8f3k2q").get("difficulty", -1) == Difficulty.NORMAL, "codes are case-insensitive")
	check(LevelCode.decode("X-8F3K2Q").is_empty(), "bad difficulty letter rejected")
	check(LevelCode.decode("N-8F3K2").is_empty(), "short code rejected")
	check(LevelCode.decode("N-8F3K2O").is_empty(), "letter O is not in the alphabet")
	check(LevelCode.encode(0, 0) == "E-222222", "seed 0 encodes to all '2'")


func _test_roles() -> void:
	check(Roles.station_count(1) == Roles.COUNT and Roles.station_count(4) == Roles.COUNT, "every station is always on board")
	var Run: GDScript = load("res://scripts/run/run.gd")
	check(Run.breakdown_interval(2, Difficulty.NORMAL) > Run.breakdown_interval(8, Difficulty.NORMAL), "big crews get more breakdowns")
	check(Run.enemy_chance(2) < 0.3 and Run.enemy_chance(2) > 0.0, "two players see a few enemies")
	check(Run.enemy_chance(7) >= 1.0, "seven players get every enemy")
	var song: AudioStreamWAV = Music.render("danger")
	check(song.data.size() > 100000 and song.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the soundtrack renders and loops")
	var bosses := 0
	for i in 1000:
		if Run.has_boss(i):
			bosses += 1
	check(bosses > 700 and bosses < 800, "about three in four levels have a boss (%d/1000)" % bosses)


func _test_generator() -> void:
	for d in 3:
		for s in [1, 42, 123456, 987654321 & LevelCode.SEED_MASK]:
			var t0 := Time.get_ticks_msec()
			var a := LevelGenerator.generate(s, d)
			var ms := Time.get_ticks_msec() - t0
			var b := LevelGenerator.generate(s, d)
			print("level %s: %dx%d tiles, %d attempt(s), %d ms, %d spawns, %d pickups, %d wind zones, pieces %s" % [
				LevelCode.encode(s, d), a.width, a.height, a.attempts, ms, a.spawns.size(), a.pickups.size(),
				a.wind_zones.size(), a.set_pieces.map(func(p: Dictionary) -> String: return p["kind"])])
			check(a.checksum() == b.checksum(), "same seed + difficulty gives the same level (%d, %d)" % [s, d])
			check(a.spawns.size() == b.spawns.size() and a.pickups.size() == b.pickups.size(), "same spawns and pickups")
			check(LevelGenerator.validate(a), "level is passable (%d, %d)" % [s, d])
			check(a.width == Difficulty.SEGMENTS[d] * Tiles.SEG_W, "level length follows difficulty")
			check(a.get_cell(0, 10) == Tiles.BEDROCK and a.get_cell(a.width - 1, 10) == Tiles.BEDROCK
				and a.get_cell(10, 0) == Tiles.BEDROCK and a.get_cell(10, a.height - 1) == Tiles.BEDROCK, "outer walls are bedrock")
			check(a.get_cell(a.platform.position.x + 2, a.platform.position.y) == Tiles.PLATFORM, "landing platform exists")
	var x := LevelGenerator.generate(1, Difficulty.NORMAL)
	var y := LevelGenerator.generate(2, Difficulty.NORMAL)
	check(x.checksum() != y.checksum(), "different seeds give different levels")
	var z := LevelGenerator.generate(1, Difficulty.HARD)
	check(x.checksum() != z.checksum(), "difficulty changes the level")


func _test_terrain() -> void:
	var data := LevelGenerator.generate(5, Difficulty.EASY)
	var terrain := Terrain.new()
	add_child(terrain)
	terrain.setup(data)
	var dirt := Vector2i(-1, -1)
	var bedrock := Vector2i(0, 5)
	for yy in data.height:
		for xx in range(2, data.width - 2):
			if data.get_cell(xx, yy) == Tiles.DIRT:
				dirt = Vector2i(xx, yy)
				break
		if dirt.x >= 0:
			break
	check(dirt.x >= 0, "level has dirt")
	check(not terrain.damage_cell(dirt, 1.0), "one hit does not break dirt")
	check(terrain.damage_cell(dirt, 5.0), "enough damage breaks dirt")
	check(data.get_cell(dirt.x, dirt.y) == Tiles.AIR and terrain.get_cell_source_id(dirt) == -1, "broken tile is gone")
	check(not terrain.damage_cell(bedrock, 1000.0), "bedrock can't be broken")
	terrain.queue_free()


func _test_scores() -> void:
	var old_path := Scores.path
	Scores.path = "user://test_scoreboard.json"
	Scores.entries.clear()
	Scores.add({"team": "A", "gold": 10, "time": 50.0, "crew": 2, "difficulty": 1, "seed": 5, "landed": true})
	Scores.add({"team": "B", "gold": 30, "time": 70.0, "crew": 4, "difficulty": 1, "seed": 5, "landed": true})
	Scores.add({"team": "C", "gold": 0, "time": 20.0, "crew": 4, "difficulty": 1, "seed": 6, "landed": false})
	Scores.load_scores()
	check(Scores.entries.size() == 3, "scores survive a reload")
	var r := Scores.ranked()
	check(r[0]["team"] == "B" and r[2]["team"] == "C", "ranking puts landed runs with most gold first")
	check(Scores.best_for(5, 1) == 30, "best score per level")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Scores.path))
	Scores.path = old_path
	Scores.load_scores()


## Flies a run with bots mashing random buttons, to catch script errors in the whole game loop.
func _test_run_smoke(bots: int, frames: int) -> void:
	Players.clear()
	var slots: Array[PlayerSlot] = []
	for i in bots:
		var s := Players.add_bot()
		s.role = i if i < Roles.station_count(bots) else Roles.ROAM
		slots.append(s)
	Game.level_seed = 4242
	Game.difficulty = Difficulty.NORMAL
	var run: Node = load("res://scripts/run/run.gd").new()
	add_child(run)
	await get_tree().physics_frame
	check(run.balloon.crew.size() == bots, "%d crew in the basket" % bots)
	check(run.balloon.station_count == Roles.COUNT, "all stations on board")
	var manned := 0
	for st: Station in run.balloon.stations:
		if st.operator != null:
			manned += 1
	check(manned == mini(bots, Roles.station_count(bots)), "players start at their chosen stations")
	if bots >= 4:
		run.spawn_enemy("bat", run.balloon.center() + Vector2(120, 0))
		run.spawn_enemy("harpy", run.balloon.center() + Vector2(-120, 0))
		run.spawn_enemy("goblin", run.balloon.center() + Vector2(0, 100))
		run.spawn_enemy("bomber", run.balloon.center() + Vector2(150, 40))
		run.spawn_drop("fuel", run.balloon.center() + Vector2(40, 60), 0)
		run.spawn_boss()
	for st: Station in run.balloon.stations:
		if st.role % 2 == bots % 2:
			run.break_station(st)
	var rng := RandomNumberGenerator.new()
	rng.seed = bots
	for f in frames:
		for s in slots:
			if f % 20 == 0:
				var buttons := []
				for b in PlayerSlot.BUTTON_COUNT:
					buttons.append(rng.randf() < (0.5 if b == PlayerSlot.Btn.A else 0.08) and b != PlayerSlot.Btn.START)
				Players.bot_inputs[s.device] = {
					"move": Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)),
					"aim": Vector2.from_angle(rng.randf() * TAU), "buttons": buttons}
		if f == frames / 2 and bots >= 2:
			Players.remove(slots[-1])  # someone leaves mid-run
		await get_tree().physics_frame
	print("smoke %d bots: balloon at %s, hull %.0f, fuel %.0f, gold %d, crew %d, finished %s" % [
		bots, run.balloon.center().round(), run.balloon.hull, run.balloon.fuel, run.gold, run.balloon.crew.size(), run.finished])
	check(is_instance_valid(run.balloon), "run survives %d frames with %d bots" % [frames, bots])
	run.queue_free()
	Players.clear()
	await get_tree().process_frame


## A broken burner gives no heat until its operator holds A on it; a leak wears the hull down.
func _test_breakdown() -> void:
	Players.clear()
	var s := Players.add_bot()
	s.role = Roles.BURNER
	Game.level_seed = 99
	Game.difficulty = Difficulty.NORMAL
	var run: Node = load("res://scripts/run/run.gd").new()
	add_child(run)
	await get_tree().physics_frame
	var b: Balloon = run.balloon
	var burner: Station = b.stations[Roles.BURNER]
	run.break_station(burner)
	run.break_station(b.stations[Roles.REPAIR])
	var heat := b.heat
	var hull := b.hull
	var a_btn: Array[bool] = [true, false, false, false, false, false, false, false]
	Players.bot_inputs[s.device] = {"buttons": a_btn}
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(burner.broken and b.heat <= heat, "a broken burner gives no heat")
	for i in 120:
		await get_tree().physics_frame
	check(not burner.broken, "holding A on a broken station fixes it")
	check(b.hull < hull, "a leak wears the hull down")
	hull = b.hull
	for i in 60:
		await get_tree().physics_frame
	check(b.hull < hull, "the hull does not heal by itself")
	run.spawn_boss()
	var boss: Boss = run.boss
	for i in 240:
		await get_tree().physics_frame
	check(is_instance_valid(boss) and boss.alive(), "the boss shows up and stays")
	while is_instance_valid(boss) and boss.alive():
		boss.hit(1)
	check(run.gold >= 40, "beating the boss pays out gold")
	run.queue_free()
	Players.clear()
	await get_tree().process_frame


## Walks through every screen, and starts a run from the setup screen with everyone ready.
func _test_screens() -> void:
	Game.register_root(self)
	Game.goto("menu")
	await get_tree().process_frame
	Game.goto("scores")
	await get_tree().process_frame
	Game.use_random_level()
	Game.goto("setup")
	await get_tree().physics_frame
	var a := Players.add_bot()
	var b := Players.add_bot()
	check(a.role == Roles.BURNER and b.role == Roles.SHRINKER, "joining players get the first free stations")
	for i in 20:
		await get_tree().physics_frame
	var start: Array[bool] = [false, false, false, false, false, false, true, false]
	Players.bot_inputs[a.device] = {"buttons": start}
	Players.bot_inputs[b.device] = {"buttons": start}
	for i in 60:
		await get_tree().physics_frame
	check(_screen_is("controls_screen.gd"), "everyone ready shows the controls")
	var a_btn: Array[bool] = [true, false, false, false, false, false, false, false]
	var none: Array[bool] = [false, false, false, false, false, false, false, false]
	Players.bot_inputs[a.device] = {"buttons": none}
	Players.bot_inputs[b.device] = {"buttons": none}
	for i in 30:
		await get_tree().physics_frame
	Players.bot_inputs[a.device] = {"buttons": a_btn}
	for i in 60:
		await get_tree().physics_frame
	check(_screen_is("controls_screen.gd"), "the flight waits until every player confirms")
	Players.bot_inputs[b.device] = {"buttons": a_btn}
	for i in 60:
		await get_tree().physics_frame
	check(_screen_is("run.gd"), "all players confirming starts the run")
	for i in 30:
		await get_tree().physics_frame
	Players.clear()
	Game.goto("menu")
	await get_tree().process_frame
	Game._screen.queue_free()
	await get_tree().process_frame


## Three bots fly a whole level and land it (see Autopilot).
func _test_autopilot(difficulty: int, level_seed: int) -> void:
	Players.clear()
	var slots: Array[PlayerSlot] = []
	for i in 3:
		var s := Players.add_bot()
		s.role = i
		slots.append(s)
	Game.level_seed = level_seed
	Game.difficulty = difficulty
	var run: Node = load("res://scripts/run/run.gd").new()
	add_child(run)
	await get_tree().physics_frame
	var b: Balloon = run.balloon
	var pilot := Autopilot.new(run, slots)
	var frames := 0
	while not run.finished and frames < 60 * 300:
		frames += 1
		pilot.step()
		await get_tree().physics_frame
	var r: Dictionary = run.result
	print("autopilot %s: %s after %.0f s, hull %.0f, fuel %.0f (+%d cans), gold %d" % [
		LevelCode.encode(level_seed, difficulty), r.get("reason", "still flying"), run.elapsed, b.hull, b.fuel,
		b.count_items("fuel"), run.gold])
	check(r.get("landed", false), "autopilot lands on %s" % LevelCode.encode(level_seed, difficulty))
	run.queue_free()
	Players.clear()
	Scores.entries.pop_back()
	Scores.save_scores()
	await get_tree().process_frame


func _screen_is(script_file: String) -> bool:
	return Game._screen != null and is_instance_valid(Game._screen) \
		and Game._screen.get_script().resource_path.ends_with(script_file)
