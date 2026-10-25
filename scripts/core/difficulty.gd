class_name Difficulty
extends RefCounted
## Per-difficulty settings. Crew size decides which mechanics are active; difficulty decides how hard they are.

const EASY := 0
const NORMAL := 1
const HARD := 2

const NAMES: Array[String] = ["Easy", "Normal", "Hard"]
const LETTERS: Array[String] = ["E", "N", "H"]
const SEGMENTS: Array[int] = [8, 10, 12]               # level length
const TUNNEL_FACTOR: Array[float] = [3.0, 2.0, 1.4]    # narrowest tunnel, in balloon widths
const WIND: Array[float] = [12.0, 24.0, 40.0]          # wind zone push, px/s^2
const ENEMY_DENSITY: Array[float] = [0.6, 1.0, 1.6]
const PICKUP_MULT: Array[float] = [1.6, 1.0, 0.6]
const LANDING_SPEED: Array[float] = [60.0, 40.0, 25.0] # px/s allowed on touchdown


static func next(d: int) -> int:
	return (d + 1) % 3
