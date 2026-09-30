extends "res://tests/test_case.gd"
## Test automatique du jalon 3 : armes, combo, frames actives, dégâts, critiques,
## résistances, retour d'impact, magie et mana, équipement sauvegardé.
## Utilisation : voir tests/test_case.gd.

const TEST_SAVE_PATH := "user://test_save_j3.json"

var _hits: Array[DamageInfo] = []
var _hit_targets: Array[Node] = []

var _player: Player
var _screenshot_taken: bool = false
var _dummy: CharacterBody3D


func run() -> void:
	GameState.new_game()
	var main := load_main()
	_player = main.get_node("Player") as Player
	_dummy = main.get_node("Dummies/Dummy1") as CharacterBody3D
	var machine := _player.state_machine
	EventBus.damage_dealt.connect(func(target: Node, info: DamageInfo) -> void:
		_hit_targets.append(target)
		_hits.append(info))
	await frames(20)

	print("== Catalogue d'armes")
	check(GameState.weapons.size() == 3, "3 armes chargées depuis resources/weapons/")
	for weapon_id: StringName in [&"wooden_sword", &"knight_sword", &"fire_blade"]:
		var weapon: WeaponData = GameState.weapons.get(weapon_id)
		check(weapon != null and weapon.icon != null and weapon.model_scene != null, "%s : icône et modèle" % weapon_id)
	check(GameState.weapons[&"fire_blade"].damage_type == DamageInfo.DamageType.FEU, "la Lame de feu inflige du feu")
	check(GameState.equipped_weapon.id == &"wooden_sword", "épée en bois équipée au départ")
	check(_player.weapon_socket.get_child_count() == 1, "le modèle de l'arme est dans la main")

	print("== Combo en 3 coups (épée en bois, sans critique)")
	_equip_without_crit(&"wooden_sword")
	await _place_in_front_of_dummy()
	var dummy_start := _dummy.global_position
	var stamina_before := _player.stamina.stamina
	var result := await _attack_sequence(3)
	check(result.animations == [&"attack_1", &"attack_2", &"attack_3"], "3 animations enchaînées grâce au buffer %s" % [result.animations])
	check(result.activations == 3, "Hitbox activée 3 fois, uniquement pendant les frames actives (%d images actives sur %d)" % [result.active_frames, result.total_frames])
	check(_amounts() == [6, 7, 10], "dégâts du combo : (4 + Force 2) × [1 ; 1,2 ; 1,6] = %s" % [_amounts()])
	check(_hit_targets.all(func(t: Node) -> bool: return t == _dummy), "chaque coup touche le mannequin une seule fois")
	check(absf(result.stamina_after - (stamina_before - 3 * 6.0)) < 0.5, "endurance : 3 × 6 consommés")
	check(result.saw_flash, "flash blanc du mannequin")
	check(result.saw_hit_stop, "hit-stop à l'impact")
	check(result.saw_shake, "tremblement de caméra")
	check(result.saw_number, "chiffre de dégâts flottant")
	check((_dummy.global_position - dummy_start).z < -0.3, "recul du mannequin")
	check(machine.get_state_name() in [&"Idle", &"Walk"], "retour au sol après le combo")

	print("== Un seul clic = un seul coup")
	_hits.clear()
	await _place_in_front_of_dummy()
	result = await _attack_sequence(1)
	check(result.animations == [&"attack_1"] and _hits.size() == 1, "un clic → attack_1 seulement")

	print("== Nouveau combo : il repart du 1er coup")
	_hits.clear()
	await _place_in_front_of_dummy()
	result = await _attack_sequence(2)
	check(result.animations == [&"attack_1", &"attack_2"], "attack_1 puis attack_2")

	print("== Épée de chevalier et Lame de feu")
	_hits.clear()
	_equip_without_crit(&"knight_sword")
	check(is_equal_approx((_player.weapon_hitbox.get_node("CollisionShape3D").get("shape") as BoxShape3D).size.z, 1.8), "portée de la zone de coup = 1,8 m")
	await _place_in_front_of_dummy()
	await _attack_sequence(1)
	check(_amounts() == [12], "chevalier : (8 × 1,2 + 2) = 11,6 → 12")
	_hits.clear()
	_equip_without_crit(&"fire_blade")
	var dummy_hurtbox := _dummy.get_node("Hurtbox") as Hurtbox
	dummy_hurtbox.resistances = {DamageInfo.DamageType.FEU: 2.0}
	await _place_in_front_of_dummy()
	await _attack_sequence(1)
	check(_hits.size() == 1 and _hits[0].damage_type == DamageInfo.DamageType.FEU, "coup de type FEU")
	check(_amounts() == [22], "faiblesse au feu ×2 : (7 × 1,3 + 2) × 2 = 22")
	dummy_hurtbox.resistances = {}

	print("== Coup critique")
	_hits.clear()
	var always_critical := GameState.weapons[&"wooden_sword"].duplicate() as WeaponData
	always_critical.critical_chance = 1.0
	GameState.equip_weapon(always_critical)
	await _place_in_front_of_dummy()
	result = await _attack_sequence(1)
	check(_hits.size() == 1 and _hits[0].is_critical and _hits[0].amount == 9, "critique : 6 × 1,5 = 9")
	check(result.critical_number, "chiffre critique jaune avec « ! »")
	_equip_without_crit(&"wooden_sword")

	print("== Magie : boule d'énergie")
	_hits.clear()
	# Les combos ont repoussé le mannequin : on le remet à sa place d'origine.
	teleport(_dummy, Vector3(0, 0, -8))
	await _place_in_front_of_dummy()
	teleport(_player, Vector3(0, 0.1, -3))
	await frames(5)
	await send_action("lock_on")
	check(_player.lock_on.target == _dummy, "mannequin verrouillé")
	var mana_before := _player.mana.mana
	Input.action_press("magic")
	await frames(2)
	Input.action_release("magic")
	check(machine.get_state_name() == &"Magic", "état Magic")
	var magic_hit := false
	var lowest_mana := mana_before
	for i in 150:
		await get_tree().physics_frame
		lowest_mana = minf(lowest_mana, _player.mana.mana)
		if _hits.any(func(h: DamageInfo) -> bool: return h.damage_type == DamageInfo.DamageType.MAGIE):
			magic_hit = true
			break
	check(magic_hit and _hit_targets.back() == _dummy, "la boule d'énergie atteint la cible verrouillée")
	check(_hits.size() == 1 and _hits[0].amount == 8, "dégâts magiques : 6 + Force 2 = 8")
	check(is_equal_approx(lowest_mana, mana_before - 10.0), "10 de mana consommés")
	await send_action("lock_on")

	print("== Mana insuffisant, puis régénération")
	await frames(30)
	_player.mana.set_mana(5.0)
	Input.action_press("magic")
	await frames(2)
	Input.action_release("magic")
	check(machine.get_state_name() != &"Magic", "pas de sort avec 5 de mana")
	await frames(60)
	check(_player.mana.mana > 8.0, "le mana se régénère (%.1f)" % _player.mana.mana)

	print("== Défense du joueur (Hurtbox)")
	await frames(30)
	var hp_before := _player.health.hp
	var incoming := DamageInfo.new()
	incoming.raw_amount = 10.6
	incoming.source = _dummy
	check(_player.hurtbox.receive_hit(incoming), "le joueur encaisse le coup")
	check(_player.health.hp == hp_before - 10, "10,6 − Défense 1 × 0,5 = 10 dégâts")
	check(machine.get_state_name() == &"Hurt", "état Hurt")

	print("== Sauvegarde de l'arme équipée")
	await frames(40)
	GameState.equip_weapon_by_id(&"knight_sword")
	check(GameState.save_game(TEST_SAVE_PATH), "écriture")
	GameState.new_game()
	check(GameState.equipped_weapon.id == &"wooden_sword", "nouvelle partie : épée en bois")
	check(GameState.load_game(TEST_SAVE_PATH) and GameState.equipped_weapon.id == &"knight_sword", "chargement : épée de chevalier")
	check(_player.weapon_socket.get_child(_player.weapon_socket.get_child_count() - 1).name == &"KnightSword", "le modèle en main a changé")
	delete_user_file(TEST_SAVE_PATH)


## Équipe une copie de l'arme sans critique (dégâts prévisibles).
func _equip_without_crit(weapon_id: StringName) -> void:
	var weapon := GameState.weapons[weapon_id].duplicate() as WeaponData
	weapon.critical_chance = 0.0
	GameState.equip_weapon(weapon)


## Place le joueur à 1,6 m devant le mannequin, tourné vers lui, endurance pleine.
func _place_in_front_of_dummy() -> void:
	while _player.state_machine.get_state_name() not in [&"Idle", &"Walk"]:
		await get_tree().physics_frame
	teleport(_player, _dummy.global_position + Vector3(0, 0.1, 1.6))
	_player.model.rotation.y = 0.0
	_player.camera_pivot.snap_to(0.0, -0.35)
	_player.stamina.set_max_stamina(_player.stamina.max_stamina, true)
	await frames(10)


## Lance une attaque puis clique `clicks - 1` fois de plus pendant les coups (avant la
## fenêtre d'enchaînement), et observe tout jusqu'au retour à un état au sol.
func _attack_sequence(clicks: int) -> Dictionary:
	var result := {
		"animations": [], "activations": 0, "active_frames": 0, "total_frames": 0,
		"stamina_after": 0.0, "saw_flash": false, "saw_hit_stop": false, "saw_shake": false,
		"saw_number": false, "critical_number": false,
	}
	var flash := _dummy.get_node("HitFlash") as HitFlash
	var clicks_done := 1
	var was_active := false
	Input.action_press("attack")
	for i in 600:
		await get_tree().physics_frame
		Input.action_release("attack")
		var state := _player.state_machine.get_state_name()
		if state != &"Attack":
			if i > 1:
				break
			continue
		result.total_frames += 1
		result.stamina_after = _player.stamina.stamina
		var active := _player.weapon_hitbox.active
		if active:
			result.active_frames += 1
			if not was_active:
				result.activations += 1
		was_active = active
		var current := StringName(_player.anim.current_animation)
		if current != &"" and (result.animations.is_empty() or result.animations.back() != current):
			result.animations.append(current)
		result.saw_flash = result.saw_flash or flash.is_flashing()
		result.saw_hit_stop = result.saw_hit_stop or HitStop.is_active()
		result.saw_shake = result.saw_shake or _player.camera_pivot.is_shaking()
		for child in get_children():
			if child is DamageNumber:
				result.saw_number = true
				result.critical_number = result.critical_number or (child as DamageNumber).text.ends_with("!")
		# Capture d'écran au premier impact du premier combo.
		if result.saw_number and not _screenshot_taken:
			_screenshot_taken = true
			await frames(3)
			await save_screenshot_if_requested()
		# Un clic par coup, pendant le coup en cours et avant l'ouverture de la fenêtre.
		if clicks_done < clicks and result.animations.size() == clicks_done \
				and not _player.combo_window_open and _player.anim.current_animation_position > 0.02:
			Input.action_press("attack")
			clicks_done += 1
	return result


func _amounts() -> Array[int]:
	var result: Array[int] = []
	for info in _hits:
		result.append(info.amount)
	return result
