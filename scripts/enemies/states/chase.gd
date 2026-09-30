extends EnemyState
## Poursuite du joueur par la navigation. Attaque dès qu'il est à portée (et que la
## recharge est finie). Abandonne → Return s'il est hors de vue depuis `lose_sight_time`
## secondes ou si l'ennemi s'est trop éloigné de son point d'apparition.

var _time_out_of_sight: float = 0.0
## Dernière position connue du joueur (on y va quand on le perd de vue).
var _last_known_position: Vector3


func enter(_msg: Dictionary) -> void:
	_time_out_of_sight = 0.0
	var player := enemy.get_player()
	_last_known_position = player.global_position if player else enemy.global_position


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	var player := enemy.get_player()
	if player == null or player.health.is_dead():
		transition_to(&"Return")
		return

	if enemy.can_see_player():
		_time_out_of_sight = 0.0
		_last_known_position = player.global_position
	else:
		_time_out_of_sight += delta

	var too_far_from_home := enemy.global_position.distance_to(enemy.spawn_position) > enemy.leash_distance
	if _time_out_of_sight > enemy.lose_sight_time or too_far_from_home:
		transition_to(&"Return")
		return

	var distance := enemy.distance_to_player()
	if distance <= enemy.attack_range and _time_out_of_sight == 0.0:
		enemy.face_player(delta)
		enemy.stop_moving(delta)
		enemy.play_animation(&"idle")
		if enemy.attack_cooldown_left <= 0.0 and enemy.is_on_floor():
			transition_to(&"Attack")
		return

	enemy.navigate_to(_last_known_position, enemy.get_chase_speed(), delta)
	enemy.play_animation(&"walk")
