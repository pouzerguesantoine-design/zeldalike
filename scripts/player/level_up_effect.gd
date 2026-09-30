class_name LevelUpEffect
extends Node3D
## Effet de montée de niveau : anneau doré qui s'élargit, étincelles, éclair de lumière
## et texte « NIVEAU SUPÉRIEUR ! » qui monte puis s'efface. Se détruit tout seul.

@export var duration: float = 2.0
@export var text_rise: float = 1.0
@export var ring_final_scale: float = 3.0

## Nouveau niveau affiché (à renseigner avant add_child).
var level: int = 2

@onready var label: Label3D = $Label3D
@onready var ring: MeshInstance3D = $Ring
@onready var sparkles: CPUParticles3D = $Sparkles
@onready var flash: OmniLight3D = $Flash


func _ready() -> void:
	label.text = "NIVEAU SUPÉRIEUR !\nNiveau %d" % level
	sparkles.emitting = true

	var tween := create_tween().set_parallel()
	# Texte : monte en ralentissant, puis s'efface sur la fin.
	tween.tween_property(label, "position:y", label.position.y + text_rise, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(duration - 0.5)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.5).set_delay(duration - 0.5)
	# Anneau au sol : s'élargit en devenant transparent.
	tween.tween_property(ring, "scale", Vector3.ONE * ring_final_scale, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "transparency", 1.0, 0.7)
	# Éclair de lumière bref.
	tween.tween_property(flash, "light_energy", 0.0, 0.8)
	tween.chain().tween_callback(queue_free)
