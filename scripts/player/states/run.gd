extends PlayerState
## Sprint (Maj) : consomme de l'endurance. Même en lock-on, le personnage
## regarde où il court (comme dans BotW).


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	var direction := player.get_move_direction()
	player.move_horizontally(direction, player.get_run_speed(), delta)
	player.update_facing(direction, delta, false)
	player.stamina.try_consume(player.sprint_stamina_per_second * delta)
	if try_ground_actions():
		return
	var next := ground_state_from_input()
	if next != name:
		transition_to(next)
