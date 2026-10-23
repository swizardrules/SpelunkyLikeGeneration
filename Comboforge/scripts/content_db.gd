extends RefCounted
## Data-driven tiles and enemies. Mods are optional JSON files with {"tiles": [...]}.

var tiles: Dictionary = {}
var enemies: Array = []
var messages: Array[String] = []

func load_all() -> void:
	tiles.clear()
	enemies.clear()
	messages.clear()
	var tile_data = _read_json("res://data/tiles.json")
	if tile_data is Array:
		for entry in tile_data:
			_merge_tile(entry)
	var enemy_data = _read_json("res://data/enemies.json")
	if enemy_data is Array:
		for entry in enemy_data:
			if entry is Dictionary and entry.has("name") and entry.has("hp") and entry.has("damage"):
				enemies.append(entry.duplicate(true))
	_load_mods()
	if enemies.is_empty():
		enemies.append({"name": "Wanderer", "hp": 20, "damage": 3})

func _merge_tile(entry: Variant) -> void:
	if not entry is Dictionary:
		return
	if not entry.has("id") or not entry.has("name") or not entry.has("cost") or not entry.has("effects"):
		messages.append("Ignored invalid tile: missing id, name, cost or effects")
		return
	if not entry["effects"] is Array:
		messages.append("Ignored invalid effects for " + str(entry["id"]))
		return
	var id = str(entry["id"])
	if id.is_empty():
		return
	tiles[id] = entry.duplicate(true)

func _load_mods() -> void:
	var locations: Array[String] = [
		OS.get_executable_path().get_base_dir().path_join("mods"),
		"user://mods"
	]
	for location in locations:
		var absolute = ProjectSettings.globalize_path(location)
		if not DirAccess.dir_exists_absolute(absolute):
			continue
		var names = DirAccess.get_files_at(absolute)
		names.sort()
		for filename in names:
			if not filename.to_lower().ends_with(".json"):
				continue
			var payload = _read_json(location.path_join(filename))
			if not payload is Dictionary:
				messages.append("Invalid mod JSON: " + filename)
				continue
			for entry in payload.get("tiles", []):
				_merge_tile(entry)
			messages.append("Loaded mod: " + filename)

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		messages.append("Missing file: " + path)
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		messages.append("Could not open: " + path)
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null:
		messages.append("Could not parse JSON: " + path)
	return parsed
