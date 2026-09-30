class_name FloatingText
extends Label3D
## Texte flottant 3D (billboard) : monte puis s'efface. Sert aux messages de ramassage
## (« +1 Potion »), aux portes (« Il faut une clé ! »)…

const SCENE_PATH := "res://scene/ui/floating_text.tscn"

@export var rise_height: float = 0.9
@export var duration: float = 1.4


## Crée un texte flottant dans la scène courante, à `position`.
static func spawn(tree: SceneTree, message: String, position: Vector3, color: Color = Color.WHITE) -> FloatingText:
	var label := (load(SCENE_PATH) as PackedScene).instantiate() as FloatingText
	label.text = message
	label.modulate = color
	var parent := tree.current_scene if tree.current_scene else tree.root
	parent.add_child(label)
	label.global_position = position
	return label


func _ready() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y + rise_height, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.35).set_delay(duration * 0.65)
	tween.tween_property(self, "outline_modulate:a", 0.0, duration * 0.35).set_delay(duration * 0.65)
	tween.chain().tween_callback(queue_free)
