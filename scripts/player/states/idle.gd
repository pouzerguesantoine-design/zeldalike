extends PlayerState
## Immobile au sol.


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_horizontally(Vector3.ZERO, 0.0, delta)
	player.update_facing(Vector3.ZERO, delta)
	player.animate_locomotion()
	if try_ground_actions():
		return
	var next := ground_state_from_input()
	if next != name:
		transition_to(next)
