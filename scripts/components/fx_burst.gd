class_name FxBurst
extends Node3D
## Effet ponctuel (scene/fx/*.tscn) : déclenche toutes ses particules CPUParticles3D
## (one_shot) puis se détruit. `FxBurst.spawn(self, SCENE, point, couleur)`.

## Couleur imposée aux particules (alpha 0 = couleurs de la scène).
var tint: Color = Color(0, 0, 0, 0)


static func spawn(context: Node, scene: PackedScene, at: Vector3, color: Color = Color(0, 0, 0, 0)) -> FxBurst:
	if not context.is_inside_tree():
		return null
	var fx := scene.instantiate() as FxBurst
	fx.tint = color
	var tree := context.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene else tree.root
	parent.add_child(fx)
	fx.global_position = at
	return fx


func _ready() -> void:
	var longest := 0.0
	for node in find_children("*", "CPUParticles3D", true, false):
		var particles := node as CPUParticles3D
		if tint.a > 0.0:
			particles.color = tint
		particles.emitting = true
		longest = maxf(longest, particles.lifetime)
	get_tree().create_timer(longest + 0.3, false).timeout.connect(queue_free)
