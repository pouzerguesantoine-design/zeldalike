extends Node
## État persistant de la partie (autoload « GameState ») : stats du joueur, et plus tard
## inventaire / équipement (jalons 3 et 6). Sauvegarde JSON dans user://.
##
## Sauvegarde : `saving` est émis juste avant l'écriture pour que chaque système range
## son état dans `data` ; `loaded` est émis après la lecture pour qu'il le relise.

## Juste avant l'écriture de la sauvegarde.
signal saving
## Juste après le chargement d'une sauvegarde.
signal loaded
## Les stats du joueur ont changé (XP gagnée, chargement, nouvelle partie).
signal stats_changed

const SAVE_PATH := "user://savegame.json"
const BASE_PLAYER_STATS: PlayerStats = preload("res://resources/stats/player_base_stats.tres")
## XP donnée par le raccourci de test F1 (builds de debug uniquement).
const DEBUG_XP_AMOUNT := 50

## Données sérialisables de la partie, rangées par section ("player", "world"…).
var data: Dictionary = {}
## Stats courantes du joueur (copie de BASE_PLAYER_STATS qui évolue).
var player_stats: PlayerStats


func _ready() -> void:
	new_game()


func _unhandled_input(event: InputEvent) -> void:
	# Raccourcis de test, absents des exports « release ».
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("debug_add_xp"):
		add_xp(DEBUG_XP_AMOUNT)
		print("[debug] +%d XP → niveau %d (%d / %d XP)" % [DEBUG_XP_AMOUNT, player_stats.level, player_stats.xp, player_stats.get_xp_to_next()])
	elif event.is_action_pressed("debug_save"):
		print("[debug] sauvegarde : ", "OK" if save_game() else "échec")
	elif event.is_action_pressed("debug_load"):
		print("[debug] chargement : ", "OK" if load_game() else "aucune sauvegarde")


func new_game() -> void:
	data = {}
	player_stats = BASE_PLAYER_STATS.duplicate() as PlayerStats
	stats_changed.emit()


## Donne de l'XP au joueur ; émet EventBus.level_up pour chaque niveau gagné.
func add_xp(amount: int) -> void:
	var previous_level := player_stats.level
	player_stats.add_xp(amount)
	for new_level in range(previous_level + 1, player_stats.level + 1):
		EventBus.level_up.emit(new_level)
	stats_changed.emit()


func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func save_game(path: String = SAVE_PATH) -> bool:
	saving.emit()
	data["player_stats"] = player_stats.to_dict()
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
	player_stats = BASE_PLAYER_STATS.duplicate() as PlayerStats
	player_stats.from_dict(data.get("player_stats", {}))
	stats_changed.emit()
	loaded.emit()
	return true
