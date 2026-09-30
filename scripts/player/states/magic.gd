extends PlayerState
## Magie PROVISOIRE (jalon 1) : une orbe apparaît dans la main, sans projectile.
## Remplacée au jalon 3 par la boule d'énergie (projectile Area3D).

@export var duration: float = 0.4

var _elapsed: float


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	player.magic_visual.visible = true


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	player.move_horizontally(Vector3.ZERO, 0.0, delta)
	player.update_facing(Vector3.ZERO, delta)
	if _elapsed >= duration:
		transition_to(state_after_action())


func exit() -> void:
	player.magic_visual.visible = false
