extends Node
## Test automatique du jalon 1 (déplacements, états, lock-on, dégâts, sauvegarde).
##   Logique seule :      godot --headless --path . res://tests/test_jalon1.tscn
##   Avec capture PNG :   godot --path . res://tests/test_jalon1.tscn -- chemin/capture.png
## Code de sortie 0 = tout est OK.

const TEST_SAVE_PATH := "user://test_save.json"

var _failures: int = 0
var _player_died_received: bool = false


func _ready() -> void:
	# Garde-fou : un test bloqué échoue au bout de 90 s au lieu de tourner sans fin.
	get_tree().create_timer(90.0).timeout.connect(func() -> void:
		print("[ÉCHEC]  délai dépassé")
		get_tree().quit(2))
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scene/world/main.tscn").instantiate()
	add_child(main)
	var player := main.get_node("Player") as Player
	var machine := player.state_machine
	EventBus.player_died.connect(func() -> void: _player_died_received = true)

	print("== Gravité et état initial")
	await _frames(30)
	_check(player.is_on_floor(), "le joueur tombe puis tient au sol")
	_check(machine.get_state_name() == &"Idle", "état initial Idle")

	print("== Déplacement relatif à la caméra")
	player.camera_pivot.snap_to(PI / 2.0, -0.35)  # caméra tournée vers -X
	var start := player.global_position
	Input.action_press("move_forward")
	await _frames(30)
	_check(machine.get_state_name() == &"Walk", "état Walk")
	var moved := player.global_position - start
	_check(moved.x < -1.0 and absf(moved.z) < 0.2, "avance dans l'axe de la caméra %s" % moved)
	_check(absf(angle_difference(player.model.rotation.y, PI / 2.0)) < 0.2, "le modèle s'est tourné vers la direction")

	print("== Sprint")
	Input.action_press("sprint")
	await _frames(30)
	_check(machine.get_state_name() == &"Run", "état Run avec Maj")
	_check(player.stamina.stamina < player.stamina.max_stamina, "le sprint consomme l'endurance")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _frames(40)
	_check(machine.get_state_name() == &"Idle", "retour à Idle (décélération)")

	print("== Saut")
	var ground_y := player.global_position.y
	Input.action_press("jump")
	await _frames(2)
	_check(machine.get_state_name() == &"Jump", "état Jump")
	var peak := ground_y
	var saw_fall := false
	for i in 90:
		await get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)
		saw_fall = saw_fall or machine.get_state_name() == &"Fall"
		if i == 30:
			Input.action_release("jump")
	_check(peak - ground_y > 1.5, "hauteur du saut %.2f m" % (peak - ground_y))
	_check(saw_fall and player.is_on_floor(), "Jump → Fall → atterrissage")

	print("== Coyote time")
	_teleport(player, player.global_position + Vector3.UP * 5.0)
	await _frames(3)
	_check(player.can_jump(), "saut encore possible juste après avoir quitté le sol")
	await _frames(15)
	_check(not player.can_jump(), "plus possible après le délai de coyote")

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
	_check(buffered, "l'appui juste avant l'atterrissage déclenche le saut")
	while not player.is_on_floor() or machine.get_state_name() != &"Idle":
		await get_tree().physics_frame

	print("== Roulade")
	player.stamina._set_stamina(player.stamina.max_stamina)
	start = player.global_position
	var forward := player.get_forward()
	Input.action_press("dodge")
	await _frames(2)
	Input.action_release("dodge")
	_check(machine.get_state_name() == &"Dodge", "état Dodge")
	_check(player.health.is_invincible(), "invincible pendant la roulade")
	_check(is_equal_approx(player.stamina.stamina, player.stamina.max_stamina - player.dodge_stamina_cost), "coût d'endurance payé")
	await _frames(35)
	_check(machine.get_state_name() != &"Dodge", "la roulade se termine")
	_check((player.global_position - start).dot(forward) < -2.0, "sans direction : bond en arrière")

	print("== Lock-on")
	_teleport(player, Vector3(0, 0.1, 0))
	player.model.rotation.y = 0.0
	player.camera_pivot.snap_to(0.0, -0.35)
	await _frames(10)
	await _send_action("lock_on")
	_check(player.lock_on.target != null and player.lock_on.target.name == "Dummy1", "Tab verrouille la cible la plus proche")
	var first := player.lock_on.target
	await _send_action("target_next")
	_check(player.lock_on.target != null and player.lock_on.target != first, "la molette change de cible (%s)" % player.lock_on.target.name)
	await _frames(60)
	var to_target := player.lock_on.get_target_point() - player.global_position
	var wanted_yaw := atan2(-to_target.x, -to_target.z)
	_check(absf(angle_difference(player.camera_pivot.get_yaw(), wanted_yaw)) < 0.1, "la caméra suit la cible")
	_check(absf(angle_difference(player.model.rotation.y, wanted_yaw)) < 0.15, "le joueur fait face à la cible (strafe)")
	var screenshot_path := _screenshot_path()
	if screenshot_path != "":
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(screenshot_path)
		print("  capture : ", screenshot_path)
	await _send_action("lock_on")
	_check(player.lock_on.target == null, "Tab relâche la cible")
	await _send_action("lock_on")
	_teleport(player, Vector3(0, 0.1, 25))
	await _frames(3)
	_check(player.lock_on.target == null, "relâché quand la cible est trop loin")

	print("== Dégâts, Hurt et Dead")
	var dummy := main.get_node("Dummies/Dummy1") as Node3D
	_check(player.health.take_damage(5, dummy), "dégâts appliqués")
	await get_tree().physics_frame
	_check(machine.get_state_name() == &"Hurt", "état Hurt")
	_check(not player.health.take_damage(5, dummy), "invincibilité après un coup")
	await _frames(45)
	player.health.take_damage(999, dummy)
	await get_tree().physics_frame
	_check(machine.get_state_name() == &"Dead", "état Dead")
	_check(_player_died_received, "signal EventBus.player_died émis")

	print("== Sauvegarde JSON (GameState)")
	GameState.data = {"test": 42}
	_check(GameState.save_game(TEST_SAVE_PATH), "écriture")
	GameState.data = {}
	_check(GameState.load_game(TEST_SAVE_PATH) and int(GameState.data.get("test", 0)) == 42, "relecture")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

	print("\n%s : %d échec(s)" % ["SUCCÈS" if _failures == 0 else "ÉCHEC", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	print(("  [OK]     " if condition else "  [ÉCHEC]  ") + label)
	if not condition:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _teleport(player: Player, position: Vector3) -> void:
	player.global_position = position
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


## Simule un appui + relâchement d'action (passe par _unhandled_input).
func _send_action(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


func _screenshot_path() -> String:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		return ""
	return args[0]
