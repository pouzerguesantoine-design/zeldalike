extends "res://tests/test_case.gd"
## Test automatique du jalon 4 : navigation, stats, patrouille, ligne de vue, poursuite,
## attaque télégraphiée, abandon et retour, barre de vie, mort, XP, butin, ramassage,
## inventaire sauvegardé. Utilisation : voir tests/test_case.gd.

const TEST_SAVE_PATH := "user://test_save_j4.json"

var _died: Array[Node] = []
var _picked: Array[ItemData] = []
var _main: Node
var _player: Player


func run() -> void:
	GameState.new_game()
	_main = load_main(true)
	_player = _main.get_node("Player") as Player
	EventBus.enemy_died.connect(func(enemy: Node) -> void: _died.append(enemy))
	EventBus.item_picked_up.connect(func(item: ItemData, _quantity: int) -> void: _picked.append(item))
	var slime := _main.get_node("Enemies/Slime1") as Enemy
	var slime2 := _main.get_node("Enemies/Slime2") as Enemy
	var goblin := _main.get_node("Enemies/Goblin1") as Enemy
	(_main.get_node("Enemies/Goblin2") as Node).queue_free()
	await frames(20)

	print("== Navigation et stats")
	var region := _main.get_node("NavigationRegion3D") as NavigationRegion3D
	check(region.navigation_mesh.get_polygon_count() > 0, "maillage de navigation cuit (%d polygones)" % region.navigation_mesh.get_polygon_count())
	check(slime.health.max_hp == 20 and goblin.health.max_hp == 35, "vie : Slime 20, Gobelin 35")
	check(goblin.hurtbox.defense == 2, "Défense du Gobelin appliquée à sa Hurtbox")
	check(is_equal_approx(float(slime.hurtbox.resistances.get(DamageInfo.DamageType.FEU, 1.0)), 1.5), "le Slime est faible au feu (×1,5)")
	check(not slime.health_bar.visible, "barre de vie cachée au départ")

	print("== Barre de vie pendant le lock-on")
	EventBus.lock_on_target_changed.emit(slime2)
	check(slime2.health_bar.visible and not slime.health_bar.visible, "visible sur la cible verrouillée seulement")
	EventBus.lock_on_target_changed.emit(null)
	check(not slime2.health_bar.visible, "cachée quand le lock-on est relâché")
	slime2.queue_free()

	print("== Patrouille")
	var goblin_start := goblin.global_position
	var slime_start := slime.global_position
	await frames(180)
	check(goblin.state_machine.get_state_name() == &"Patrol", "le Gobelin patrouille")
	check(goblin.global_position.distance_to(goblin_start) > 1.0, "il suit ses points de patrouille")
	check(slime.global_position.distance_to(slime_start) > 0.3, "le Slime erre autour de son point d'apparition")
	check(slime.global_position.distance_to(slime.spawn_position) <= slime.wander_radius + 1.5, "sans s'en éloigner")

	print("== Ligne de vue (RayCast)")
	teleport(goblin, Vector3(-14, 0, 9.5))
	check(not goblin.has_line_of_sight_to(Vector3(-14, 1, 2.5)), "bloquée par un rocher")
	check(goblin.has_line_of_sight_to(Vector3(-9, 1, 9.5)), "dégagée en terrain libre")

	print("== Détection et poursuite")
	teleport(goblin, Vector3(-14, 0, 12))
	goblin.model.rotation.y = -PI / 2.0  # regarde vers +X
	teleport(_player, Vector3(-7, 0.1, 12))
	await frames(10)
	check(goblin.state_machine.get_state_name() == &"Chase", "le joueur est repéré → Chase")
	var distance_before := goblin.distance_to_player()
	await frames(30)
	check(goblin.distance_to_player() < distance_before - 0.5 or goblin.state_machine.get_state_name() == &"Attack", "il se rapproche du joueur")

	print("== Attaque télégraphiée")
	var hp_before := _player.health.hp
	var frame := 0
	var telegraph_frame := -1
	var active_frame := -1
	var attacked := false
	while frame < 400:
		await get_tree().physics_frame
		frame += 1
		var state := goblin.state_machine.get_state_name()
		if state == &"Attack":
			attacked = true
			if telegraph_frame < 0 and goblin.telegraph.visible:
				telegraph_frame = frame
				# Capture : caméra tournée vers le Gobelin, barre de vie affichée.
				if not OS.get_cmdline_user_args().is_empty():
					var to_goblin := goblin.global_position - _player.global_position
					_player.camera_pivot.snap_to(atan2(-to_goblin.x, -to_goblin.z), -0.3)
					EventBus.lock_on_target_changed.emit(goblin)
					await frames(8)
					await save_screenshot_if_requested()
					EventBus.lock_on_target_changed.emit(null)
			if active_frame < 0 and goblin.attack_hitbox.active:
				active_frame = frame
		elif attacked:
			break
	check(attacked, "le Gobelin attaque")
	check(telegraph_frame >= 0 and active_frame - telegraph_frame >= 20, "« ! » visible %.2f s avant les frames actives" % ((active_frame - telegraph_frame) / 60.0))
	check(_player.health.hp == hp_before - 9, "coup reçu : (6 + Force 3) − Défense 1 × 0,5 = 8,5 → 9")

	print("== Abandon de la poursuite et retour au point d'apparition")
	await frames(40)
	teleport(_player, Vector3(-25, 0.1, -25))
	var returned := false
	for i in 420:
		await get_tree().physics_frame
		if goblin.state_machine.get_state_name() == &"Return":
			returned = true
			break
	check(returned, "hors de vue depuis %.0f s → Return" % goblin.lose_sight_time)
	var back_home := false
	for i in 600:
		await get_tree().physics_frame
		if goblin.state_machine.get_state_name() == &"Patrol":
			back_home = true
			break
	check(back_home and goblin.global_position.distance_to(goblin.spawn_position) < 1.5, "revenu chez lui, reprend sa patrouille")

	print("== Coup reçu : Hurt, recul, barre de vie")
	teleport(_player, slime.global_position + Vector3(0, 0.1, 3))
	var slime_position := slime.global_position
	check(slime.hurtbox.receive_hit(_player_hit(6.0)), "le Slime encaisse 6")
	await get_tree().physics_frame
	check(slime.state_machine.get_state_name() == &"Hurt", "état Hurt")
	await frames(20)
	check(slime.health_bar.visible, "barre de vie affichée après le premier coup")
	check(absf(slime.health_bar.get_ratio() - 0.7) < 0.02, "barre à 70 % (14 / 20)")
	check(slime.global_position.distance_to(slime_position) > 0.3, "recul")

	print("== Mort, XP et butin")
	var xp_before := GameState.player_stats.xp
	slime.hurtbox.receive_hit(_player_hit(100.0))
	await get_tree().physics_frame
	check(slime.state_machine.get_state_name() == &"Dead", "état Dead")
	check(_died == [slime], "EventBus.enemy_died émis")
	check(slime.collision_layer == 0 and not slime.is_in_group(&"lockable"), "collisions coupées, plus verrouillable")
	check(GameState.player_stats.xp == xp_before + 25, "+25 XP")
	var pickups := _pickups()
	check(pickups.any(func(p: Pickup) -> bool: return p.item.id == &"rupee"), "des rubis jaillissent (%d objet(s) lâché(s))" % pickups.size())
	await frames(100)
	check(not is_instance_valid(slime), "l'ennemi disparaît après un délai")

	print("== Ramassage")
	var rupees_before := GameState.rupees
	for pickup in _pickups():
		teleport(_player, pickup.global_position + Vector3(0, 0.1, 0))
		await frames(40)
	check(_pickups().is_empty(), "tout le butin est ramassé")
	check(GameState.rupees > rupees_before, "rubis : %d → %d" % [rupees_before, GameState.rupees])
	check(not _picked.is_empty(), "EventBus.item_picked_up émis")
	var hp_now := _player.health.hp
	_spawn_pickup(&"heart")
	await frames(40)
	check(_player.health.hp == mini(hp_now + 10, _player.health.max_hp), "un cœur rend 10 PV")
	var jelly_before := GameState.get_item_count(&"slime_jelly")
	_spawn_pickup(&"slime_jelly")
	await frames(40)
	check(GameState.get_item_count(&"slime_jelly") == jelly_before + 1, "la gelée va dans l'inventaire")

	print("== Table de butin")
	var table := load("res://resources/loot_tables/slime_loot.tres") as LootTable
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var rupee_every_time := true
	var jelly_seen := false
	var heart_seen := false
	for i in 200:
		var found_rupee := false
		for drop in table.roll(rng):
			var item_id: StringName = drop["item"].id
			if item_id == &"rupee":
				found_rupee = drop["quantity"] >= 1 and drop["quantity"] <= 2
			jelly_seen = jelly_seen or item_id == &"slime_jelly"
			heart_seen = heart_seen or item_id == &"heart"
		rupee_every_time = rupee_every_time and found_rupee
	check(rupee_every_time, "rubis garantis (1 à 2)")
	check(jelly_seen and heart_seen, "gelée et cœur tirés selon leurs poids et chances")

	print("== Sauvegarde de l'inventaire")
	var saved_rupees := GameState.rupees
	var saved_jelly := GameState.get_item_count(&"slime_jelly")
	check(GameState.save_game(TEST_SAVE_PATH), "écriture")
	GameState.new_game()
	check(GameState.rupees == 0 and GameState.inventory.is_empty(), "nouvelle partie : inventaire vide")
	check(GameState.load_game(TEST_SAVE_PATH), "lecture")
	check(GameState.rupees == saved_rupees and GameState.get_item_count(&"slime_jelly") == saved_jelly, "rubis et objets restaurés")
	delete_user_file(TEST_SAVE_PATH)


func _player_hit(raw_amount: float) -> DamageInfo:
	var info := DamageInfo.new()
	info.raw_amount = raw_amount
	info.knockback = 5.0
	info.source = _player
	return info


func _pickups() -> Array[Pickup]:
	var result: Array[Pickup] = []
	for node in _main.find_children("*", "Area3D", true, false):
		if node is Pickup and not node.is_queued_for_deletion():
			result.append(node)
	return result


func _spawn_pickup(item_id: StringName) -> void:
	var pickup := preload("res://scene/items/pickup.tscn").instantiate() as Pickup
	pickup.item = GameState.items[item_id]
	_main.add_child(pickup)
	pickup.global_position = _player.global_position
