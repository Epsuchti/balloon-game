class_name Tiles
extends RefCounted
## Tile size, materials and level dimensions shared by the generator, the terrain and the balloon.

const SIZE := 8
const SEG_W := 80          # tiles per level segment
const LEVEL_H := 150       # level height in tiles
const BALLOON_W := 18      # balloon bounding box in tiles (144 px at Balloon.SCALE 1.5)
const BALLOON_H := 23      # (180 px, plus a little headroom)

const AIR := 0
const DIRT := 1
const STONE := 2
const BEDROCK := 3
const PLATFORM := 4

const MAX_HP: Array[float] = [0.0, 3.0, 8.0, INF, INF]


static func is_breakable(mat: int) -> bool:
	return mat == DIRT or mat == STONE
