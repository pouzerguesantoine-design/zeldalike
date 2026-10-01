extends Node
## État persistant de la partie (autoload « GameState ») : stats du joueur, équipement,
## inventaire et rubis. Sauvegarde JSON dans user://.
##
## Sauvegarde : `saving` est émis juste avant l'écriture pour que chaque système range
## son état dans `data` ; `loaded` est émis après la lecture pour qu'il le relise.

## Juste avant l'écriture de la sauvegarde.
signal saving
## Juste après le chargement d'une sauvegarde.
signal loaded
## Les stats du joueur ont changé (XP gagnée, chargement, nouvelle partie).
signal stats_changed
## L'arme équipée a changé.
signal equipment_changed(weapon: WeaponData)
## L'inventaire ou le nombre de rubis a changé.
signal inventory_changed
## La qualité graphique a changé (0 = Bas, 1 = Moyen, 2 = Haut).
signal graphics_quality_changed(quality: int)

## Qualité graphique : réglée dans le menu pause ou l'écran titre.
enum Quality { BAS, MOYEN, HAUT }
const QUALITY_NAMES: Array[String] = ["Bas", "Moyen", "Haut"]
## Réglages du joueur (indépendants des sauvegardes de partie).
const SETTINGS_PATH := "user://settings.cfg"

const SAVE_PATH := "user://savegame.json"
const LEVEL_SCENE := "res://scene/world/island.tscn"
const TITLE_SCENE := "res://scene/ui/title_screen.tscn"
## Objets de départ d'une nouvelle partie (l'épée en bois est aussi équipée).
const STARTING_ITEMS: Dictionary[StringName, int] = {&"wooden_sword_item": 1}
const BASE_PLAYER_STATS: PlayerStats = preload("res://resources/stats/player_base_stats.tres")
## Toutes les armes (.tres) de ce dossier sont chargées au démarrage.
const WEAPONS_DIR := "res://resources/weapons/"
## Arme de départ (comme dans Zelda, on commence avec une arme modeste).
const DEFAULT_WEAPON_ID := &"wooden_sword"
## Tous les objets (.tres) de ce dossier sont chargés au démarrage.
const ITEMS_DIR := "res://resources/items/"

## Raccourcis de test (builds de debug uniquement).
const DEBUG_XP_AMOUNT := 50
const DEBUG_WEAPON_ACTIONS: Dictionary[StringName, StringName] = {
	&"debug_weapon_1": &"wooden_sword",
	&"debug_weapon_2": &"knight_sword",
	&"debug_weapon_3": &"fire_blade",
}

## Fichier de sauvegarde utilisé (les tests le remplacent pour ne pas toucher la vraie).
var save_path: String = SAVE_PATH
## Données sérialisables de la partie, rangées par section ("player", "world"…).
var data: Dictionary = {}
## Vrai après un chargement suivi d'un changement de scène : le prochain joueur créé
## reprend la position, la vie et le mana sauvegardés (point de sauvegarde).
var restore_player_on_spawn: bool = false
## Stats courantes du joueur (copie de BASE_PLAYER_STATS qui évolue).
var player_stats: PlayerStats
## Catalogue des armes, par identifiant.
var weapons: Dictionary[StringName, WeaponData] = {}
var equipped_weapon: WeaponData
## Catalogue des objets, par identifiant.
var items: Dictionary[StringName, ItemData] = {}
## Inventaire : identifiant d'objet → quantité.
var inventory: Dictionary[StringName, int] = {}
var rupees: int = 0
## Drapeaux du monde : coffres ouverts, portes déverrouillées… (« chest:<id> », « door:<id> »).
var world_flags: Dictionary[StringName, bool] = {}
## « Moyen » par défaut : le jeu doit tourner sur tous les PC.
var graphics_quality: int = Quality.MOYEN


func _ready() -> void:
	# La fermeture de la fenêtre passe par quit_game() (voir _notification).
	get_tree().auto_accept_quit = false
	_load_settings()
	_apply_viewport_quality()
	weapons.assign(_load_catalog(WEAPONS_DIR))
	items.assign(_load_catalog(ITEMS_DIR))
	new_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Quitte le jeu proprement : les sons en cours sont coupés et le serveur audio a le
## temps de les libérer (sinon Godot signale des fuites à la fermeture).
func quit_game() -> void:
	get_tree().paused = true
	Sfx.stop_all(get_tree())
	await get_tree().create_timer(0.25, true, false, true).timeout
	get_tree().quit()


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
	else:
		for action in DEBUG_WEAPON_ACTIONS:
			if event.is_action_pressed(action) and equip_weapon_by_id(DEBUG_WEAPON_ACTIONS[action]):
				print("[debug] arme équipée : ", equipped_weapon.display_name)


func new_game() -> void:
	data = {}
	player_stats = BASE_PLAYER_STATS.duplicate() as PlayerStats
	inventory = {}
	inventory.assign(STARTING_ITEMS)
	rupees = 0
	world_flags = {}
	restore_player_on_spawn = false
	stats_changed.emit()
	inventory_changed.emit()
	equip_weapon_by_id(DEFAULT_WEAPON_ID)


## Donne de l'XP au joueur ; émet EventBus.level_up pour chaque niveau gagné.
func add_xp(amount: int) -> void:
	var previous_level := player_stats.level
	player_stats.add_xp(amount)
	for new_level in range(previous_level + 1, player_stats.level + 1):
		EventBus.level_up.emit(new_level)
	stats_changed.emit()


# --- Équipement ----------------------------------------------------------------

func equip_weapon(weapon: WeaponData) -> void:
	equipped_weapon = weapon
	equipment_changed.emit(weapon)


func equip_weapon_by_id(weapon_id: StringName) -> bool:
	if not weapons.has(weapon_id):
		push_error("Arme inconnue : %s" % weapon_id)
		return false
	equip_weapon(weapons[weapon_id])
	return true


## Charge toutes les ressources .tres d'un dossier, indexées par leur `id`.
## list_directory() fonctionne aussi dans le jeu exporté (noms de fichiers d'origine).
func _load_catalog(directory: String) -> Dictionary:
	var catalog := {}
	for file_name in ResourceLoader.list_directory(directory):
		if not file_name.ends_with(".tres"):
			continue
		var resource := load(directory + file_name)
		if resource and &"id" in resource:
			catalog[resource.get(&"id")] = resource
	return catalog


# --- Inventaire ------------------------------------------------------------------

## Ajoute un objet ramassé : les rubis vont au compteur, le reste dans l'inventaire
## (plafonné à max_quantity). Émet EventBus.item_picked_up.
func add_item(item: ItemData, quantity: int = 1) -> void:
	if quantity <= 0:
		return
	if item.type == ItemData.ItemType.MONNAIE:
		rupees += item.value * quantity
	else:
		var limit := item.max_quantity if item.stackable else 1
		inventory[item.id] = mini(get_item_count(item.id) + quantity, limit)
	inventory_changed.emit()
	EventBus.item_picked_up.emit(item, quantity)


func get_item_count(item_id: StringName) -> int:
	return inventory.get(item_id, 0)


## Retire `quantity` exemplaires (clé utilisée, potion bue…). Renvoie false s'il en manque.
func remove_item(item_id: StringName, quantity: int = 1) -> bool:
	if get_item_count(item_id) < quantity:
		return false
	inventory[item_id] -= quantity
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	inventory_changed.emit()
	return true


# --- Drapeaux du monde ------------------------------------------------------------

func set_flag(flag: StringName, value: bool = true) -> void:
	world_flags[flag] = value


func has_flag(flag: StringName) -> bool:
	return world_flags.get(flag, false)


# --- Réglages graphiques ---------------------------------------------------------

## Change la qualité graphique. Les niveaux (WorldVisuals, herbe, contours) écoutent
## `graphics_quality_changed` ; l'anticrénelage et la résolution sont réglés ici.
func set_graphics_quality(quality: int, persist: bool = true) -> void:
	graphics_quality = clampi(quality, Quality.BAS, Quality.HAUT)
	_apply_viewport_quality()
	if persist:
		var config := ConfigFile.new()
		config.set_value("graphismes", "qualite", graphics_quality)
		config.save(SETTINGS_PATH)
	graphics_quality_changed.emit(graphics_quality)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		graphics_quality = clampi(int(config.get_value("graphismes", "qualite", Quality.MOYEN)), Quality.BAS, Quality.HAUT)


func _apply_viewport_quality() -> void:
	var viewport := get_tree().root
	match graphics_quality:
		Quality.BAS:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			viewport.scaling_3d_scale = 0.8
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		Quality.MOYEN:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			viewport.scaling_3d_scale = 1.0
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		_:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			viewport.scaling_3d_scale = 1.0
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)


# --- Navigation entre les écrans ----------------------------------------------

## Écran titre → « Nouvelle partie ».
func start_new_game() -> void:
	new_game()
	change_scene(LEVEL_SCENE)


## « Continuer » / « Charger » / « Réapparaître » : reprend au dernier point de sauvegarde,
## ou recommence une partie s'il n'y a pas de sauvegarde.
func continue_game() -> void:
	if prepare_respawn():
		change_scene(LEVEL_SCENE)
	else:
		start_new_game()


## Charge la sauvegarde et demande au prochain joueur créé de reprendre sa position.
func prepare_respawn() -> bool:
	if not load_game():
		return false
	restore_player_on_spawn = true
	return true


## Données du joueur à restaurer (une seule fois), ou {} s'il n'y a rien à restaurer.
func consume_player_restore() -> Dictionary:
	if not restore_player_on_spawn:
		return {}
	restore_player_on_spawn = false
	return data.get("player", {})


func go_to_title() -> void:
	change_scene(TITLE_SCENE)


func change_scene(path: String) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file.call_deferred(path)


# --- Sauvegarde ----------------------------------------------------------------

func has_save(path: String = "") -> bool:
	return FileAccess.file_exists(path if not path.is_empty() else save_path)


func save_game(path: String = "") -> bool:
	if path.is_empty():
		path = save_path
	saving.emit()
	data["player_stats"] = player_stats.to_dict()
	data["equipment"] = {"weapon": String(equipped_weapon.id)}
	data["inventory"] = inventory.duplicate()
	data["rupees"] = rupees
	data["world_flags"] = world_flags.duplicate()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Sauvegarde impossible (%s) : %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func load_game(path: String = "") -> bool:
	if path.is_empty():
		path = save_path
	if not has_save(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Sauvegarde corrompue : %s" % path)
		return false
	data = parsed
	player_stats = BASE_PLAYER_STATS.duplicate() as PlayerStats
	player_stats.from_dict(data.get("player_stats", {}))
	var equipment: Dictionary = data.get("equipment", {})
	if not equip_weapon_by_id(StringName(equipment.get("weapon", DEFAULT_WEAPON_ID))):
		equip_weapon_by_id(DEFAULT_WEAPON_ID)
	inventory = {}
	var saved_inventory: Dictionary = data.get("inventory", {})
	for item_id in saved_inventory:
		if items.has(StringName(item_id)):
			inventory[StringName(item_id)] = int(saved_inventory[item_id])
	rupees = int(data.get("rupees", 0))
	world_flags = {}
	var saved_flags: Dictionary = data.get("world_flags", {})
	for flag in saved_flags:
		world_flags[StringName(flag)] = bool(saved_flags[flag])
	stats_changed.emit()
	inventory_changed.emit()
	loaded.emit()
	return true
