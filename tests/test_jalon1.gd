extends "res://tests/test_case.gd"
## Test automatique du jalon 1 : déplacements, états, lock-on, dégâts, sauvegarde.
## Utilisation : voir tests/test_case.gd.

const TEST_SAVE_PATH := "user://test_save_j1.json"

var _player_died_received: bool = false


func run() -> void:
	var main := load_main()
	var player := main.get_node("Player") as Player
	var machine := player.state_machine
	EventBus.player_died.connect(func() -> void: _player_died_received = true)

	print("== Gravité et état initial")
	await frames(30)
	check(player.is_on_floor(), "le joueur tombe puis tient au sol")
	check(machine.get_state_name() == &"Idle", "état initial Idle")

	print("== Déplacement relatif à la caméra")
	player.camera_pivot.snap_to(PI / 2.0, -0.35)  # caméra tournée vers -X
	var start := player.global_position
	Input.action_press("move_forward")
	await frames(30)
	check(machine.get_state_name() == &"Walk", "état Walk")
	var moved := player.global_position - start
	check(moved.x < -1.0 and absf(moved.z) < 0.2, "avance dans l'axe de la caméra %s" % moved)
	check(absf(angle_difference(player.model.rotation.y, PI / 2.0)) < 0.2, "le modèle s'est tourné vers la direction")

	print("== Sprint")
	Input.action_press("sprint")
	await frames(30)
	check(machine.get_state_name() == &"Run", "état Run avec Maj")
	check(player.stamina.stamina < player.stamina.max_stamina, "le sprint consomme l'endurance")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await frames(40)
	check(machine.get_state_name() == &"Idle", "retour à Idle (décélération)")

	print("== Saut")
	var ground_y := player.global_position.y
	Input.action_press("jump")
	await frames(2)
	check(machine.get_state_name() == &"Jump", "état Jump")
	var peak := ground_y
	var saw_fall := false
	for i in 90:
		await get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)
		saw_fall = saw_fall or machine.get_state_name() == &"Fall"
		if i == 30:
			Input.action_release("jump")
	check(peak - ground_y > 1.5, "hauteur du saut %.2f m" % (peak - ground_y))
	check(saw_fall and player.is_on_floor(), "Jump → Fall → atterrissage")

	print("== Coyote time")
	teleport(player, player.global_position + Vector3.UP * 5.0)
	await frames(3)
	check(player.can_jump(), "saut encore possible juste après avoir quitté le sol")
	await frames(15)
	check(not player.can_jump(), "plus possible après le délai de coyote")

	print("== Buffer de saut")
	while player.global_position.y > ground_y + 0.6:
		await get_tree().physics_frame
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	var buffered := false
	for i in 12:
		await get_tree().physics_frame
		buffered = buffered or machine.get_state_name() == &"Jump"
	check(buffered, "l'appui juste avant l'atterrissage déclenche le saut")
	while not player.is_on_floor() or machine.get_state_name() != &"Idle":
		await get_tree().physics_frame

	print("== Roulade")
	player.stamina.set_max_stamina(player.stamina.max_stamina, true)
	start = player.global_position
	var forward := player.get_forward()
	Input.action_press("dodge")
	await frames(2)
	Input.action_release("dodge")
	check(machine.get_state_name() == &"Dodge", "état Dodge")
	check(player.health.is_invincible(), "invincible pendant la roulade")
	check(is_equal_approx(player.stamina.stamina, player.stamina.max_stamina - player.dodge_stamina_cost), "coût d'endurance payé")
	await frames(35)
	check(machine.get_state_name() != &"Dodge", "la roulade se termine")
	check((player.global_position - start).dot(forward) < -2.0, "sans direction : bond en arrière")

	print("== Lock-on")
	teleport(player, Vector3(0, 0.1, 0))
	player.model.rotation.y = 0.0
	player.camera_pivot.snap_to(0.0, -0.35)
	await frames(10)
	await send_action("lock_on")
	check(player.lock_on.target != null and player.lock_on.target.name == "Dummy1", "Tab verrouille la cible la plus proche")
	var first := player.lock_on.target
	await send_action("target_next")
	check(player.lock_on.target != null and player.lock_on.target != first, "la molette change de cible (%s)" % player.lock_on.target.name)
	await frames(60)
	var to_target := player.lock_on.get_target_point() - player.global_position
	var wanted_yaw := atan2(-to_target.x, -to_target.z)
	check(absf(angle_difference(player.camera_pivot.get_yaw(), wanted_yaw)) < 0.1, "la caméra suit la cible")
	check(absf(angle_difference(player.model.rotation.y, wanted_yaw)) < 0.15, "le joueur fait face à la cible (strafe)")
	await save_screenshot_if_requested()
	await send_action("lock_on")
	check(player.lock_on.target == null, "Tab relâche la cible")
	await send_action("lock_on")
	teleport(player, Vector3(0, 0.1, 25))
	await frames(3)
	check(player.lock_on.target == null, "relâché quand la cible est trop loin")

	print("== Dégâts, Hurt et Dead")
	var dummy := main.get_node("Dummies/Dummy1") as Node3D
	check(player.health.take_damage(5, dummy), "dégâts appliqués")
	await get_tree().physics_frame
	check(machine.get_state_name() == &"Hurt", "état Hurt")
	check(not player.health.take_damage(5, dummy), "invincibilité après un coup")
	await frames(45)
	player.health.take_damage(999, dummy)
	await get_tree().physics_frame
	check(machine.get_state_name() == &"Dead", "état Dead")
	check(_player_died_received, "signal EventBus.player_died émis")

	print("== Sauvegarde JSON (GameState)")
	GameState.data = {"test": 42}
	check(GameState.save_game(TEST_SAVE_PATH), "écriture")
	GameState.data = {}
	check(GameState.load_game(TEST_SAVE_PATH) and int(GameState.data.get("test", 0)) == 42, "relecture")
	delete_user_file(TEST_SAVE_PATH)
