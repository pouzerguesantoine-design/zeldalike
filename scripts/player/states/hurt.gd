extends PlayerState
## Coup reçu : recul à l'opposé de la source, contrôle perdu un court instant.
## L'invincibilité qui suit est gérée par le HealthComponent.

## Inclinaison du corps vers l'arrière pendant le recul (radians).
@export var tilt: float = 0.35

var _elapsed: float


func enter(msg: Dictionary) -> void:
	_elapsed = 0.0
	var away := -player.get_forward()
	var source := msg.get("source") as Node3D
	if source:
		var offset := player.global_position - source.global_position
		offset.y = 0.0
		if offset.length_squared() > 0.01:
			away = offset.normalized()
	player.velocity = away * player.hurt_knockback + Vector3.UP * 2.5
	player.visual.basis = Basis(Vector3.RIGHT, tilt)


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	player.move_horizontally(Vector3.ZERO, 0.0, delta)
	if _elapsed >= player.hurt_duration:
		transition_to(state_after_action())


func exit() -> void:
	player.visual.basis = Basis.IDENTITY
