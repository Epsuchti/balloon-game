class_name LevelData
extends RefCounted
## Everything the generator decides about a level. Built once from seed + difficulty.

var level_seed := 0
var difficulty := Difficulty.NORMAL
var attempts := 1
var width := 0
var height := 0
var cells := PackedByteArray()
var path := PackedFloat32Array()       # tunnel center row for each column (tiles)
var col_half := PackedFloat32Array()   # tunnel half-opening for each column (tiles)
var segments: Array[Dictionary] = []   # {x0, x1, tension, breather, night}
var start_tile := Vector2i.ZERO        # top-left tile of the balloon's box at the start
var platform := Rect2i()               # landing platform, in tiles
var pickups: Array[Dictionary] = []    # {pos: Vector2 px, kind: String}
var spawns: Array[Dictionary] = []     # {pos: Vector2 px, kind: String, segment: int}
var wind_zones: Array[Dictionary] = [] # {rect: Rect2 px, force: Vector2}
var set_pieces: Array[Dictionary] = [] # {kind: String, segment: int}


func get_cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return Tiles.BEDROCK
	return cells[y * width + x]


func set_cell(x: int, y: int, mat: int) -> void:
	if x >= 0 and y >= 0 and x < width and y < height:
		cells[y * width + x] = mat


func is_solid(x: int, y: int) -> bool:
	return get_cell(x, y) != Tiles.AIR


func segment_at_px(px: float) -> int:
	return clampi(int(px / (Tiles.SEG_W * Tiles.SIZE)), 0, segments.size() - 1)


## Pixel position of the middle of the balloon's box at the start.
func start_position() -> Vector2:
	return Vector2(
		(start_tile.x + Tiles.BALLOON_W * 0.5) * Tiles.SIZE,
		(start_tile.y + Tiles.BALLOON_H * 0.5) * Tiles.SIZE)


func platform_px() -> Rect2:
	return Rect2(Vector2(platform.position) * Tiles.SIZE, Vector2(platform.size) * Tiles.SIZE)


func size_px() -> Vector2:
	return Vector2(width, height) * Tiles.SIZE


func checksum() -> int:
	return hash(cells)
