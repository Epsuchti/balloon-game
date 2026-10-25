extends Node
## Local scoreboard, saved as JSON in user://. Every run is kept in the history; crashes score 0.

const DEFAULT_PATH := "user://scoreboard.json"
const MAX_ENTRIES := 300

var path := DEFAULT_PATH
var entries: Array[Dictionary] = []


func _ready() -> void:
	load_scores()


func load_scores() -> void:
	entries.clear()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		for e: Variant in parsed:
			if e is Dictionary:
				entries.append(e)


func save_scores() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not save scoreboard to %s" % path)
		return
	f.store_string(JSON.stringify(entries, "  "))


## entry: team, gold, time, crew, difficulty, seed, landed, reason
func add(entry: Dictionary) -> Dictionary:
	entry["date"] = Time.get_datetime_string_from_system()
	entries.append(entry)
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()
	save_scores()
	return entry


## Landed runs first, most gold first, fastest time breaks ties.
func ranked() -> Array[Dictionary]:
	var out := entries.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("landed", false)) != bool(b.get("landed", false)):
			return bool(a.get("landed", false))
		if int(a.get("gold", 0)) != int(b.get("gold", 0)):
			return int(a.get("gold", 0)) > int(b.get("gold", 0))
		return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	return out


## Best landed score for one level, or -1.
func best_for(level_seed: int, difficulty: int) -> int:
	var best := -1
	for e in entries:
		if int(e.get("seed", -1)) == level_seed and int(e.get("difficulty", -1)) == difficulty and e.get("landed", false):
			best = maxi(best, int(e.get("gold", 0)))
	return best
