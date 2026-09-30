extends "res://tests/test_case.gd"
## Test automatique du jalon 2 : courbe d'XP, montée de niveau, effet de la Vitesse,
## formule de dégâts, sauvegarde des stats. Utilisation : voir tests/test_case.gd.

const TEST_SAVE_PATH := "user://test_save_j2.json"

var _levels_received: Array[int] = []


func run() -> void:
	GameState.new_game()
	var main := load_main()
	var player := main.get_node("Player") as Player
	EventBus.level_up.connect(func(new_level: int) -> void: _levels_received.append(new_level))
	await frames(20)
	var stats := GameState.player_stats

	print("== Courbe d'XP : 100 × niveau^1,5")
	var expected := {1: 100, 2: 283, 4: 800, 10: 3162}
	for level: int in expected:
		stats.level = level
		check(stats.get_xp_to_next() == expected[level], "niveau %d → %d XP" % [level, expected[level]])
	stats.level = 1

	print("== Stats appliquées au joueur")
	check(player.health.max_hp == stats.max_hp and player.health.hp == stats.max_hp, "vie max = %d" % stats.max_hp)
	check(is_equal_approx(player.stamina.max_stamina, stats.max_stamina), "endurance max = %.0f" % stats.max_stamina)
	check(is_equal_approx(player.get_walk_speed(), player.walk_speed), "Vitesse 10 → vitesse de base")

	print("== Gain d'XP sans montée de niveau")
	GameState.add_xp(50)
	check(stats.level == 1 and stats.xp == 50 and _levels_received.is_empty(), "niveau 1, 50 XP")

	print("== Montée de niveau")
	player.health.take_damage(10, null)
	await frames(40)
	player.stamina.try_consume(50.0)
	var before := stats.to_dict()
	GameState.add_xp(60)
	check(stats.level == 2 and stats.xp == 10, "niveau 2, surplus de 10 XP conservé")
	check(_levels_received == [2], "EventBus.level_up(2) émis")
	check(stats.max_hp == before.max_hp + stats.hp_per_level, "vie max +%d" % stats.hp_per_level)
	check(stats.force == before.force + stats.force_per_level, "Force +%d" % stats.force_per_level)
	check(stats.defense == before.defense + stats.defense_per_level, "Défense +%d" % stats.defense_per_level)
	check(stats.speed == before.speed + stats.speed_per_level, "Vitesse +%d" % stats.speed_per_level)
	check(player.health.hp == stats.max_hp and player.health.max_hp == stats.max_hp, "vie restaurée et augmentée")
	check(is_equal_approx(player.stamina.stamina, stats.max_stamina), "endurance restaurée et augmentée")
	check(player.get_walk_speed() > player.walk_speed and player.get_run_speed() > player.run_speed, "la Vitesse accélère marche et course")
	await frames(20)
	check(is_instance_valid(player.level_up_effect) and player.level_up_effect.label.text.begins_with("NIVEAU SUPÉRIEUR !"), "effet « NIVEAU SUPÉRIEUR ! » affiché")
	await save_screenshot_if_requested()

	print("== Plusieurs niveaux d'un coup")
	_levels_received.clear()
	GameState.add_xp((283 - 10) + 520)
	check(stats.level == 4 and stats.xp == 0, "niveau 4")
	check(_levels_received == [3, 4], "un signal level_up par niveau")

	print("== Formule de dégâts")
	# (5 × 1 + 2) × 1 − 2 × 0,5 = 6
	check(DamageCalculator.compute(5, 1.0, 2, 1.0, false, 2) == 6, "coup simple = 6")
	# (10 × 1,5 + 4) × 1,2 × 1,5 − 6 × 0,5 = 31,2 → 31
	check(DamageCalculator.compute(10, 1.5, 4, 1.2, true, 6) == 31, "combo + critique = 31")
	check(DamageCalculator.compute(1, 1.0, 0, 1.0, false, 100) == 1, "minimum 1")
	var resistances := {DamageInfo.DamageType.FEU: 2.0, DamageInfo.DamageType.GLACE: 0.5}
	check(is_equal_approx(DamageCalculator.type_multiplier(resistances, DamageInfo.DamageType.FEU), 2.0), "faiblesse au feu ×2")
	check(is_equal_approx(DamageCalculator.type_multiplier(resistances, DamageInfo.DamageType.FOUDRE), 1.0), "type absent = ×1")
	check(DamageCalculator.compute(10, 1.0, 0, 1.0, false, 0, 0.5) == 5, "résistance ×0,5")

	print("== Sauvegarde et chargement des stats")
	await frames(40)  # fin de l'invincibilité
	player.health.take_damage(7, null)
	var saved_stats := stats.to_dict()
	var saved_hp := player.health.hp
	check(GameState.save_game(TEST_SAVE_PATH), "écriture")
	GameState.new_game()
	check(GameState.player_stats.level == 1 and player.health.max_hp == 30, "nouvelle partie : retour au niveau 1")
	check(GameState.load_game(TEST_SAVE_PATH), "lecture")
	check(GameState.player_stats.to_dict() == saved_stats, "stats identiques après chargement")
	check(player.health.max_hp == GameState.player_stats.max_hp and player.health.hp == saved_hp, "vie du joueur restaurée (%d)" % saved_hp)
	delete_user_file(TEST_SAVE_PATH)
