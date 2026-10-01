extends "res://tests/test_case.gd"
## Test automatique du jalon 8 : sons (bibliothèque, bus, lecteurs qui se libèrent),
## sons et particules branchés sur le gameplay, réglages d'équilibrage dans les Resources.

const EXPECTED_SOUNDS: Array[StringName] = [&"footstep", &"sword_swing", &"hit", &"hit_critical",
	&"player_hurt", &"slime_hurt", &"goblin_hurt", &"enemy_death", &"enemy_alert", &"pickup_rupee",
	&"pickup_item", &"pickup_heart", &"chest_open", &"door_open", &"door_locked", &"level_up",
	&"save_game", &"magic_cast", &"magic_hit", &"jump", &"roll", &"ui_move", &"ui_confirm", &"ui_open", &"ui_close"]
const FX_SCENES := ["impact_sparks", "dust_puff", "death_puff", "pickup_sparkle", "magic_burst"]

## Sons et effets apparus dans la scène (noms des fichiers audio, noms des effets).
var _sounds: Array[String] = []
var _effects: Array[String] = []


func run() -> void:
	GameState.new_game()
	child_entered_tree.connect(_on_node_added)

	print("== Bibliothèque de sons")
	var library := Sfx.LIBRARY
	var missing := EXPECTED_SOUNDS.filter(func(id: StringName) -> bool:
		var effect := library.get_effect(id)
		return effect == null or effect.stream == null)
	check(missing.is_empty(), "%d sons générés et référencés %s" % [EXPECTED_SOUNDS.size(), missing])
	check(AudioServer.get_bus_index(&"SFX") > 0 and AudioServer.get_bus_index(&"UI") > 0, "bus audio SFX et UI")
	var player_node := Sfx.play(self, &"hit", Vector3.ZERO)
	check(player_node is AudioStreamPlayer3D and player_node.is_in_group(Sfx.GROUP), "son 3D joué")
	check(Sfx.play(self, &"ui_confirm") is AudioStreamPlayer, "son d'interface non spatialisé")
	await get_tree().create_timer(0.6).timeout
	check(not is_instance_valid(player_node), "le lecteur se libère à la fin du son")

	print("== Particules")
	for fx_name: String in FX_SCENES:
		var fx := FxBurst.spawn(self, load("res://scene/fx/%s.tscn" % fx_name), Vector3.ZERO, Color.RED)
		var particles := fx.get_node("Particles") as CPUParticles3D
		check(particles.emitting and particles.color == Color.RED, "%s : émet, teinte appliquée" % fx_name)
	await get_tree().create_timer(1.5).timeout
	check(find_children("*", "CPUParticles3D", true, false).is_empty(), "les effets se détruisent après leur durée")

	print("== Sons et effets en jeu")
	var main := load_main(true)
	var player := main.get_node("Player") as Player
	var goblin := main.get_node("Enemies/Goblin1") as Enemy
	var slime := main.get_node("Enemies/Slime1") as Enemy
	for other in ["Enemies/Goblin2", "Enemies/Slime2"]:
		main.get_node(other).queue_free()
	await frames(20)
	# Pas
	player.camera_pivot.snap_to(PI, -0.3)
	Input.action_press("move_forward")
	await frames(75)
	Input.action_release("move_forward")
	check(_sounds.count("footstep") >= 2, "bruits de pas en marchant (%d)" % _sounds.count("footstep"))
	# Saut, roulade
	await frames(30)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(60)
	Input.action_press("dodge")
	await frames(2)
	Input.action_release("dodge")
	await frames(3)
	check(_sounds.has("jump") and _sounds.has("roll") and _effects.has("DustPuff"), "saut, roulade + poussière")
	await frames(40)
	# Attaque sur un mannequin
	var dummy := main.get_node("Dummies/Dummy1") as Node3D
	teleport(player, dummy.global_position + Vector3(0, 0.1, 1.6))
	player.model.rotation.y = 0.0
	await frames(20)
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	await frames(20)
	check(_sounds.has("sword_swing") and _sounds.has("hit") and _effects.has("ImpactSparks"), "coup d'épée : souffle, impact, étincelles")
	# Ennemis : alerte, douleur, mort
	teleport(goblin, Vector3(-14, 0, 12))
	goblin.model.rotation.y = -PI / 2.0
	teleport(player, Vector3(-8, 0.1, 12))
	await frames(10)
	check(_sounds.has("enemy_alert"), "cri d'alerte quand le Gobelin repère le joueur")
	var hit := DamageInfo.new()
	hit.raw_amount = 5.0
	hit.source = player
	slime.hurtbox.receive_hit(hit)
	await frames(2)
	check(_sounds.has("slime_hurt"), "le Slime a son propre cri de douleur")
	hit = hit.copy()
	hit.raw_amount = 100.0
	slime.hurtbox.receive_hit(hit)
	await frames(3)
	check(_sounds.has("enemy_death") and _effects.has("DeathPuff"), "mort : son + nuage de fumée")
	# Ramassage
	await frames(40)
	var pickup := preload("res://scene/items/pickup.tscn").instantiate() as Pickup
	pickup.item = GameState.items[&"rupee"]
	main.add_child(pickup)
	pickup.global_position = player.global_position
	await frames(40)
	check(_sounds.has("pickup_rupee") and _effects.has("PickupSparkle"), "ramassage de rubis : son + scintillement")
	# Niveau
	GameState.add_xp(200)
	await frames(2)
	check(_sounds.has("level_up"), "jingle de montée de niveau")

	print("== Équilibrage : réglages dans les Resources")
	check(player.tuning.resource_path == "res://resources/balance/player_tuning.tres", "réglages du joueur dans player_tuning.tres")
	var tuning := player.tuning.duplicate() as PlayerTuning
	tuning.walk_speed = 7.5
	player.tuning = tuning
	check(is_equal_approx(player.walk_speed, 7.5), "modifier la Resource change le jeu (vitesse de marche)")
	check(is_equal_approx(player.stamina.regen_per_second, player.tuning.stamina_regen_per_second), "régénération d'endurance lue dans les réglages")
	check(GameState.BASE_PLAYER_STATS.resource_path.begins_with("res://resources/stats/") and goblin.stats.resource_path.begins_with("res://resources/stats/"),
		"stats du joueur et des ennemis dans resources/stats/")


func _on_node_added(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		var stream: AudioStream = node.get(&"stream")
		if stream:
			_sounds.append(stream.resource_path.get_file().get_basename())
	elif node is FxBurst:
		_effects.append(String(node.name).lstrip("@").rstrip("0123456789@"))
