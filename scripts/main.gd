extends Node
## Root scene. Screens are swapped in and out underneath it by the Game autoload.


func _ready() -> void:
	Game.register_root(self)
	Game.goto("menu")
