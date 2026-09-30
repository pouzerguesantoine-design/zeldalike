extends SceneTree
## Génère resources/animation/player_animation_tree.tres : la machine à états de
## l'AnimationTree du joueur (modifiable ensuite dans l'éditeur).
## Lancer : godot --headless --path . -s res://tools/godot/build_player_animation_tree.gd
##
##   locomotion : BlendSpace1D idle (0) → walk (5 m/s) → run (9 m/s)
##   jump, fall, roll, roll_back (roulade jouée à l'envers), cast, hurt, death
##   attack_1..3 : BlendTree animation + TimeScale (paramètre « time_scale/scale »,
##                 réglé sur la vitesse d'attaque de l'arme)
## Transitions entre tous les états (fondu court) ; le code choisit l'état avec
## travel() (fondu) ou start() (immédiat, pour relancer une action).

const OUTPUT := "res://resources/animation/player_animation_tree.tres"
const SIMPLE_STATES := [&"jump", &"fall", &"roll", &"cast", &"hurt", &"death"]
const ATTACK_STATES := [&"attack_1", &"attack_2", &"attack_3"]
const CROSSFADE := 0.12


func _initialize() -> void:
	var machine := AnimationNodeStateMachine.new()
	var position := Vector2.ZERO

	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = 10.0
	for point: Array in [[&"idle", 0.0], [&"walk", 5.0], [&"run", 9.0]]:
		locomotion.add_blend_point(_animation(point[0]), point[1], -1, point[0])
	machine.add_node(&"locomotion", locomotion, position)

	for state: StringName in SIMPLE_STATES:
		position += Vector2(160, 0)
		machine.add_node(state, _animation(state), position)

	var roll_back := _animation(&"roll")
	roll_back.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD
	machine.add_node(&"roll_back", roll_back, Vector2(160, 120))

	for i in ATTACK_STATES.size():
		var tree := AnimationNodeBlendTree.new()
		tree.add_node(&"animation", _animation(ATTACK_STATES[i]), Vector2(0, 0))
		tree.add_node(&"time_scale", AnimationNodeTimeScale.new(), Vector2(200, 0))
		tree.connect_node(&"time_scale", 0, &"animation")
		tree.connect_node(&"output", 0, &"time_scale")
		machine.add_node(ATTACK_STATES[i], tree, Vector2(320 + 160 * i, 240))

	# Démarrage automatique sur la locomotion, puis transitions entre tous les états.
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	machine.add_transition(&"Start", &"locomotion", start)
	var states: Array[StringName] = [&"locomotion", &"roll_back"]
	states.append_array(SIMPLE_STATES)
	states.append_array(ATTACK_STATES)
	for from_state in states:
		for to_state in states:
			if from_state != to_state:
				var transition := AnimationNodeStateMachineTransition.new()
				transition.xfade_time = CROSSFADE
				machine.add_transition(from_state, to_state, transition)

	var error := ResourceSaver.save(machine, OUTPUT)
	print("AnimationTree du joueur : ", OUTPUT, " → ", error_string(error))
	quit(0 if error == OK else 1)


func _animation(animation_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = animation_name
	return node
