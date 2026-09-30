extends PlayerState
## Roulade : déplacement rapide avec invincibilité (i-frames) et coût d'endurance
## (payé avant d'entrer, dans PlayerState.try_ground_actions).
## Direction : celle des touches, sinon un bond en arrière.

var _direction: Vector3
var _roll_axis: Vector3
var _elapsed: float


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	_direction = player.get_move_direction()
	if _direction.is_zero_approx():
		_direction = -player.get_forward()
	else:
		_direction = _direction.normalized()
		if not player.lock_on.has_target():
			player.face_direction_instant(_direction)
	player.health.set_invincible(player.dodge_invincibility)
	# Axe de rotation du corps : perpendiculaire à la direction, dans le repère du modèle.
	var local_direction := player.model.global_basis.inverse() * _direction
	_roll_axis = Vector3.UP.cross(local_direction).normalized()


func physics_update(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / player.dodge_duration, 0.0, 1.0)
	# Départ explosif puis ralentissement.
	var speed := player.dodge_speed * (1.0 - 0.5 * progress)
	player.velocity.x = _direction.x * speed
	player.velocity.z = _direction.z * speed
	player.apply_gravity(delta)
	# Animation provisoire : le corps fait un tour complet (remplacée au jalon 5).
	player.visual.basis = Basis(_roll_axis, TAU * progress)
	if progress >= 1.0:
		transition_to(state_after_action())


func exit() -> void:
	player.visual.basis = Basis.IDENTITY
