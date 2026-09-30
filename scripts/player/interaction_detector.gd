class_name InteractionDetector
extends Area3D
## Détecte l'Interactable le plus proche DEVANT le joueur (zone placée devant le modèle,
## masque 7). Annonce les changements via EventBus.interaction_target_changed (le message
## « Ouvrir [E] » s'y abonne). Le joueur appelle try_interact() quand E est pressé.

## Au-delà de cet angle par rapport à l'avant du personnage, un objet est ignoré.
@export_range(0.0, 180.0) var max_angle_degrees: float = 75.0

var current: Interactable

@onready var player: Player = owner as Player


func _ready() -> void:
	monitoring = true
	monitorable = false


func _physics_process(_delta: float) -> void:
	var best: Interactable = null
	if not player.health.is_dead():
		var best_score := INF
		var forward := player.get_forward()
		for area in get_overlapping_areas():
			var candidate := area as Interactable
			if candidate == null or not candidate.available:
				continue
			var offset := candidate.global_position - player.global_position
			offset.y = 0.0
			if offset.length() > 0.3 and rad_to_deg(forward.angle_to(offset)) > max_angle_degrees:
				continue
			# Le plus proche, avec une petite préférence pour ce qui est bien en face.
			var score := offset.length() * (1.0 + 0.5 * (1.0 - forward.dot(offset.normalized())))
			if score < best_score:
				best_score = score
				best = candidate
	if best != current:
		current = best
		EventBus.interaction_target_changed.emit(current)


## Active l'objet ciblé. Renvoie true si une interaction a eu lieu.
func try_interact() -> bool:
	if current == null or not current.available:
		return false
	current.interact(player)
	return true
