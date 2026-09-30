extends PlayerState
## Attaque PROVISOIRE (jalon 1) : l'épée apparaît un court instant, sans dégâts.
## Remplacée au jalon 3 par le combo en 3 coups (AnimationPlayer + Hitbox).

@export var duration: float = 0.3

var _elapsed: float


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	player.sword_visual.visible = true


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	player.move_horizontally(Vector3.ZERO, 0.0, delta)
	player.update_facing(Vector3.ZERO, delta)
	if _elapsed >= duration:
		transition_to(state_after_action())


func exit() -> void:
	player.sword_visual.visible = false
