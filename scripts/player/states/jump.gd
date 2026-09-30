extends PlayerState
## Montée du saut. Relâcher Espace tôt raccourcit le saut.

var _air_speed: float


func enter(_msg: Dictionary) -> void:
	player.velocity.y = player.jump_velocity
	_air_speed = player.get_air_speed()


func physics_update(delta: float) -> void:
	if Input.is_action_just_released("jump") and player.velocity.y > 0.0:
		player.velocity.y *= player.jump_cut_ratio
	air_move(_air_speed, delta)
	if player.velocity.y <= 0.0:
		transition_to(&"Fall", {"air_speed": _air_speed})
