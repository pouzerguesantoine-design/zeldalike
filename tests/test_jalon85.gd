extends "res://tests/test_case.gd"
## Test automatique du jalon 8.5 : cel-shading, contours, réglages graphiques (Bas / Moyen /
## Haut), environnement, cycle jour/nuit, herbe, eau, traînée d'épée, effets d'impact,
## vignette de dégâts, modèles enrichis. Le réglage du joueur n'est pas modifié (persist = false).

var _level: Node
var _player: Player


func run() -> void:
	var previous_quality := GameState.graphics_quality
	GameState.new_game()
	GameState.set_graphics_quality(GameState.Quality.HAUT, false)
	_level = load("res://scene/world/island.tscn").instantiate()
	var enemies := _level.get_node("Enemies")
	_level.remove_child(enemies)
	enemies.free()
	add_child(_level)
	_player = _level.get_node("Player") as Player
	var nav := _level.get_node("NavigationRegion3D")
	await frames(30)

	print("== Cel-shading")
	check(_all_toon(_player.body_model), "héros entièrement cel-shadé")
	check(_all_toon(_player.weapon_socket), "épée cel-shadée")
	var goblin := (load("res://scene/enemies/goblin.tscn") as PackedScene).instantiate() as Enemy
	_level.add_child(goblin)
	goblin.global_position = Vector3(30, 0, 30)
	var slime := (load("res://scene/enemies/slime.tscn") as PackedScene).instantiate() as Enemy
	_level.add_child(slime)
	slime.global_position = Vector3(32, 0, 30)
	await frames(2)
	check(_all_toon(goblin.visual) and _all_toon(slime.visual), "Gobelin et Slime cel-shadés (gelée transparente en éclairage toon)")
	var foliage := nav.get_node("Village/TreeWest").find_child("TreeRoundFoliage", true, false) as MeshInstance3D
	check((foliage.get_active_material(0) as ShaderMaterial).shader == ToonMaterials.FOLIAGE_SHADER, "feuillage des arbres qui ondule (shader dédié)")
	check(_all_toon(nav.get_node("Village/HouseWest")), "décor cel-shadé")

	print("== Modèles enrichis")
	check(_player.body_model.find_child("PlayerBody", true, false).get("mesh").get_surface_count() >= 13, "héros : 13 matériaux (bouclier, ceinture, sourcils…)")
	check(goblin.visual.find_child("GoblinBody", true, false).get("mesh").get_surface_count() >= 9, "Gobelin enrichi")

	print("== Réglages graphiques")
	var environment := (_level.get_node("WorldEnvironment") as WorldEnvironment).environment
	var outline := _player.find_child("OutlinePost", true, false) as OutlinePost
	var grass := _level.get_node("Grass") as GrassField
	var counts: Array[int] = []
	for quality in [GameState.Quality.BAS, GameState.Quality.MOYEN, GameState.Quality.HAUT]:
		GameState.set_graphics_quality(quality, false)
		await frames(3)
		counts.append(grass.blade_count)
		var label: String = GameState.QUALITY_NAMES[quality]
		match quality:
			GameState.Quality.BAS:
				check(not environment.sdfgi_enabled and not environment.ssao_enabled and not environment.volumetric_fog_enabled and not outline.visible,
					"%s : ni GI, ni SSAO, ni brouillard volumétrique, ni contours" % label)
				check(get_tree().root.scaling_3d_scale < 1.0, "%s : résolution 3D réduite" % label)
			GameState.Quality.MOYEN:
				check(environment.ssao_enabled and environment.glow_enabled and not environment.sdfgi_enabled and outline.visible,
					"%s : SSAO, éclat et contours ; sans SDFGI" % label)
			GameState.Quality.HAUT:
				check(environment.sdfgi_enabled and environment.volumetric_fog_enabled and outline.visible
					and get_tree().root.msaa_3d == Viewport.MSAA_2X, "%s : SDFGI, brouillard volumétrique, MSAA" % label)
	check(counts[0] < counts[1] and counts[1] < counts[2], "densité d'herbe selon la qualité %s" % [counts])
	check(environment.tonemap_mode == Environment.TONE_MAPPER_ACES and environment.adjustment_enabled and environment.fog_enabled,
		"tonemap ACES, étalonnage chaud, brouillard léger")
	var pause := (_level.get_node("GameUI") as GameUI).pause_menu
	check(pause.graphics_option.item_count == 3 and pause.graphics_option.get_item_text(0) == "Bas", "choix Bas / Moyen / Haut dans le menu pause")

	print("== Cycle jour / nuit")
	var cycle := _level.get_node("DayNight") as DayNightCycle
	cycle.running = false
	cycle.set_hour(12.0)
	var sun := _level.get_node("Sun") as DirectionalLight3D
	var moon := _level.get_node("Moon") as DirectionalLight3D
	var sky := environment.sky.sky_material as ProceduralSkyMaterial
	var noon_sky := sky.sky_top_color
	check(sun.visible and sun.light_energy > 1.2 and not moon.visible, "midi : plein soleil")
	cycle.set_hour(23.0)
	check(not sun.visible and moon.visible and cycle.is_night(), "23 h : clair de lune")
	check(sky.sky_top_color.v < noon_sky.v * 0.5, "le ciel s'assombrit la nuit")
	cycle.set_hour(10.0)

	print("== Eau stylisée")
	var sea_material := (_level.get_node("Sea") as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
	var river_material := (_level.get_node("River") as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
	check(sea_material and sea_material.shader.resource_path.ends_with("water.gdshader"), "mer : shader d'eau avec écume au rivage")
	check(river_material and river_material.get_shader_parameter(&"river_mode") == true, "rivière : courant + écume sur les berges")

	print("== Effets")
	teleport(_player, Vector3(0, 0.1, 20))
	for i in 60:
		await get_tree().physics_frame
		if _player.state_machine.get_state_name() == &"Idle":
			break
	var trail := _player.get_node("SwordTrail") as SwordTrail
	_player.stamina.set_max_stamina(_player.stamina.max_stamina, true)
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	await frames(8)
	check(trail.point_count() > 3, "traînée d'épée pendant le coup (%d points)" % trail.point_count())
	await frames(60)
	check(trail.point_count() == 0, "la traînée s'efface après le coup")
	var impact := (load("res://scene/fx/impact_sparks.tscn") as PackedScene).instantiate()
	check(impact.find_children("*", "CPUParticles3D", true, false).size() == 3, "impact : étincelles + éclair + débris")
	impact.free()
	var hud := (_level.get_node("GameUI") as GameUI).hud
	_player.health.take_damage(3, null)
	await frames(2)
	check(hud.damage_vignette.modulate.a > 0.5, "bords de l'écran rouges quand le héros est touché")

	GameState.set_graphics_quality(previous_quality, false)


## Toutes les surfaces visibles sont en cel-shading (shader toon ou matériau en éclairage toon).
func _all_toon(root: Node) -> bool:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return false
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface)
			var toon_standard := material is BaseMaterial3D and (material as BaseMaterial3D).diffuse_mode == BaseMaterial3D.DIFFUSE_TOON
			if not ToonMaterials.is_toon(material) and not toon_standard:
				return false
	return true
