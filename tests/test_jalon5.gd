extends "res://tests/test_case.gd"
## Test automatique du jalon 5 : modèles Blender importés (squelettes, animations,
## boucles), arme attachée à la main, AnimationTree du joueur, animations des ennemis,
## collisions des décors (suffixes -colonly / -convcolonly), navigation autour des décors,
## animations « open ». Utilisation : voir tests/test_case.gd.

const PLAYER_ANIMATIONS: Array[StringName] = [&"idle", &"walk", &"run", &"jump", &"fall", &"roll",
	&"attack_1", &"attack_2", &"attack_3", &"cast", &"hurt", &"death"]
const ENEMY_ANIMATIONS: Array[StringName] = [&"idle", &"walk", &"attack", &"hurt", &"death"]

var _player: Player


func run() -> void:
	GameState.new_game()
	var main := load_main(true)
	_player = main.get_node("Player") as Player
	var goblin := main.get_node("Enemies/Goblin1") as Enemy
	var slime := main.get_node("Enemies/Slime1") as Enemy
	for other in ["Enemies/Goblin2", "Enemies/Slime2"]:
		main.get_node(other).queue_free()
	await frames(20)

	print("== Modèle du joueur")
	var skeleton := _player.body_model.find_child("Skeleton3D") as Skeleton3D
	check(skeleton != null and skeleton.get_bone_count() == 15, "squelette de 15 os")
	var model_player := _player.body_model.find_child("AnimationPlayer") as AnimationPlayer
	var names: Array[StringName] = []
	for animation_name in model_player.get_animation_list():
		names.append(StringName(animation_name))
	check(PLAYER_ANIMATIONS.all(func(a: StringName) -> bool: return names.has(a)), "les 12 animations aux noms exacts")
	for looping: StringName in [&"idle", &"walk", &"run", &"fall"]:
		check(model_player.get_animation(looping).loop_mode == Animation.LOOP_LINEAR, "%s en boucle (réglage d'import)" % looping)
	check(model_player.get_animation(&"attack_1").loop_mode == Animation.LOOP_NONE, "les attaques ne bouclent pas")

	print("== Arme dans la main (BoneAttachment3D)")
	var attachment := _player.weapon_socket.get_parent() as BoneAttachment3D
	check(attachment != null and attachment.bone_name == "hand.R", "WeaponSocket suit l'os hand.R")
	check(_player.weapon_socket.get_child_count() == 1 and _player.weapon_socket.get_child(0).name == &"WoodenSword", "l'épée en bois (modèle Blender) est en main")
	GameState.equip_weapon_by_id(&"fire_blade")
	check(_player.weapon_socket.get_child(0).name == &"FireBlade", "changement d'arme → Lame de feu en main")
	GameState.equip_weapon_by_id(&"wooden_sword")

	print("== AnimationTree : locomotion")
	check(_player.anim_tree.active, "AnimationTree actif")
	check(_player.body_playback.get_current_node() == &"locomotion", "état initial : locomotion")
	_player.camera_pivot.snap_to(0.0, -0.35)
	teleport(_player, Vector3(0, 0.1, 0))
	Input.action_press("move_forward")
	await frames(30)
	var blend: float = _player.anim_tree.get(&"parameters/locomotion/blend_position")
	check(blend > 4.0 and blend < 6.0, "marche : mélange idle/walk/run à %.1f (≈ walk)" % blend)
	Input.action_press("sprint")
	await frames(30)
	blend = _player.anim_tree.get(&"parameters/locomotion/blend_position")
	check(blend > 8.0, "sprint : mélange à %.1f (≈ run)" % blend)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await frames(40)

	print("== AnimationTree : actions")
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	check(_player.body_playback.get_current_node() == &"jump", "saut → jump")
	await _wait_state(&"Fall", 60)
	check(_player.body_playback.get_current_node() == &"fall", "chute → fall")
	await _wait_state(&"Idle", 120)
	Input.action_press("dodge")
	await frames(2)
	Input.action_release("dodge")
	check(_player.body_playback.get_current_node() == &"roll_back", "roulade sans direction → roll_back (roll à l'envers)")
	await _wait_state(&"Idle", 60)
	Input.action_press("move_forward")
	await frames(2)
	Input.action_press("dodge")
	await frames(2)
	Input.action_release("dodge")
	Input.action_release("move_forward")
	check(_player.body_playback.get_current_node() == &"roll", "roulade vers l'avant → roll")
	await _wait_state(&"Idle", 90)

	print("== Attaque : corps et gameplay synchronisés")
	_player.stamina.set_max_stamina(_player.stamina.max_stamina, true)
	var socket_before := _player.weapon_socket.global_position
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	check(_player.body_playback.get_current_node() == &"attack_1" and _player.anim.current_animation == "attack_1", "attack_1 sur le corps ET sur le gameplay")
	var time_scale: float = _player.anim_tree.get(&"parameters/attack_1/time_scale/scale")
	check(is_equal_approx(time_scale, GameState.equipped_weapon.attack_speed), "vitesse d'animation = vitesse de l'arme (%.2f)" % time_scale)
	await frames(10)
	check(_player.weapon_socket.global_position.distance_to(socket_before) > 0.2, "l'épée suit la main pendant le coup")
	await save_screenshot_if_requested()
	await _wait_state(&"Idle", 90)
	var hurt := DamageInfo.new()
	hurt.raw_amount = 3.0
	hurt.source = goblin
	_player.hurtbox.receive_hit(hurt)
	await frames(2)
	check(_player.body_playback.get_current_node() == &"hurt", "coup reçu → hurt")

	print("== Ennemis animés")
	var goblin_model := goblin.model_anim
	check(goblin_model != null and ENEMY_ANIMATIONS.all(func(a: StringName) -> bool: return goblin_model.has_animation(a)), "Gobelin : idle, walk, attack, hurt, death")
	check(slime.model_anim != null and ENEMY_ANIMATIONS.all(func(a: StringName) -> bool: return slime.model_anim.has_animation(a)), "Slime : idle, walk, attack, hurt, death")
	check(goblin_model.current_animation in ["walk", "idle"], "le Gobelin qui patrouille joue %s" % goblin_model.current_animation)
	goblin.state_machine.transition_to(&"Attack")
	await frames(2)
	check(goblin_model.current_animation == "attack" and goblin.anim.current_animation == "attack", "attaque : modèle et gameplay ensemble")
	var club_attachment := goblin.find_child("Skeleton3D", true, false) as Skeleton3D
	check(club_attachment != null, "squelette du Gobelin")

	print("== Décors : collisions importées et navigation")
	var props := main.get_node("NavigationRegion3D/Props")
	var house_bodies := props.get_node("House").find_children("*", "StaticBody3D", true, false)
	check(house_bodies.size() == 2, "maisonnette : 2 collisions (murs, toit) issues de -convcolonly")
	check(props.get_node("Grass1").find_children("*", "StaticBody3D", true, false).is_empty(), "l'herbe n'a pas de collision")
	check(props.get_node("Bridge").find_children("*", "StaticBody3D", true, false).size() == 5, "pont : tablier (-colonly) + 2 rampes + 2 rambardes")
	var no_visible_collision_mesh := true
	for mesh_node in props.find_children("*", "MeshInstance3D", true, false):
		if "Collision" in String(mesh_node.name):
			no_visible_collision_mesh = false
	check(no_visible_collision_mesh, "aucun maillage de collision visible")
	var map := _player.get_world_3d().navigation_map
	var tree_position := (props.get_node("TreePine1") as Node3D).global_position
	var closest := NavigationServer3D.map_get_closest_point(map, tree_position)
	check(Vector2(closest.x - tree_position.x, closest.z - tree_position.z).length() > 0.5, "la navigation contourne le tronc d'un sapin")

	print("== Animations « open »")
	var door_anim := props.get_node("Door").find_child("AnimationPlayer") as AnimationPlayer
	var door_body := props.get_node("Door").find_child("DoorPanelCollision", true, false) as Node3D
	# Centre du battant dans le repère de sa collision (origine sur les gonds).
	var panel_center := Vector3(0.625, 1.125, 0.0)
	var door_before := door_body.global_transform * panel_center
	door_anim.play(&"open")
	door_anim.advance(1.0)
	await get_tree().physics_frame
	check((door_body.global_transform * panel_center).distance_to(door_before) > 0.3, "la porte s'ouvre et sa collision suit le battant")
	var chest_anim := props.get_node("Chest").find_child("AnimationPlayer") as AnimationPlayer
	check(chest_anim.has_animation(&"open"), "le coffre a son animation « open »")


func _wait_state(state: StringName, max_frames: int) -> void:
	for i in max_frames:
		if _player.state_machine.get_state_name() == state:
			return
		await get_tree().physics_frame
