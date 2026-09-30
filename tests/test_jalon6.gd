extends "res://tests/test_case.gd"
## Test automatique du jalon 6 : île (village, forêt, pont, donjon), collisions, navigation
## précuite, éclairage, système d'interaction, coffres, porte à clé, objets aspirés,
## textes « +1 … », sauvegarde des coffres et portes. Utilisation : voir tests/test_case.gd.

const TEST_SAVE_PATH := "user://test_save_j6.json"

var _level: Node
var _player: Player
var _prompt: InteractionPrompt
var _texts_seen: Array[String] = []


func run() -> void:
	GameState.new_game()
	_level = load("res://scene/world/island.tscn").instantiate()
	var enemies := _level.get_node("Enemies")
	_level.remove_child(enemies)
	enemies.free()
	add_child(_level)
	child_entered_tree.connect(func(node: Node) -> void:
		if node is FloatingText: _texts_seen.append((node as FloatingText).text))
	_player = _level.get_node("Player") as Player
	_prompt = _level.get_node("InteractionPrompt") as InteractionPrompt
	var nav := _level.get_node("NavigationRegion3D") as NavigationRegion3D
	await frames(20)

	print("== L'île")
	check(nav.navigation_mesh.resource_path == "res://resources/navigation/island_navmesh.tres" and nav.navigation_mesh.get_polygon_count() > 100,
		"navigation précuite (%d polygones)" % nav.navigation_mesh.get_polygon_count())
	var environment := (_level.get_node("WorldEnvironment") as WorldEnvironment).environment
	check(environment.background_mode == Environment.BG_SKY and environment.fog_enabled and environment.ssao_enabled, "ciel, brouillard léger et SSAO")
	check(_count(nav.get_node("Village"), "House") == 3, "village de 3 maisons")
	check(_count(nav.get_node("Forest"), "Tree") >= 15, "forêt (%d arbres)" % _count(nav.get_node("Forest"), "Tree"))
	check(nav.has_node("Village/Bridge") and nav.has_node("Dungeon/Ruins") and nav.has_node("DungeonDoor"), "pont, donjon et sa porte")
	var without_collision: Array[String] = []
	for group in ["Village", "Forest", "North", "Dungeon", "Coast"]:
		for prop in nav.get_node(group).get_children():
			if prop is OmniLight3D or String(prop.name).begins_with("Grass"):
				continue
			if prop.find_children("*", "StaticBody3D", true, false).is_empty():
				without_collision.append(String(prop.name))
	check(without_collision.is_empty(), "collisions sur tout le décor %s" % [without_collision])

	print("== Rivière et pont")
	var map := _player.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, Vector3(-20, 0, 6), Vector3(-20, 0, -12), true)
	var via_bridge := false
	for point in path:
		via_bridge = via_bridge or (absf(point.x) < 1.5 and point.z < 1.5 and point.z > -5.5)
	check(path.size() > 2 and via_bridge, "le chemin de la forêt vers le nord passe par le pont")
	teleport(_player, Vector3(10, 0.1, 3))
	_player.camera_pivot.snap_to(0.0, -0.3)
	Input.action_press("move_forward")
	await frames(90)
	Input.action_release("move_forward")
	check(_player.global_position.z > 0.0, "impossible de traverser la rivière hors du pont (z = %.1f)" % _player.global_position.z)

	print("== Coffre du village")
	var chest := nav.get_node("ChestVillage") as Chest
	await _face(chest, 1.6)
	check(_player.interaction.current == chest.interactable, "le coffre est détecté devant le joueur")
	check(_prompt.get_text() == "Ouvrir  [E]", "message à l'écran : « %s »" % _prompt.get_text())
	await _press(&"interact")
	check(chest.is_open and GameState.has_flag(&"chest:village"), "E ouvre le coffre (état enregistré)")
	check(chest.anim.current_animation == "open", "animation « open »")
	# Capture : caméra décalée sur le côté pour voir le coffre s'ouvrir et le butin jaillir.
	if not OS.get_cmdline_user_args().is_empty():
		_player.camera_pivot.snap_to(_player.model.rotation.y + 0.75, -0.35)
		await frames(22)
		await save_screenshot_if_requested()
	await frames(10)
	check(_prompt.get_text() == "", "plus de message sur un coffre ouvert")
	await frames(90)
	check(GameState.get_item_count(&"potion") == 1, "potion ramassée")
	check(GameState.rupees >= 5 and GameState.rupees <= 10, "%d rubis ramassés" % GameState.rupees)
	check(_texts_seen.has("+1 Potion"), "texte « +1 Potion » (%s)" % [_texts_seen])

	print("== Aspiration des objets")
	var pickup := preload("res://scene/items/pickup.tscn").instantiate() as Pickup
	pickup.item = GameState.items[&"rupee"]
	_level.add_child(pickup)
	pickup.global_position = _player.global_position + Vector3(2.0, 0, 0)
	await frames(30)
	var attracted := pickup.is_being_attracted() or not is_instance_valid(pickup)
	await frames(60)
	check(attracted and not is_instance_valid(pickup), "un objet à 2 m est aspiré puis ramassé")

	print("== Porte verrouillée du donjon")
	var door := nav.get_node("DungeonDoor") as Door
	await _face(door, 1.8)
	check(_prompt.get_text() == "Verrouillée  [E]", "message : « %s »" % _prompt.get_text())
	await _press(&"interact")
	check(not door.is_open and _texts_seen.has("Il faut une petite clé !"), "sans clé : « Il faut une petite clé ! »")

	print("== La clé")
	var key_chest := nav.get_node("ChestKey") as Chest
	await _face(key_chest, 1.6)
	await _press(&"interact")
	await frames(100)
	check(GameState.get_item_count(&"small_key") == 1, "petite clé trouvée dans le coffre gardé")
	await _face(door, 1.8)
	check(_prompt.get_text() == "Déverrouiller  [E]", "message : « %s »" % _prompt.get_text())
	var panel := door.find_child("DoorPanelCollision", true, false) as Node3D
	var local_center := Vector3(0.625, 1.125, 0)
	var center_before := panel.global_transform * local_center
	await _press(&"interact")
	check(door.is_open and GameState.get_item_count(&"small_key") == 0, "porte déverrouillée, clé consommée")
	await frames(60)
	check((panel.global_transform * local_center).distance_to(center_before) > 0.3, "le battant (et sa collision) s'ouvre")

	print("== Sauvegarde des coffres et portes")
	check(GameState.save_game(TEST_SAVE_PATH), "écriture")
	GameState.new_game()
	check(not GameState.has_flag(&"chest:village") and not GameState.has_flag(&"door:dungeon"), "nouvelle partie : drapeaux effacés")
	check(GameState.load_game(TEST_SAVE_PATH), "lecture")
	check(GameState.has_flag(&"chest:village") and GameState.has_flag(&"chest:key") and GameState.has_flag(&"door:dungeon"), "coffres et porte restaurés")
	check(chest.is_open and not chest.interactable.available and door.is_open, "le monde reflète l'état chargé")
	var forest_chest := nav.get_node("ChestForest") as Chest
	check(not forest_chest.is_open and forest_chest.interactable.available, "un coffre jamais ouvert reste fermé")
	delete_user_file(TEST_SAVE_PATH)


func _count(parent: Node, prefix: String) -> int:
	var total := 0
	for child in parent.get_children():
		if String(child.name).begins_with(prefix):
			total += 1
	return total


## Place le joueur à `distance` devant l'objet (dont l'avant est -Z local), tourné vers lui.
func _face(target: Node3D, distance: float) -> void:
	var front := -target.global_basis.z.normalized()
	teleport(_player, target.global_position + front * distance + Vector3.UP * 0.1)
	_player.face_direction_instant(-front)
	_player.camera_pivot.snap_to(_player.model.rotation.y, -0.3)
	# L'interaction n'est possible qu'au sol : on attend l'atterrissage (état Idle).
	for i in 60:
		await get_tree().physics_frame
		if _player.state_machine.get_state_name() == &"Idle":
			break
	await frames(3)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(1)
