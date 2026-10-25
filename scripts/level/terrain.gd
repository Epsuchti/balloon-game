class_name Terrain
extends TileMapLayer
## The level's tiles. Every tile has hit points by material and can be broken at runtime;
## the neighbours then pick a new edge tile so the hole gets proper edges.

signal tile_broken(cell: Vector2i, mat: int)

var data: LevelData
var hp := PackedFloat32Array()


func setup(level: LevelData) -> void:
	data = level
	tile_set = Art.terrain_tileset()
	hp.resize(data.cells.size())
	for i in data.cells.size():
		hp[i] = Tiles.MAX_HP[data.cells[i]]
	for y in data.height:
		for x in data.width:
			if data.cells[y * data.width + x] != Tiles.AIR:
				_paint(x, y)


func _paint(x: int, y: int) -> void:
	var m := data.get_cell(x, y)
	var cell := Vector2i(x, y)
	if m == Tiles.AIR:
		erase_cell(cell)
		return
	var mask := 0
	if data.is_solid(x, y - 1):
		mask |= 1
	if data.is_solid(x + 1, y):
		mask |= 2
	if data.is_solid(x, y + 1):
		mask |= 4
	if data.is_solid(x - 1, y):
		mask |= 8
	var damaged := Tiles.is_breakable(m) and hp[y * data.width + x] < Tiles.MAX_HP[m] * 0.6
	set_cell(cell, 0, Art.atlas_coords(m, mask, damaged))


func cell_at(world_pos: Vector2) -> Vector2i:
	return local_to_map(to_local(world_pos))


func material_at(cell: Vector2i) -> int:
	return data.get_cell(cell.x, cell.y)


func is_solid_at(world_pos: Vector2) -> bool:
	var c := cell_at(world_pos)
	return data.is_solid(c.x, c.y)


## Returns true if the tile broke.
func damage_cell(cell: Vector2i, amount: float) -> bool:
	var m := data.get_cell(cell.x, cell.y)
	if not Tiles.is_breakable(m):
		return false
	var i := cell.y * data.width + cell.x
	var limit := Tiles.MAX_HP[m] * 0.6
	var was_damaged := hp[i] < limit
	hp[i] -= amount
	if hp[i] <= 0.0:
		hp[i] = 0.0
		data.cells[i] = Tiles.AIR
		erase_cell(cell)
		for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var n := cell + d
			if data.is_solid(n.x, n.y) and n.x >= 0 and n.y >= 0 and n.x < data.width and n.y < data.height:
				_paint(n.x, n.y)
		tile_broken.emit(cell, m)
		return true
	if not was_damaged and hp[i] < limit:
		_paint(cell.x, cell.y)
	return false


## Damages every tile within radius (px). Returns how many broke.
func damage_circle(world_center: Vector2, radius: float, amount: float) -> int:
	var c := cell_at(world_center)
	var r := int(ceil(radius / Tiles.SIZE))
	var broken := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if Vector2(dx, dy).length() * Tiles.SIZE <= radius:
				if damage_cell(c + Vector2i(dx, dy), amount):
					broken += 1
	return broken
