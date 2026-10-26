extends Node
## Placeholder pixel art, generated at startup from tiny ASCII sprites and procedural drawing.
## Swap any of these for real textures later; callers only ever ask for a Texture2D.

const TILE_COLORS := {
	Tiles.DIRT: [Color("8a5a34"), Color("6b4226"), Color("a06a3c"), Color("4e2f1a")],
	Tiles.STONE: [Color("7a7a86"), Color("5c5c68"), Color("94949f"), Color("3e3e48")],
	Tiles.BEDROCK: [Color("3a3440"), Color("2a2530"), Color("4a4252"), Color("17131b")],
	Tiles.PLATFORM: [Color("b07a3c"), Color("8a5a2a"), Color("d09a58"), Color("4e3016")],
}
const GRASS := [Color("6cc04a"), Color("4a9a34")]
const CRACKS: Array[Vector2i] = [
	Vector2i(2, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(4, 4), Vector2i(5, 4),
	Vector2i(4, 5), Vector2i(2, 6), Vector2i(3, 5), Vector2i(6, 3),
]

const SPRITES := {
	"fuel": [
		"..kk...",
		".rrrrr.",
		"rrwrrrr",
		"rrrwrrr",
		"rrrrwrr",
		"rrrrrrr",
		"rrrrrrr",
		".rrrrr.",
	],
	"ammo": [
		"dddddddd",
		"dggggggd",
		"dgyyyygd",
		"dggggggd",
		"dgyyyygd",
		"dggggggd",
		"dddddddd",
	],
	"kit": [
		"..kkk..",
		"..k.k..",
		"lllllll",
		"llleell",
		"lleeeel",
		"llleell",
		"lllllll",
	],
	"gold": [
		".ooo.",
		"oylyo",
		"oyyyo",
		"oyyyo",
		".ooo.",
	],
	"nugget": [
		".yl.",
		"yyyo",
		".oo.",
	],
	"bat_0": [
		"m.........m",
		"mm.......mm",
		"mmm.bbb.mmm",
		".mmmbebmmm.",
		"....bbb....",
		"...........",
	],
	"bat_1": [
		"...........",
		"....bbb....",
		"...mbebm...",
		".mmmbbbmmm.",
		"mmm.....mmm",
		"m.........m",
	],
	"harpy_0": [
		"ww.......ww",
		"www.ppp.www",
		".wwpppepww.",
		"..wppppyy..",
		"...ppppp...",
		"...ppppp...",
		"....p.p....",
		"....y.y....",
	],
	"harpy_1": [
		"...........",
		"....ppp....",
		"...pppep...",
		"..wppppyy..",
		"wwwppppppww",
		"ww.ppppp.ww",
		"....p.p....",
		"....y.y....",
	],
	"goblin_0": [
		".lllllll.",
		"lllllllll",
		"..|...|..",
		"...GGG...",
		"..GeGeG..",
		"..GGGGG..",
		"...bbb...",
		"..GbbbG..",
		"...b.b...",
		"...G.G...",
	],
	"goblin_1": [
		"..lllll..",
		"lllllllll",
		"..|...|..",
		"...GGG...",
		"..GeGeG..",
		"..GGGGG..",
		"...bbb...",
		".G.bbb.G.",
		"...b.b...",
		"...G.G...",
	],
	"bomber_0": [
		"....s....",
		"....f....",
		"...kkk...",
		"w.kkkkk.w",
		"wwkkekkww",
		"w.kkkkk.w",
		"..kkkkk..",
		"...kkk...",
	],
	"bomber_1": [
		"....y....",
		"....f....",
		"...kkk...",
		"..kkkkk..",
		"wwkkekkww",
		"wwkkkkkww",
		"..kkkkk..",
		"...kkk...",
	],
}
const SPRITE_PALETTE := {
	"k": Color("33303a"), "r": Color("d03a2a"), "w": Color("f07a5a"),
	"d": Color("3e4a22"), "g": Color("6a7a38"), "y": Color("f0c030"),
	"o": Color("b07a18"), "l": Color("fff0a0"), "m": Color("5a3a6a"),
	"b": Color("3a2a4a"), "e": Color("ff4040"), "p": Color("8a5a7a"),
	"G": Color("6aa040"), "|": Color("4a3a2a"), "s": Color("ffe080"), "f": Color("8a6a4a"),
}
# Wings and leaves get their own colors per sprite.
const SPRITE_OVERRIDES := {
	"harpy": {"w": Color("c09060"), "y": Color("f0b030")},
	"goblin": {"l": Color("9ac050"), "b": Color("6a4a2a")},
	"bomber": {"w": Color("e8e8f0"), "y": Color("ffb030")},
}

# Crew sprite frames: idle, walk1, walk2, jump, wave1, wave2, at station.
const CREW_HEAD := ["..hhh..", ".hhhhh.", ".hsese.", "..sss.."]
const CREW_BODIES := [
	["..ccc..", ".ccccc.", ".scccs.", "..ccc..", "..d.d..", "..d.d.."],
	["..ccc..", ".ccccc.", ".scccs.", "..ccc..", ".d..d..", ".d...d."],
	["..ccc..", ".ccccc.", ".scccs.", "..ccc..", "..dd...", "..d.d.."],
	["s.ccc.s", ".ccccc.", "..ccc..", "..ccc..", ".d...d.", "d.....d"],
	["s.ccc.s", "sccccc.", "..ccc..", "..ccc..", "..d.d..", "..d.d.."],
	["..ccc.s", ".ccccs.", ".sccc..", "..ccc..", "..d.d..", "..d.d.."],
	["..ccc..", ".cccccs", ".ccccc.", "..ccc..", "..d.d..", "..d.d.."],
]

var _sprites := {}
var _crew := {}
var _envelopes := {}
var _tileset: TileSet
var _glow: Texture2D
var _cone: Texture2D
var _basket_back: Texture2D
var _basket_front: Texture2D
var _cave_wall: Texture2D


func make(rows: Array, palette: Dictionary) -> ImageTexture:
	var h := rows.size()
	var w: int = rows[0].length()
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var row: String = rows[y]
		for x in w:
			var ch := row[x]
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	return ImageTexture.create_from_image(img)


func sprite(sprite_name: String) -> Texture2D:
	if not _sprites.has(sprite_name):
		var palette := SPRITE_PALETTE.duplicate()
		var base := sprite_name.split("_")[0]
		if SPRITE_OVERRIDES.has(base):
			palette.merge(SPRITE_OVERRIDES[base], true)
		_sprites[sprite_name] = make(SPRITES[sprite_name], palette)
	return _sprites[sprite_name]


func crew_frames(color: Color) -> Array[Texture2D]:
	var key := color.to_html()
	if not _crew.has(key):
		var palette := {
			"h": Color("4a3020"), "s": Color("f0c8a0"), "e": Color("201820"),
			"c": color, "d": Color("3a3448"),
		}
		var frames: Array[Texture2D] = []
		for body: Array in CREW_BODIES:
			frames.append(make(CREW_HEAD + body, palette))
		_crew[key] = frames
	return _crew[key]


static func atlas_coords(mat: int, mask: int, damaged: bool) -> Vector2i:
	return Vector2i(mask, (mat - 1) * 2 + int(damaged))


func terrain_tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var img := Image.create_empty(16 * 8, 8 * 8, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for mat in range(1, 5):
		for damaged in 2:
			for mask in 16:
				var at := atlas_coords(mat, mask, damaged == 1)
				_draw_tile(img, at.x * 8, at.y * 8, mat, mask, damaged == 1, rng)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(8, 8)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(8, 8)
	ts.add_source(src, 0)
	var square := PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
	for y in 8:
		for x in 16:
			var c := Vector2i(x, y)
			src.create_tile(c)
			var td := src.get_tile_data(c, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, square)
	_tileset = ts
	return ts


func _draw_tile(img: Image, ox: int, oy: int, mat: int, mask: int, damaged: bool, rng: RandomNumberGenerator) -> void:
	var pal: Array = TILE_COLORS[mat]
	var top_open := (mask & 1) == 0
	var right_open := (mask & 2) == 0
	var bottom_open := (mask & 4) == 0
	var left_open := (mask & 8) == 0
	for y in 8:
		for x in 8:
			var c: Color = pal[0]
			var r := rng.randf()
			if mat == Tiles.PLATFORM:
				c = pal[2] if y == 0 else (pal[1] if y == 4 or (x + (y / 4) * 4) % 8 == 0 else pal[0])
			elif r < 0.18:
				c = pal[1]
			elif r < 0.3:
				c = pal[2]
			if (top_open and y == 0) or (bottom_open and y == 7) or (left_open and x == 0) or (right_open and x == 7):
				c = pal[3]
			elif top_open and y == 1 and mat != Tiles.PLATFORM:
				c = pal[2]
			if mat == Tiles.DIRT and top_open and (y < 2 or (y == 2 and rng.randf() < 0.4)):
				c = GRASS[0] if y == 0 else GRASS[1]
			if damaged and CRACKS.has(Vector2i(x, y)):
				c = pal[3]
			img.set_pixel(ox + x, oy + y, c)


func envelope_texture(size: float) -> Texture2D:
	var key := int(round(size * 20.0))
	if _envelopes.has(key):
		return _envelopes[key]
	var f := lerpf(0.72, 1.0, clampf((key / 20.0 - 0.6) / 0.4, 0.0, 1.0))
	var rx := 44.0 * f
	var ry := 36.0 * f
	var w := int(rx * 2.0) + 2
	var h := int(ry * 2.0) + 4
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var red := Color("d94a3a")
	var cream := Color("f3e3c3")
	var inside := func(x: int, y: int) -> float:
		var u := (x + 0.5 - w * 0.5) / rx
		var v := (y + 0.5 - ry - 1.0) / ry
		var half := sqrt(maxf(0.0, 1.0 - v * v))
		if v > 0.0:
			half = maxf(half * (1.0 - 0.45 * v), 0.3 if v < 1.08 else 0.0)
		return u / half if half > 0.0 and absf(u) <= half else 9.0
	for y in h:
		for x in w:
			var s: float = inside.call(x, y)
			if s > 1.0:
				continue
			var v := (y + 0.5 - ry - 1.0) / ry
			var gore := int(floor((asin(clampf(s, -1.0, 1.0)) + PI / 2.0) / (PI / 6.0)))
			var c := red if gore % 2 == 0 else cream
			if s < -0.55 and v < 0.1:
				c = c.lightened(0.18)
			elif s > 0.7:
				c = c.darkened(0.22)
			if v > 0.95:
				c = Color("6a4a2a")
			var edge: bool = inside.call(x - 1, y) > 1.0 or inside.call(x + 1, y) > 1.0 \
				or inside.call(x, y - 1) > 1.0 or inside.call(x, y + 1) > 1.0
			if edge:
				c = Color("5a2020")
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_envelopes[key] = tex
	return tex


## Wicker back wall of the basket (96x38), drawn behind the crew.
func basket_back() -> Texture2D:
	if _basket_back != null:
		return _basket_back
	var img := Image.create_empty(96, 38, false, Image.FORMAT_RGBA8)
	for y in 38:
		for x in 96:
			var c := Color("6a4428")
			if (y / 3 + x / 6) % 2 == 0:
				c = Color("744c2e")
			if y % 3 == 0:
				c = Color("57371f")
			if y < 2:
				c = Color("8a5a34")
			img.set_pixel(x, y, c)
	# Hold: a crate frame at the bottom middle.
	for x in range(38, 58):
		img.set_pixel(x, 26, Color("3a2614"))
	for y in range(26, 34):
		img.set_pixel(38, y, Color("3a2614"))
		img.set_pixel(57, y, Color("3a2614"))
	_basket_back = ImageTexture.create_from_image(img)
	return _basket_back


## Rails, floor and front lip of the basket (96x38), drawn in front of the crew.
func basket_front() -> Texture2D:
	if _basket_front != null:
		return _basket_front
	var img := Image.create_empty(96, 38, false, Image.FORMAT_RGBA8)
	var wood := Color("b07a3c")
	var dark := Color("6a4220")
	# Floor (y 34..37 => local 16..20)
	for y in range(34, 38):
		for x in 96:
			img.set_pixel(x, y, dark if y == 37 or (x % 8 == 0) else Color("8a5a2a"))
	# Rails: posts at both ends from local y 4 to 16 (image 22..34), top bar at 22.
	for side in [0, 93]:
		for y in range(22, 34):
			for x in range(side, side + 3):
				img.set_pixel(x, y, wood if x != side + 2 else dark)
		for x in range(side, side + 3):
			img.set_pixel(x, 22, Color("d09a58"))
	# Deck plank (local y -2..0 => image 16..18), x -36..36 => 12..84
	for x in range(12, 84):
		img.set_pixel(x, 16, Color("d09a58"))
		img.set_pixel(x, 17, wood)
	for x in [14, 81]:
		for y in range(18, 34):
			img.set_pixel(x, y, dark)
	_basket_front = ImageTexture.create_from_image(img)
	return _basket_front


## Dark cave wall shown behind the tunnel.
func cave_wall() -> Texture2D:
	if _cave_wall != null:
		return _cave_wall
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for y in 64:
		for x in 64:
			var c := Color("2e2230")
			var r := rng.randf()
			if r < 0.15:
				c = Color("261c28")
			elif r < 0.25:
				c = Color("362a38")
			if (x % 16 == 0) or ((y % 16 == 0) and x % 16 < 15):
				c = Color("231a25")
			img.set_pixel(x, y, c)
	_cave_wall = ImageTexture.create_from_image(img)
	return _cave_wall


func glow_texture() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_glow = t
	return _glow


## Flashlight cone pointing right from the texture's center.
func cone_texture() -> Texture2D:
	if _cone == null:
		var n := 256
		var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x - n / 2.0, y - n / 2.0)
				var a := 0.0
				if d.x > 0.0:
					var ang := absf(d.angle())
					var fall := 1.0 - d.length() / (n / 2.0)
					a = clampf(fall, 0.0, 1.0) * clampf((0.42 - ang) / 0.14, 0.0, 1.0)
				a = maxf(a, clampf(1.0 - d.length() / 14.0, 0.0, 1.0))
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_cone = ImageTexture.create_from_image(img)
	return _cone


## The boss: a big, grumpy, fuzzy blob (after the team's mascot). Frames: 0-1 idle with arms
## bobbing, 2 winding up a charge (arms up, mouth wide).
func boss_frames() -> Array[Texture2D]:
	if _boss.is_empty():
		for f in 3:
			_boss.append(ImageTexture.create_from_image(_boss_image(f)))
	return _boss


var _boss: Array[Texture2D] = []


func _boss_image(frame: int) -> Image:
	var w := 64
	var h := 56
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var ink := Color("1a1418")
	var fur := Color("f4f1ea")
	var shade := Color("d6d0c6")
	var c := Vector2(32, 27)
	# Fuzzy, slightly pear-shaped body with a bump on top.
	var inside := func(x: float, y: float) -> bool:
		var d := Vector2(x, y) - c
		var a := d.angle()
		var rx := 25.0 + (2.0 if d.y > 0.0 else 0.0)
		var ry := 20.0
		var r := 1.0 + 0.045 * sin(a * 11.0) + 0.03 * sin(a * 7.0 + 1.3)
		var bump := Vector2(x, y) - Vector2(38, 8)
		return (d.x / rx) * (d.x / rx) + (d.y / ry) * (d.y / ry) <= r * r or bump.length() < 6.0
	for y in h:
		for x in w:
			if inside.call(x + 0.5, y + 0.5):
				var col := fur
				if (x - c.x) * 0.5 + (y - c.y) > 14.0:
					col = shade
				img.set_pixel(x, y, col)
	# Outline: body pixels next to the outside.
	var body := img.duplicate() as Image
	for y in h:
		for x in w:
			if body.get_pixel(x, y).a == 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + o
				if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or body.get_pixel(p.x, p.y).a == 0.0:
					img.set_pixel(x, y, ink)
					break
	# Fur strokes along the top edge.
	for i in 14:
		var a := PI + 0.25 + i * (PI - 0.5) / 13.0
		var p := c + Vector2(cos(a) * 26.0, sin(a) * 21.0)
		_px(img, p.x, p.y - 1.0, ink)
		_px(img, p.x + (1.0 if i % 2 == 0 else -1.0), p.y - 2.0, ink)
	# Little hair tuft lines inside the body.
	for p in [Vector2(14, 24), Vector2(50, 26), Vector2(20, 40), Vector2(44, 40), Vector2(30, 12)]:
		_px(img, p.x, p.y, shade.darkened(0.25))
		_px(img, p.x + 1, p.y - 1, shade.darkened(0.25))
	# Feet and stubby arms.
	for fx in [24, 40]:
		for y in range(46, 50):
			for x in range(fx - 4, fx + 5):
				if Vector2((x - fx) / 4.5, (y - 47.5) / 2.5).length() <= 1.0:
					img.set_pixel(x, y, fur if y < 48 else shade)
		_line(img, Vector2(fx - 4, 49), Vector2(fx + 4, 49), ink)
		_line(img, Vector2(fx - 5, 47), Vector2(fx - 4, 49), ink)
		_line(img, Vector2(fx + 5, 47), Vector2(fx + 4, 49), ink)
	var arm_y := 2.0 if frame == 1 else (-6.0 if frame == 2 else 0.0)
	_thick(img, Vector2(8, 30), Vector2(2, 34 + arm_y), ink, 1.5)
	_thick(img, Vector2(56, 30), Vector2(62, 34 + arm_y), ink, 1.5)
	# Eyes: white with an outline, pupils looking down and in.
	for ex in [24, 40]:
		for y in range(17, 28):
			for x in range(ex - 5, ex + 6):
				var d := Vector2(x - ex, y - 22).length()
				if d <= 4.6:
					img.set_pixel(x, y, Color.WHITE if d < 3.6 else ink)
		var px: int = ex + (1 if ex < 32 else -1)
		for y in range(22, 25):
			for x in range(px - 1, px + 1):
				img.set_pixel(x, y, ink)
	# Angry eyebrows slanting down to the middle; they also cut off the top of the eyes.
	_thick(img, Vector2(17, 14), Vector2(29, 19), ink, 1.6)
	_thick(img, Vector2(47, 14), Vector2(35, 19), ink, 1.6)
	for x in range(18, 30):
		for y in range(15, int(14.0 + (x - 17) * 5.0 / 12.0) + 2):
			if img.get_pixel(x, y) == Color.WHITE:
				img.set_pixel(x, y, fur)
	for x in range(35, 47):
		for y in range(15, int(14.0 + (47 - x) * 5.0 / 12.0) + 2):
			if img.get_pixel(x, y) == Color.WHITE:
				img.set_pixel(x, y, fur)
	# Gritted-teeth grimace, corners turned down; wider when winding up.
	var mw := 13 if frame == 2 else 11
	var mh := 6 if frame == 2 else 4
	var top := 32
	for x in range(32 - mw, 32 + mw + 1):
		var droop := int(pow(absf(x - 32) / float(mw), 3.0) * 3.0)
		for y in range(top + droop - int(absf(x - 32) / float(mw) * 1.5), top + mh + droop):
			img.set_pixel(x, y, Color.WHITE)
	for x in range(32 - mw - 1, 32 + mw + 2):
		var xx := clampi(x, 32 - mw, 32 + mw)
		var droop := int(pow(absf(xx - 32) / float(mw), 3.0) * 3.0)
		var y0 := top + droop - int(absf(xx - 32) / float(mw) * 1.5) - 1
		img.set_pixel(x, y0, ink)
		img.set_pixel(x, top + mh + droop, ink)
		if (x - 32) % 3 == 0 and absf(x - 32) < mw:
			for y in range(y0 + 1, top + mh + droop):
				img.set_pixel(x, y, ink)
	_line(img, Vector2(32 - mw, top + mh / 2 + 3), Vector2(32 + mw, top + mh / 2 + 3), Color(0, 0, 0, 0))
	for x in range(32 - mw + 1, 32 + mw):
		var droop := int(pow(absf(x - 32) / float(mw), 3.0) * 3.0)
		var mid := top + droop + mh / 2 - int(absf(x - 32) / float(mw) * 0.75)
		img.set_pixel(x, mid, ink)
	return img


func _px(img: Image, x: float, y: float, col: Color) -> void:
	var xi := int(x)
	var yi := int(y)
	if xi >= 0 and yi >= 0 and xi < img.get_width() and yi < img.get_height():
		img.set_pixel(xi, yi, col)


func _line(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		_px(img, p.x, p.y, col)


func _thick(img: Image, a: Vector2, b: Vector2, col: Color, r: float) -> void:
	var n := int(a.distance_to(b) * 2.0) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for y in range(int(p.y - r), int(p.y + r) + 1):
			for x in range(int(p.x - r), int(p.x + r) + 1):
				if Vector2(x + 0.5, y + 0.5).distance_to(p) <= r:
					_px(img, x, y, col)
