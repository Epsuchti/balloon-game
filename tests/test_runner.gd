extends Node
## Headless tests. Run with:
##   godot --headless --path . res://tests/test_runner.tscn
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
	check(Roles.station_count(1) == 3, "one player still has three stations")
	check(Roles.station_count(4) == 4, "fourth player adds the turret")
	check(Roles.station_count(12) == 8, "stations cap at eight")


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


func _test_run_smoke(bots: int, frames: int) -> void:
	pass
