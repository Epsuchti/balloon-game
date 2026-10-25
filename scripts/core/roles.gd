class_name Roles
extends RefCounted
## Stations on the balloon. Their ids double as unlock order: the first three are always there,
## then one more unfolds for each extra player.

const BURNER := 0
const SHRINKER := 1
const PROPELLER := 2
const TURRET := 3
const FISHING := 4
const REPAIR := 5
const LAMP := 6
const PROPELLER2 := 7
const ROAM := -1

const COUNT := 8
const NAMES: Array[String] = [
	"Burner", "Shrinker", "Propeller", "Shooter turret",
	"Fishing rod", "Repair kit", "Lamp", "Second propeller",
]
const UNLOCKS: Array[String] = [
	"", "", "", "Enemies spawn from the next segment",
	"Enemy drops can be caught", "Damage stays until repaired",
	"Night sections ahead", "One propeller per side",
]


## Number of stations on the balloon for a crew of this size.
static func station_count(crew: int) -> int:
	return clampi(crew, 3, COUNT)


static func name_of(role: int) -> String:
	return "Roam" if role < 0 else NAMES[role]
