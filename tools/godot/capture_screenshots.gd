extends "res://tests/test_case.gd"
## Prend toujours les mêmes captures d'écran (même cadrage) : README et comparaisons
## avant / après. Lancer avec rendu (pas en headless) :
##   godot --path . --resolution 1280x720 res://tools/godot/capture_screenshots.tscn -- docs/screenshots/ prefixe_
## Produit : <dossier><préfixe>village.png, combat.png, donjon.png, inventaire.png, titre.png

var _folder: String = "docs/screenshots/"
var _prefix: String = ""


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_folder = args[0]
	if args.size() >= 2:
		_prefix = args[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _folder))
	GameState.save_path = "user://capture_save.json"
	GameState.new_game()
	for pair in [[&"potion", 2], [&"knight_sword_item", 1], [&"fire_blade_item", 1], [&"slime_jelly", 3], [&"small_key", 1], [&"goblin_fang", 2]]:
		GameState.add_item(GameState.items[pair[0]], pair[1])
	GameState.add_item(GameState.items[&"rupee"], 42)

	var level: Node = load("res://scene/world/island.tscn").instantiate()
	add_child(level)
	var player := level.get_node("Player") as Player
	var enemies := level.get_node("Enemies")
	await frames(30)

	# 1. Village, vu depuis la plage d'arrivée.
	await _place(player, Vector3(0, 0.1, 30), 0.0, -0.28)
	await _shot("village")

	# 2. Combat : un Gobelin prépare son attaque, cible verrouillée, coup d'épée.
	var goblin := enemies.get_node("GoblinNorth") as Enemy
	await _place(player, Vector3(6, 0.1, -24), 0.0, -0.3)
	teleport(goblin, Vector3(6, 0, -27))
	goblin.model.rotation.y = PI
	await frames(10)
	player.lock_on.toggle()
	goblin.state_machine.transition_to(&"Attack")
	await frames(8)
	player.stamina.set_max_stamina(player.stamina.max_stamina, true)
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	await frames(9)
	await _shot("combat")
	player.lock_on.release()
	goblin.queue_free()

	# 3. Le donjon et sa porte.
	await _place(player, Vector3(22, 0.1, -12), 0.0, -0.18)
	await _shot("donjon")

	# 4. Inventaire (onglet Équipement).
	await _place(player, Vector3(0, 0.1, 20), 0.0, -0.3)
	var ui := level.get_node("GameUI") as GameUI
	ui.inventory.open()
	ui.inventory.tabs.current_tab = 1
	await frames(5)
	await _shot("inventaire")
	ui.inventory.close()
	level.queue_free()
	await frames(3)

	# 5. Écran titre.
	var title: Node = load("res://scene/ui/title_screen.tscn").instantiate()
	add_child(title)
	await frames(40)
	await _shot("titre")
	title.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_save.json"))
	GameState.save_path = GameState.SAVE_PATH


func _place(player: Player, position: Vector3, yaw: float, pitch: float) -> void:
	teleport(player, position)
	player.model.rotation.y = yaw
	player.camera_pivot.snap_to(yaw, pitch)
	for i in 60:
		await get_tree().physics_frame
		if player.state_machine.get_state_name() == &"Idle":
			break
	await frames(15)


func _shot(shot_name: String) -> void:
	await get_tree().process_frame
	var path := "res://%s%s%s.png" % [_folder, _prefix, shot_name]
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("  capture : ", path)
