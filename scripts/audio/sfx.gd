class_name Sfx
extends RefCounted
## Joue un effet sonore de la bibliothèque : `Sfx.play(self, &"hit", position)`.
## Sans position (ou pour un son non spatialisé) : lecteur 2D. Le lecteur est créé à la
## volée et se détruit à la fin du son ; il continue de jouer pendant la pause (menus).

const LIBRARY: SoundLibrary = preload("res://resources/audio/sound_library.tres")
## Distance à laquelle un son 3D est entendu à plein volume / plus du tout (m).
const UNIT_SIZE := 8.0
const MAX_DISTANCE := 45.0
## Groupe des lecteurs en cours (pour tout couper avant de quitter).
const GROUP := &"sfx_players"


static func play(context: Node, id: StringName, position: Variant = null) -> Node:
	var effect := LIBRARY.get_effect(id)
	if effect == null or effect.stream == null or not context.is_inside_tree():
		push_warning("Son inconnu : %s" % id)
		return null
	var tree := context.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene else tree.root
	var player: Node
	if effect.positional and position is Vector3:
		var player_3d := AudioStreamPlayer3D.new()
		player_3d.unit_size = UNIT_SIZE
		player_3d.max_distance = MAX_DISTANCE
		player_3d.volume_db = effect.volume_db
		player_3d.pitch_scale = _random_pitch(effect)
		player_3d.stream = effect.stream
		player_3d.bus = effect.bus
		parent.add_child(player_3d)
		player_3d.global_position = position
		player_3d.play()
		player = player_3d
	else:
		var player_2d := AudioStreamPlayer.new()
		player_2d.volume_db = effect.volume_db
		player_2d.pitch_scale = _random_pitch(effect)
		player_2d.stream = effect.stream
		player_2d.bus = effect.bus
		parent.add_child(player_2d)
		player_2d.play()
		player = player_2d
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.add_to_group(GROUP)
	# Destruction à la fin du son (minuterie : fonctionne aussi sans pilote audio).
	var length := effect.stream.get_length() / maxf(player.get(&"pitch_scale"), 0.01)
	tree.create_timer(length + 0.1, true).timeout.connect(_release.bind(player))
	return player


## Arrête explicitement la lecture avant de libérer le lecteur (sinon le serveur audio peut
## garder la lecture active et Godot signale une fuite à la fermeture).
static func _release(player: Variant) -> void:
	if is_instance_valid(player):
		player.call(&"stop")
		player.queue_free()


## Coupe et libère tous les sons en cours. À appeler avant de quitter le jeu : sinon le
## serveur audio garde des lectures actives (fuite signalée à la fermeture).
static func stop_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group(GROUP):
		node.call(&"stop")
		node.free()


static func _random_pitch(effect: SoundEffect) -> float:
	return 1.0 + randf_range(-effect.pitch_variation, effect.pitch_variation)
