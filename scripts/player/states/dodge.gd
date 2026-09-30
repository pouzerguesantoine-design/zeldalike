extends PlayerState
## Roulade : déplacement rapide avec invincibilité (i-frames) et coût d'endurance
## (payé avant d'entrer, dans PlayerState.try_ground_actions).
## Direction : celle des touches (animation « roll »), sinon un bond en arrière
## (état « roll_back » : la même animation jouée à l'envers).

var _direction: Vector3
var _elapsed: float


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	_direction = player.get_move_direction()
	var backwards := _direction.is_zero_approx()
	if backwards:
		_direction = -player.get_forward()
	else:
		_direction = _direction.normalized()
		if not player.lock_on.has_target():
			player.face_direction_instant(_direction)
	# En lock-on, on roule sur le côté sans quitter la cible des yeux : la roulade avant
	# n'est jouée à l'envers que si l'on s'éloigne d'elle.
	if player.lock_on.has_target():
		backwards = _direction.dot(player.get_forward()) < -0.3
	player.health.set_invincible(player.dodge_invincibility)
	player.play_body_animation(&"roll_back" if backwards else &"roll", true)


func physics_update(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / player.dodge_duration, 0.0, 1.0)
	# Départ explosif puis ralentissement.
	var speed := player.dodge_speed * (1.0 - 0.5 * progress)
	player.velocity.x = _direction.x * speed
	player.velocity.z = _direction.z * speed
	player.apply_gravity(delta)
	if progress >= 1.0:
		transition_to(state_after_action())
