extends SceneTree
## Renders a generated level to a PNG for quick inspection:
##   godot --headless --path . -s tools/render_level.gd -- N-8F3K2Q out.png

const COLORS := [Color("1c1626"), Color("8a5a34"), Color("7a7a86"), Color("3a3440"), Color("f0c040")]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var code := args[0] if args.size() > 0 else "N-222223"
	var out := args[1] if args.size() > 1 else "level.png"
	var parsed := LevelCode.decode(code)
	var data := LevelGenerator.generate(parsed["seed"], parsed["difficulty"])
	var img := Image.create_empty(data.width, data.height, false, Image.FORMAT_RGB8)
	for y in data.height:
		for x in data.width:
			img.set_pixel(x, y, COLORS[data.get_cell(x, y)])
	for x in data.width:
		img.set_pixel(x, int(data.path[x]), Color(0.3, 0.6, 1.0))
	for z: Dictionary in data.wind_zones:
		var r: Rect2 = z["rect"]
		for x in range(int(r.position.x / 8), int(r.end.x / 8)):
			img.set_pixel(clampi(x, 0, data.width - 1), clampi(int(r.position.y / 8), 0, data.height - 1), Color.CYAN)
	for p: Dictionary in data.pickups:
		var v: Vector2 = p["pos"] / 8.0
		img.set_pixel(clampi(int(v.x), 0, data.width - 1), clampi(int(v.y), 0, data.height - 1), Color.YELLOW if p["kind"] == "gold" else Color.GREEN)
	for s: Dictionary in data.spawns:
		var v: Vector2 = s["pos"] / 8.0
		img.set_pixel(clampi(int(v.x), 0, data.width - 1), clampi(int(v.y), 0, data.height - 1), Color.RED)
	for y in Tiles.BALLOON_H:
		for x in Tiles.BALLOON_W:
			if x == 0 or y == 0 or x == Tiles.BALLOON_W - 1 or y == Tiles.BALLOON_H - 1:
				img.set_pixel(data.start_tile.x + x, data.start_tile.y + y, Color.WHITE)
	img.resize(data.width * 2, data.height * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("saved ", out, " attempts=", data.attempts)
	quit()
