extends Node
## État persistant de la partie (autoload « GameState ») : inventaire, équipement,
## stats du joueur (remplis aux jalons 2, 3 et 6) et sauvegarde JSON dans user://.

const SAVE_PATH := "user://savegame.json"

## Données sérialisables de la partie, rangées par section ("player", "inventory", "world"…).
var data: Dictionary = {}


func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func save_game(path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Sauvegarde impossible (%s) : %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func load_game(path: String = SAVE_PATH) -> bool:
	if not has_save(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Sauvegarde corrompue : %s" % path)
		return false
	data = parsed
	return true
