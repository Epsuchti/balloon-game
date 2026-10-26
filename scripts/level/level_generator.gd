class_name LevelGenerator
extends RefCounted
## Builds a level from seed + difficulty in six steps: pacing curve, flight path, terrain,
## set pieces, validation and landing platform. The same inputs always give the same level.
## Enemy spawn points are always placed; the run decides whether the crew is big enough to switch them on.

const MAX_ATTEMPTS := 6
const BW := Tiles.BALLOON_W
const BH := Tiles.BALLOON_H
const ENEMY_WEIGHTS := {
	"bat": [5.0, 0.0], "harpy": [2.0, 3.0], "goblin": [1.0, 2.0], "bomber": [0.0, 3.0],
}


static func generate(level_seed: int, difficulty: int) -> LevelData:
	var build_seed := level_seed
	var widen := 1.0
	var data: LevelData = null
	for attempt in MAX_ATTEMPTS:
		data = _build(level_seed, build_seed, difficulty, widen)
		data.attempts = attempt + 1
		if validate(data):
			return data
		if attempt % 3 == 2:
			# Widening didn't help: move to the next seed (still derived from the level seed).
			build_seed = (build_seed * 1103515245 + 12345) & LevelCode.SEED_MASK
			widen = 1.0
		else:
			widen += 0.2
	# Last resort: a very wide tunnel always passes.
	data = _build(level_seed, build_seed, difficulty, 2.0)
	data.attempts = MAX_ATTEMPTS + 1
	return data


static func _build(level_seed: int, build_seed: int, difficulty: int, widen: float) -> LevelData:
	var rng := RandomNumberGenerator.new()
	rng.seed = build_seed
	var data := LevelData.new()
	data.level_seed = level_seed
	data.difficulty = difficulty
	data.width = Difficulty.SEGMENTS[difficulty] * Tiles.SEG_W
	data.height = Tiles.LEVEL_H
	data.cells.resize(data.width * data.height)
	_pacing(data, rng)
	_flight_path(data, rng, widen)
	_terrain(data, rng)
	_set_pieces(data, rng)
	_landing_platform(data)
	_borders(data)
	_start_area(data)
	return data


# 1. Pacing curve: rise, peak, breather, rise again, calm final approach.
static func _pacing(data: LevelData, rng: RandomNumberGenerator) -> void:
	var n := int(data.width / Tiles.SEG_W)
	var tension := PackedFloat32Array()
	tension.resize(n)
	tension[0] = 0.1
	tension[n - 1] = 0.1
	var i := 1
	var base := 0.25
	while i < n - 1:
		var climb := rng.randi_range(2, 3)
		for k in climb:
			if i >= n - 1:
				break
			tension[i] = clampf(base + 0.22 * k + rng.randf_range(-0.05, 0.05), 0.0, 1.0)
			i += 1
		if i < n - 1:
			tension[i] = rng.randf_range(0.08, 0.2)
			i += 1
		base = minf(base + 0.12, 0.55)
	for s in n:
		data.segments.append({
			"x0": s * Tiles.SEG_W, "x1": (s + 1) * Tiles.SEG_W, "tension": tension[s],
			"breather": s > 0 and s < n - 1 and tension[s] < 0.25, "night": false,
		})
	var runs := 2 if n >= 10 else 1
	for r in runs:
		var first := rng.randi_range(2, n - 3)
		var length := rng.randi_range(1, 2)
		for s in range(first, mini(first + length, n - 1)):
			data.segments[s]["night"] = true


static func _tension_at(data: LevelData, x: int) -> float:
	var f := (x + 0.5) / Tiles.SEG_W - 0.5
	var i := clampi(floori(f), 0, data.segments.size() - 1)
	var j := mini(i + 1, data.segments.size() - 1)
	var a: float = data.segments[i]["tension"]
	var b: float = data.segments[j]["tension"]
	return lerpf(a, b, clampf(f - i, 0.0, 1.0))


# 2. Flight path: a random walk smoothed with noise. High tension means steeper climbs and dives.
static func _flight_path(data: LevelData, rng: RandomNumberGenerator, widen: float) -> void:
	var w := data.width
	var h := data.height
	var narrow: float = Difficulty.TUNNEL_FACTOR[data.difficulty] * BW
	var wide := narrow + 18.0
	data.col_half.resize(w)
	for x in w:
		data.col_half[x] = minf(lerpf(wide, narrow, _tension_at(data, x)) * 0.5 * widen, (h - 12) * 0.5)
	# Broad swells from low-frequency noise, plus a random walk that gets steeper with tension.
	var swell := FastNoiseLite.new()
	swell.seed = rng.randi()
	swell.frequency = 0.009
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.035
	var path := PackedFloat32Array()
	path.resize(w)
	var walk := 0.0
	var slope := 0.0
	var target := 0.0
	var land_y := h * 0.5
	var approach_x: int = data.segments[-1]["x0"] - 24
	for x in w:
		var t := _tension_at(data, x)
		if x % 10 == 0:
			target = rng.randf_range(-1.0, 1.0) * (0.15 + 1.1 * t)
		slope = lerpf(slope, target, 0.12)
		walk = clampf(walk + slope * 0.03, -0.6, 0.6)
		var margin: float = data.col_half[x] + 4.0
		var amp := h * 0.5 - margin
		var v := clampf(swell.get_noise_1d(x) * 1.7 + noise.get_noise_1d(x) * 0.6 * t + walk, -1.0, 1.0)
		if x < Tiles.SEG_W / 2:
			v *= x / (Tiles.SEG_W / 2.0)  # start in the middle
		var y := h * 0.5 + amp * v
		if x >= approach_x:
			var k := clampf((x - approach_x) / 40.0, 0.0, 1.0)
			y = lerpf(y, land_y, k)
		path[x] = y
	for p in 2:
		path = _smooth(path, 7)
	data.path = path


static func _smooth(arr: PackedFloat32Array, r: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(arr.size())
	var n := arr.size()
	for i in n:
		var sum := 0.0
		var cnt := 0
		for j in range(maxi(0, i - r), mini(n, i + r + 1)):
			sum += arr[j]
			cnt += 1
		out[i] = sum / cnt
	return out


static func _slope(data: LevelData, x: int) -> float:
	var w := data.width
	return (data.path[mini(x + 1, w - 1)] - data.path[maxi(x - 1, 0)]) * 0.5


# 3. Terrain: solid everywhere, carve the tunnel along the path, roughen with noise and cellular automata.
static func _terrain(data: LevelData, rng: RandomNumberGenerator) -> void:
	var w := data.width
	var h := data.height
	var mat_noise := FastNoiseLite.new()
	mat_noise.seed = rng.randi()
	mat_noise.frequency = 0.07
	var wall_noise := FastNoiseLite.new()
	wall_noise.seed = rng.randi()
	wall_noise.frequency = 0.09
	var cave_noise := FastNoiseLite.new()
	cave_noise.seed = rng.randi()
	cave_noise.frequency = 0.045
	for y in h:
		var row := y * w
		for x in w:
			data.cells[row + x] = Tiles.STONE if mat_noise.get_noise_2d(x, y) > -0.1 else Tiles.DIRT
	var lo := PackedInt32Array()
	var hi := PackedInt32Array()
	lo.resize(w)
	hi.resize(w)
	for x in w:
		var cy := data.path[x]
		var s := _slope(data, x)
		var k := 1.0 / sqrt(1.0 + s * s)
		var half := data.col_half[x]
		var reach := (half + 11.0) / k
		var y0 := maxi(1, int(cy - reach))
		var y1 := mini(h - 2, int(cy + reach))
		lo[x] = y0
		hi[x] = y1
		for y in range(y0, y1 + 1):
			var d := absf(y - cy) * k
			var v := (half - d) / 3.0 + wall_noise.get_noise_2d(x, y) * 2.2
			if v > 0.0 or (d < half + 9.0 and cave_noise.get_noise_2d(x, y) > 0.36):
				data.cells[y * w + x] = Tiles.AIR
			elif d < half + 8.0:
				# Walls next to the tunnel are mostly dirt, like topsoil.
				data.cells[y * w + x] = Tiles.DIRT if mat_noise.get_noise_2d(x, y) < 0.25 else Tiles.STONE
	for p in 3:
		_automata(data, lo, hi, mat_noise)
	# Always keep a core along the path that the balloon fits through.
	for x in w:
		var cy := data.path[x]
		var core := minf(data.col_half[x], BH * 0.5 + 1.5) + _max_slope(data, x) * BW * 0.5 + 0.5
		for y in range(maxi(1, int(cy - core - 1.0)), mini(h - 2, int(cy + core + 1.0)) + 1):
			if absf(y - cy) <= core:
				data.cells[y * w + x] = Tiles.AIR


static func _automata(data: LevelData, lo: PackedInt32Array, hi: PackedInt32Array, mat_noise: FastNoiseLite) -> void:
	var w := data.width
	var src := data.cells.duplicate()
	for x in range(1, w - 1):
		for y in range(lo[x], hi[x] + 1):
			var i := y * w + x
			var a := i - w
			var b := i + w
			var solid := int(src[a - 1] != 0) + int(src[a] != 0) + int(src[a + 1] != 0) \
				+ int(src[i - 1] != 0) + int(src[i] != 0) + int(src[i + 1] != 0) \
				+ int(src[b - 1] != 0) + int(src[b] != 0) + int(src[b + 1] != 0)
			if solid >= 5:
				if src[i] == Tiles.AIR:
					data.cells[i] = Tiles.DIRT if mat_noise.get_noise_2d(x, y) < 0.25 else Tiles.STONE
			else:
				data.cells[i] = Tiles.AIR


# 4. Set pieces where the pacing curve calls for them, plus pickups, enemy spawns and gold.
static func _set_pieces(data: LevelData, rng: RandomNumberGenerator) -> void:
	var n := data.segments.size()
	var density: float = Difficulty.ENEMY_DENSITY[data.difficulty]
	var pickup_mult: float = Difficulty.PICKUP_MULT[data.difficulty]
	# Repair kits get their own random numbers, so adding them left the rest of every level as it was.
	var kits := RandomNumberGenerator.new()
	kits.seed = hash(Vector2i(data.level_seed, data.difficulty)) + 4111
	for s in range(1, n - 1):
		var seg: Dictionary = data.segments[s]
		var t: float = seg["tension"]
		var x0: int = seg["x0"] + 6
		var x1: int = seg["x1"] - 6
		var kind := ""
		if seg["breather"]:
			kind = "supplies"
			_supplies(data, rng, kits, x0, x1, pickup_mult)
		else:
			var options: Array[String] = ["stalactites", "wind_shaft", "floating_islands"]
			if t >= 0.65:
				options = ["narrow_gap", "stalactites", "enemy_nest"]
			kind = options[rng.randi_range(0, options.size() - 1)]
			match kind:
				"narrow_gap":
					_narrow_gap(data, rng, x0, x1)
				"stalactites":
					_stalactites(data, rng, x0, x1)
				"wind_shaft":
					_wind_shaft(data, rng, x0, x1)
				"floating_islands":
					_floating_islands(data, rng, x0, x1)
				"enemy_nest":
					_enemy_nest(data, rng, x0, x1, s, t)
		data.set_pieces.append({"kind": kind, "segment": s})
		var count := roundi(density * (1.0 + 3.0 * t) * (0.3 if seg["breather"] else 1.0))
		for e in count:
			var x := rng.randi_range(x0, x1)
			data.spawns.append({"pos": _air_point(data, rng, x, 0.6), "kind": _enemy_kind(rng, t), "segment": s})
		for g in rng.randi_range(1, 2):
			data.pickups.append({"pos": _air_point(data, rng, rng.randi_range(x0, x1), 0.35), "kind": "gold"})
		# Now and then a repair kit lies on the ground below the way through: dive for it or fish it up.
		if not seg["breather"] and kits.randf() < 0.5:
			var kx := kits.randi_range(x0, x1)
			var ky := _floor(data, kx, data.path[kx])
			if ky - data.path[kx] < data.col_half[kx] + 6.0:
				data.pickups.append({"pos": Vector2((kx + 0.5) * Tiles.SIZE, (ky - 0.6) * Tiles.SIZE), "kind": "kit"})


static func _air_point(data: LevelData, rng: RandomNumberGenerator, x: int, spread: float) -> Vector2:
	var y := data.path[x] + rng.randf_range(-1.0, 1.0) * data.col_half[x] * spread
	if data.is_solid(x, int(y)):
		y = data.path[x]
	return Vector2((x + 0.5) * Tiles.SIZE, y * Tiles.SIZE)


static func _enemy_kind(rng: RandomNumberGenerator, t: float) -> String:
	var total := 0.0
	for k: String in ENEMY_WEIGHTS:
		total += ENEMY_WEIGHTS[k][0] + ENEMY_WEIGHTS[k][1] * t
	var r := rng.randf() * total
	for k: String in ENEMY_WEIGHTS:
		r -= ENEMY_WEIGHTS[k][0] + ENEMY_WEIGHTS[k][1] * t
		if r <= 0.0:
			return k
	return "bat"


static func _ceiling(data: LevelData, x: int, cy: float) -> int:
	var y := int(cy)
	while y > 0 and not data.is_solid(x, y):
		y -= 1
	return y


static func _floor(data: LevelData, x: int, cy: float) -> int:
	var y := int(cy)
	while y < data.height - 1 and not data.is_solid(x, y):
		y += 1
	return y


static func _clearance(data: LevelData, x: int) -> float:
	return BH * 0.5 + 2.0 + _max_slope(data, x) * BW * 0.5


## Steepest slope under a balloon-wide window around x, so curves get enough room too.
static func _max_slope(data: LevelData, x: int) -> float:
	var m := 0.0
	for dx in range(-BW / 2, BW / 2 + 1, 2):
		m = maxf(m, absf(_slope(data, clampi(x + dx, 0, data.width - 1))))
	return m


static func _supplies(data: LevelData, rng: RandomNumberGenerator, kit_rng: RandomNumberGenerator, x0: int, x1: int, mult: float) -> void:
	var kinds: Array[String] = []
	for i in roundi(rng.randf_range(1.0, 2.0) * mult):
		kinds.append("fuel")
	for i in roundi(rng.randf_range(1.0, 2.0) * mult):
		kinds.append("ammo")
	for i in rng.randi_range(4, 6):
		kinds.append("gold")
	for i in kinds.size():
		var x := int(lerpf(x0, x1, (i + 0.5) / kinds.size()))
		var y := data.path[x] + rng.randf_range(-1.0, 1.0) * BH * 0.25
		data.pickups.append({"pos": Vector2((x + 0.5) * Tiles.SIZE, y * Tiles.SIZE), "kind": kinds[i]})
	for i in roundi(kit_rng.randf_range(0.6, 1.4) * mult):
		var x := kit_rng.randi_range(x0, x1)
		data.pickups.append({"pos": Vector2((x + 0.5) * Tiles.SIZE, data.path[x] * Tiles.SIZE), "kind": "kit"})


static func _narrow_gap(data: LevelData, rng: RandomNumberGenerator, x0: int, x1: int) -> void:
	# Put the gap where the path is flattest.
	var xc := rng.randi_range(x0 + 4, x1 - 4)
	for i in 8:
		var cand := rng.randi_range(x0 + 4, x1 - 4)
		if absf(_slope(data, cand)) < absf(_slope(data, xc)):
			xc = cand
	var narrow: float = Difficulty.TUNNEL_FACTOR[data.difficulty] * BW
	var opening := maxf(narrow, BH + 3.0) + absf(_slope(data, xc)) * BW
	var cy := data.path[xc]
	var top := int(cy - opening * 0.5)
	var bottom := int(ceil(cy + opening * 0.5))
	for x in range(xc - 3, xc + 4):
		var round_off := absi(x - xc)
		for y in range(1, top - round_off):
			data.set_cell(x, y, Tiles.STONE)
		for y in range(bottom + round_off, data.height - 1):
			data.set_cell(x, y, Tiles.STONE)


static func _stalactites(data: LevelData, rng: RandomNumberGenerator, x0: int, x1: int) -> void:
	for i in rng.randi_range(4, 7):
		var x := rng.randi_range(x0, x1)
		var from_top := rng.randf() < 0.7
		var base := rng.randi_range(2, 3)
		var cy := data.path[x]
		var anchor := _ceiling(data, x, cy) if from_top else _floor(data, x, cy)
		var room := absf(cy - anchor) - _clearance(data, x)
		if room < 2.0:
			continue
		var length := rng.randf_range(0.4, 1.0) * room
		for dx in range(-base, base + 1):
			var cx := x + dx
			var col_len := length * (1.0 - absf(dx) / (base + 1.0))
			var limit := _clearance(data, cx) if cx >= 0 and cx < data.width else 0.0
			for k in int(col_len) + 1:
				var y := anchor + k if from_top else anchor - k
				if cx < 0 or cx >= data.width or absf(y - data.path[cx]) < limit:
					break
				data.set_cell(cx, y, Tiles.STONE)


static func _wind_shaft(data: LevelData, rng: RandomNumberGenerator, x0: int, x1: int) -> void:
	var xa := rng.randi_range(x0, maxi(x0, x1 - 24))
	var dirs: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
	var dir: Vector2 = dirs[rng.randi_range(0, dirs.size() - 1)]
	var xm := xa + 12
	var cy := data.path[xm]
	var half := data.col_half[xm]
	# A chimney the wind blows out of, above or below the tunnel.
	var shaft_up := dir == Vector2.DOWN or (dir.y == 0.0 and rng.randf() < 0.5)
	for x in range(xm - 4, xm + 5):
		var jitter := rng.randi_range(-1, 1)
		for k in range(0, int(half + 28)):
			var y := int(cy - k) if shaft_up else int(cy + k)
			if y < 3 or y > data.height - 4:
				break
			if absi(x - xm) + jitter <= 4:
				data.set_cell(x, y, Tiles.AIR)
	var rect := Rect2(xa * Tiles.SIZE, (cy - half - 4.0) * Tiles.SIZE, 24 * Tiles.SIZE, (half * 2.0 + 8.0) * Tiles.SIZE)
	data.wind_zones.append({"rect": rect, "force": dir * Difficulty.WIND[data.difficulty]})


static func _floating_islands(data: LevelData, rng: RandomNumberGenerator, x0: int, x1: int) -> void:
	for i in rng.randi_range(2, 3):
		var x := rng.randi_range(x0 + 4, x1 - 4)
		var cy := data.path[x]
		var r := rng.randi_range(2, 4)
		var clear := _clearance(data, x) + r + 2.0
		var up_room := cy - _ceiling(data, x, cy)
		var down_room := _floor(data, x, cy) - cy
		var y := 0.0
		if up_room > clear + r + 2.0:
			y = cy - clear - rng.randf() * (up_room - clear - r - 2.0)
		elif down_room > clear + r + 2.0:
			y = cy + clear + rng.randf() * (down_room - clear - r - 2.0)
		else:
			continue
		var rx := r + 2
		for dy in range(-r, r + 2):
			for dx in range(-rx, rx + 1):
				var e := pow(dx / float(rx), 2) + pow(dy / float(r), 2)
				if dy > 0:
					e = absf(dx) / float(rx) + dy / float(r + 1)  # pointy underside
				if e <= 1.0 + rng.randf_range(-0.15, 0.1):
					data.set_cell(x + dx, int(y) + dy, Tiles.DIRT if dy <= 0 else Tiles.STONE)


static func _enemy_nest(data: LevelData, rng: RandomNumberGenerator, x0: int, x1: int, seg: int, t: float) -> void:
	var xc := rng.randi_range(x0 + 8, x1 - 8)
	for i in rng.randi_range(3, 5):
		var x := clampi(xc + rng.randi_range(-8, 8), x0, x1)
		var kind := "bat" if rng.randf() < 0.6 else _enemy_kind(rng, t)
		data.spawns.append({"pos": _air_point(data, rng, x, 0.7), "kind": kind, "segment": seg})
	for i in 3:
		data.pickups.append({"pos": _air_point(data, rng, xc + rng.randi_range(-6, 6), 0.3), "kind": "gold"})


# 6. Landing platform at the end, inside a calm final approach.
static func _landing_platform(data: LevelData) -> void:
	var w := data.width
	var h := data.height
	var pw := 18
	var px0 := w - 14 - pw
	var cy := data.path[px0 + int(pw / 2)]
	var top := mini(int(cy + BH * 0.5) + 3, h - 6)
	data.platform = Rect2i(px0, top, pw, 2)
	for x in range(px0 - 12, mini(px0 + pw + 8, w - 2)):
		for y in range(maxi(2, top - BH - 8), top):
			data.set_cell(x, y, Tiles.AIR)
	for x in range(px0, px0 + pw):
		for y in range(top, top + 2):
			data.set_cell(x, y, Tiles.PLATFORM)
		for y in range(top + 2, h):
			if not data.is_solid(x, y):
				data.set_cell(x, y, Tiles.STONE)


static func _borders(data: LevelData) -> void:
	var w := data.width
	var h := data.height
	for y in h:
		for x in w:
			if x < 2 or y < 2 or x >= w - 2 or y >= h - 2:
				data.cells[y * w + x] = Tiles.BEDROCK


static func _start_area(data: LevelData) -> void:
	var sx := 8
	var sy := clampi(int(round(data.path[sx + int(BW / 2)] - BH * 0.5)), 3, data.height - BH - 3)
	data.start_tile = Vector2i(sx, sy)
	for y in range(sy - 2, sy + BH + 2):
		for x in range(sx - 2, sx + BW + 6):
			if x >= 2 and y >= 2 and y < data.height - 2:
				data.set_cell(x, y, Tiles.AIR)


# 5. Validation: flood-fill with the balloon's size from the start to the platform, every tile intact.
static func validate(data: LevelData) -> bool:
	var w := data.width
	var h := data.height
	var pw := w + 1
	var ps := PackedInt32Array()
	ps.resize(pw * (h + 1))
	for y in h:
		var run := 0
		var row := y * w
		for x in w:
			if data.cells[row + x] != Tiles.AIR:
				run += 1
			ps[(y + 1) * pw + x + 1] = ps[y * pw + x + 1] + run
	var max_x := w - BW
	var max_y := h - BH
	var cols := max_x + 1
	var start := data.start_tile
	if not _fits(ps, pw, start.x, start.y):
		return false
	var goal_y := data.platform.position.y - BH
	var gx0 := data.platform.position.x - 2
	var gx1 := data.platform.end.x + 2 - BW
	var seen := PackedByteArray()
	seen.resize(cols * (max_y + 1))
	var queue := PackedInt32Array([start.y * cols + start.x])
	seen[start.y * cols + start.x] = 1
	var head := 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var idx := queue[head]
		head += 1
		var x := idx % cols
		var y := int(idx / cols)
		if y >= goal_y - 1 and x >= gx0 and x <= gx1:
			return true
		for d in dirs:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx > max_x or ny > max_y:
				continue
			var ni := ny * cols + nx
			if seen[ni] == 1:
				continue
			seen[ni] = 1
			if _fits(ps, pw, nx, ny):
				queue.append(ni)
	return false


static func _fits(ps: PackedInt32Array, pw: int, x: int, y: int) -> bool:
	return ps[(y + BH) * pw + x + BW] - ps[y * pw + x + BW] - ps[(y + BH) * pw + x] + ps[y * pw + x] == 0
