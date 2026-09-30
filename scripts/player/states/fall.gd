extends PlayerState
## Chute. Un saut reste possible pendant le coyote time (juste après un rebord) ;
## un appui juste avant l'atterrissage est gardé en mémoire (buffer).

var _air_speed: float


func enter(msg: Dictionary) -> void:
	_air_speed = msg.get("air_speed", player.get_air_speed())
	player.play_body_animation(&"fall")


func physics_update(delta: float) -> void:
	if player.try_consume_jump():
		transition_to(&"Jump")
		return
	air_move(_air_speed, delta)
	if player.is_on_floor():
		transition_to(ground_state_from_input())
