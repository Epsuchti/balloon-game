extends Node
## Game flow: which screen is showing, the settings for the next run, and the UI theme.

const SCREENS := {
	"menu": "res://scripts/ui/main_menu.gd",
	"setup": "res://scripts/ui/setup_screen.gd",
	"run": "res://scripts/run/run.gd",
	"scores": "res://scripts/ui/scoreboard_screen.gd",
}
const ADJECTIVES: Array[String] = [
	"Brave", "Fluffy", "Daring", "Sleepy", "Mighty", "Wobbly", "Lucky", "Sneaky",
	"Golden", "Breezy", "Happy", "Rusty", "Soaring", "Giddy", "Plucky", "Toasty",
]
const ANIMALS: Array[String] = [
	"Pelicans", "Otters", "Gophers", "Ravens", "Llamas", "Badgers", "Puffins", "Geckos",
	"Walruses", "Moles", "Herons", "Yaks", "Ferrets", "Newts", "Capybaras", "Owls",
]

var level_seed := 0
var difficulty := Difficulty.NORMAL
var fixed_level := false   # the seed came from a level code or a scoreboard replay
var team_name := ""
var _root: Node
var _screen: Node


func _ready() -> void:
	randomize()
	level_seed = random_seed()
	team_name = random_team_name()
	get_tree().root.theme = _make_theme()


func register_root(root: Node) -> void:
	_root = root


func goto(screen: String) -> void:
	get_tree().paused = false
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = load(SCREENS[screen]).new()
	_root.add_child(_screen)


func random_seed() -> int:
	return randi() & LevelCode.SEED_MASK


func random_team_name() -> String:
	return ADJECTIVES[randi() % ADJECTIVES.size()] + " " + ANIMALS[randi() % ANIMALS.size()]


func level_code() -> String:
	return LevelCode.encode(level_seed, difficulty)


## Sets the next level from a code. Returns false if the code is not valid.
func use_level_code(code: String) -> bool:
	var parsed := LevelCode.decode(code)
	if parsed.is_empty():
		return false
	use_level(parsed["seed"], parsed["difficulty"])
	return true


func use_level(s: int, d: int) -> void:
	level_seed = s
	difficulty = d
	fixed_level = true


func use_random_level() -> void:
	level_seed = random_seed()
	fixed_level = false


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 10
	var normal := _box(Color("2b2238"), Color("5c4a78"))
	var hover := _box(Color("3d3052"), Color("f0c040"))
	var pressed := _box(Color("f0c040"), Color("f0c040"))
	var focus := _box(Color(0, 0, 0, 0), Color("f0c040"))
	focus.draw_center = false
	for t in ["Button"]:
		theme.set_stylebox("normal", t, normal)
		theme.set_stylebox("hover", t, hover)
		theme.set_stylebox("pressed", t, pressed)
		theme.set_stylebox("focus", t, focus)
		theme.set_stylebox("disabled", t, _box(Color("1c1626"), Color("3a3048")))
		theme.set_color("font_color", t, Color("f3e9d2"))
		theme.set_color("font_hover_color", t, Color.WHITE)
		theme.set_color("font_pressed_color", t, Color("2b2238"))
		theme.set_color("font_focus_color", t, Color.WHITE)
	theme.set_stylebox("panel", "PanelContainer", _box(Color(0.1, 0.08, 0.14, 0.88), Color("5c4a78")))
	theme.set_stylebox("panel", "Panel", _box(Color(0.1, 0.08, 0.14, 0.88), Color("5c4a78")))
	theme.set_stylebox("normal", "LineEdit", _box(Color("1c1626"), Color("5c4a78")))
	theme.set_stylebox("focus", "LineEdit", _box(Color("1c1626"), Color("f0c040")))
	theme.set_color("font_color", "Label", Color("f3e9d2"))
	theme.set_color("font_outline_color", "Label", Color("1a1422"))
	theme.set_constant("outline_size", "Label", 3)
	return theme


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	return s
