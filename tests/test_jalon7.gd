extends "res://tests/test_case.gd"
## Test automatique du jalon 7 : HUD (cœurs, endurance + barre fantôme, XP, rubis, arme,
## lock-on), inventaire (grille, fiche, Utiliser / Équiper / Jeter, comparaison, clavier),
## menu pause, point de sauvegarde, écran de mort et réapparition, écran titre.
## Utilise un fichier de sauvegarde de test : la vraie sauvegarde n'est jamais touchée.

const TEST_SAVE_PATH := "user://test_save_j7.json"

var _level: Node
var _player: Player
var _ui: GameUI
var _texts_seen: Array[String] = []


func run() -> void:
	GameState.save_path = TEST_SAVE_PATH
	delete_user_file(TEST_SAVE_PATH)
	GameState.new_game()
	await _load_level()
	child_entered_tree.connect(func(node: Node) -> void:
		if node is FloatingText: _texts_seen.append((node as FloatingText).text))
	var hud := _ui.hud

	print("== HUD : cœurs")
	check(hud.get_heart_count() == 3 and _heart_values(hud) == [10.0, 10.0, 10.0], "3 cœurs pleins pour 30 PV")
	_player.health.take_damage(5, null)
	await frames(2)
	check(_heart_values(hud) == [10.0, 10.0, 5.0], "5 dégâts → dernier cœur à moitié (remplissage par quarts)")
	GameState.add_xp(100)
	await frames(2)
	check(hud.get_heart_count() == 4 and _heart_values(hud) == [10.0, 10.0, 10.0, 5.0], "niveau 2 : 35 PV = 3 cœurs et demi")
	check(hud.level_label.text == "Niv. 2" and hud.xp_label.text == "0 / 283 XP", "niveau et XP : %s, %s" % [hud.level_label.text, hud.xp_label.text])

	print("== HUD : endurance, rubis, arme")
	_player.stamina.try_consume(40.0)
	await frames(2)
	var stamina_percent := 100.0 * _player.stamina.stamina / _player.stamina.max_stamina
	check(is_equal_approx(hud.stamina_bar.value, stamina_percent) and hud.stamina_ghost.value > hud.stamina_bar.value + 20.0,
		"la barre descend, la barre fantôme reste en arrière (%.0f / %.0f)" % [hud.stamina_bar.value, hud.stamina_ghost.value])
	await frames(60)
	check(hud.stamina_ghost.value < hud.stamina_bar.value + 5.0, "puis la barre fantôme la rattrape")
	GameState.add_item(GameState.items[&"rupee"], 12)
	await frames(60)
	check(hud.rupee_label.text == "012", "compteur de rubis « %s »" % hud.rupee_label.text)
	check(hud.weapon_icon.texture == GameState.equipped_weapon.icon and hud.weapon_label.text == "Épée en bois", "icône de l'arme équipée")

	print("== HUD : lock-on")
	var slime := (load("res://scene/enemies/slime.tscn") as PackedScene).instantiate() as Enemy
	_level.add_child(slime)
	slime.global_position = Vector3(30, 0, 30)
	EventBus.lock_on_target_changed.emit(slime)
	await frames(25)
	check(hud.is_letterbox_visible() and hud.target_label.visible and hud.target_label.text == "◆ Slime", "bandes noires + « ◆ Slime »")
	EventBus.lock_on_target_changed.emit(null)
	await frames(25)
	check(not hud.is_letterbox_visible() and not hud.target_label.visible, "bandes retirées au relâchement")
	slime.queue_free()
	await save_screenshot_if_requested("hud")

	print("== Inventaire : ouverture et grille")
	for pair in [[&"potion", 2], [&"knight_sword_item", 1], [&"fire_blade_item", 1], [&"slime_jelly", 3], [&"small_key", 1]]:
		GameState.add_item(GameState.items[pair[0]], pair[1])
	var inventory := _ui.inventory
	await send_action(&"inventory")
	await frames(3)
	check(inventory.is_open() and get_tree().paused, "I ouvre l'inventaire et met le jeu en pause")
	var slots := inventory.get_slots()
	check(slots.size() == 6, "6 objets dans la grille (%d)" % slots.size())
	check(get_viewport().gui_get_focus_owner() == slots[0], "le 1er objet a le focus clavier")
	await send_action(&"ui_right")
	check(get_viewport().gui_get_focus_owner() == slots[1], "flèche droite → objet suivant")

	print("== Inventaire : Utiliser, Équiper, Jeter")
	await _select_slot(inventory, "Potion")
	check(inventory.detail_name.text == "Potion" and not inventory.use_button.disabled, "fiche de la potion, bouton Utiliser actif")
	check(_slot(inventory, "Potion").text == "×2", "quantité affichée (×2)")
	_player.health.take_damage(20, null)
	inventory.use_selected()
	check(_player.health.hp == _player.health.max_hp and GameState.get_item_count(&"potion") == 1, "potion bue : vie remplie, reste 1")
	await _select_slot(inventory, "Épée de chevalier")
	check(not inventory.equip_button.disabled, "bouton Équiper actif sur une arme")
	inventory.equip_selected()
	check(GameState.equipped_weapon.id == &"knight_sword", "épée de chevalier équipée depuis la grille")
	await _select_slot(inventory, "Gelée de slime")
	inventory.drop_selected()
	check(GameState.get_item_count(&"slime_jelly") == 2, "gelée jetée (reste 2)")
	var dropped := _level.find_children("*", "Area3D", true, false).filter(func(n: Node) -> bool: return n is Pickup)
	check(dropped.size() == 1 and not (dropped[0] as Pickup).magnet_enabled, "l'objet jeté est posé au sol (non aspiré)")
	await _select_slot(inventory, "Petite clé")
	check(inventory.drop_button.disabled, "une clé ne peut pas être jetée")

	print("== Inventaire : onglet Équipement")
	await send_action(&"lock_on")
	await frames(3)
	check(inventory.tabs.current_tab == 1, "Tab → onglet Équipement")
	var fire_button: Button = null
	for button in inventory.weapon_list.get_children():
		if (button as Button).text.begins_with("Lame de feu"):
			fire_button = button
	check(inventory.weapon_list.get_child_count() == 3 and fire_button != null, "3 armes possédées")
	fire_button.grab_focus()
	await frames(2)
	var arrows := inventory.get_comparison_arrows()
	check(arrows.get("Dégâts") == "▼" and arrows.get("Critique %") == "▲" and arrows.get("Endurance / coup") == "▲",
		"comparaison Lame de feu vs chevalier : %s" % [arrows])
	check(inventory.stats_grid.get_child_count() == 16, "8 statistiques affichées")
	await save_screenshot_if_requested("inventaire")
	await send_action(&"inventory")
	check(not inventory.is_open() and not get_tree().paused, "I referme et relance le jeu")

	print("== Menu pause")
	await send_action(&"pause")
	await frames(2)
	var pause := _ui.pause_menu
	check(pause.is_open() and get_tree().paused, "Échap ouvre la pause")
	check(get_viewport().gui_get_focus_owner() == pause.resume_button, "focus sur « Reprendre »")
	check(pause.load_button.disabled, "« Charger » grisé sans sauvegarde")
	pause.save()
	check(FileAccess.file_exists(TEST_SAVE_PATH) and pause.message_label.text == "Partie sauvegardée.", "« Sauvegarder » écrit la partie")
	await send_action(&"pause")
	check(not pause.is_open() and not get_tree().paused, "Échap reprend la partie")

	print("== Point de sauvegarde")
	var statue := _level.get_node("NavigationRegion3D/SavePoint") as SavePoint
	await _face(statue, 1.6)
	_player.health.take_damage(8, null)
	await frames(40)
	await _press(&"interact")
	check(_player.health.hp == _player.health.max_hp and _texts_seen.has("Partie sauvegardée"), "E : sauvegarde + vie rendue")
	var saved_position := _player.global_position

	print("== Mort et réapparition")
	_player.health.take_damage(999, null)
	await frames(110)
	var death := _ui.death_screen
	check(death.is_open() and death.hint_label.text.begins_with("Vous reprendrez"), "écran de mort après la chute")
	check(GameState.prepare_respawn(), "« Réapparaître » recharge la sauvegarde")
	await _load_level()
	check(_player.global_position.distance_to(saved_position) < 0.5, "réapparition au point de sauvegarde")
	check(_player.health.hp == _player.health.max_hp and GameState.equipped_weapon.id == &"knight_sword", "vie pleine, équipement conservé")
	check(not get_tree().paused and not _ui.death_screen.is_open(), "partie relancée")

	print("== Écran titre")
	_level.queue_free()
	await frames(2)
	var title := (load("res://scene/ui/title_screen.tscn") as PackedScene).instantiate() as TitleScreen
	add_child(title)
	await frames(5)
	check(not title.continue_button.disabled, "« Continuer » disponible (une sauvegarde existe)")
	check(title.new_game_button.text == "Nouvelle partie" and title.quit_button.text == "Quitter", "Nouvelle partie / Continuer / Quitter")
	check(title.viewport.find_child("Player", true, false) == null and title.viewport.get_child_count() >= 2, "l'île tourne en arrière-plan (sans joueur)")
	await frames(20)
	await save_screenshot_if_requested("titre")
	title.queue_free()
	delete_user_file(TEST_SAVE_PATH)
	GameState.save_path = GameState.SAVE_PATH


func _load_level() -> void:
	if is_instance_valid(_level):
		_level.queue_free()
		await frames(2)
	_level = load("res://scene/world/island.tscn").instantiate()
	var enemies := _level.get_node("Enemies")
	_level.remove_child(enemies)
	enemies.free()
	add_child(_level)
	_player = _level.get_node("Player") as Player
	_ui = _level.get_node("GameUI") as GameUI
	await frames(20)


func _heart_values(hud: HUD) -> Array[float]:
	var values: Array[float] = []
	for i in hud.get_heart_count():
		values.append(snappedf(hud.get_heart_value(i), 0.01))
	return values


func _slot(inventory: InventoryMenu, item_name: String) -> Button:
	for slot in inventory.get_slots():
		if slot.tooltip_text == item_name:
			return slot
	return null


func _select_slot(inventory: InventoryMenu, item_name: String) -> void:
	_slot(inventory, item_name).grab_focus()
	await frames(2)


func _face(target: Node3D, distance: float) -> void:
	var front := Vector3(0, 0, 1)
	teleport(_player, target.global_position + front * distance + Vector3.UP * 0.1)
	_player.face_direction_instant(-front)
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
