extends PlayerState
## Marche (plus lente quand l'endurance est épuisée). En lock-on : strafe face à la cible.


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	var direction := player.get_move_direction()
	var speed := player.get_exhausted_speed() if player.stamina.is_exhausted else player.get_walk_speed()
	player.move_horizontally(direction, speed, delta)
	player.update_facing(direction, delta)
	if try_ground_actions():
		return
	var next := ground_state_from_input()
	if next != name:
		transition_to(next)
