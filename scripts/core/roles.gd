class_name Roles
extends RefCounted
## Stations on the balloon. Every station is on board at any crew size, so a small crew has to
## run between them; a big crew can man them all.

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
	"Burner", "Shrinker", "Right propeller", "Shooter turret",
	"Fishing rod", "Repair kit", "Lamp", "Left propeller",
]
## Each station's colour: its floor plate in the basket and its name tag.
const COLORS: Array[Color] = [
	Color("f07a20"), Color("c89058"), Color("6ec3f0"), Color("a0c050"),
	Color("50c8b4"), Color("e05050"), Color("f0d060"), Color("6ec3f0"),
]

## What a breakdown of each station does until someone holds A on it to fix it.
const BREAKDOWNS: Array[String] = [
	"The pilot light went out", "The shrinker rope snagged and pulls the envelope in",
	"The right propeller jammed: no flying right", "The turret jammed", "The fishing line tangled",
	"The envelope sprang a leak", "The lamp flickered out", "The left propeller jammed: no flying left",
]


## Number of stations on the balloon. Always all of them; kept as a function for the setup screen.
static func station_count(_crew: int) -> int:
	return COUNT


static func name_of(role: int) -> String:
	return "Roam" if role < 0 else NAMES[role]
