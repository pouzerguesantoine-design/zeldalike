extends EnemyState
## Retour au point d'apparition après avoir abandonné la poursuite, puis reprise de la
## patrouille. S'il revoit le joueur en chemin (et qu'il est encore assez près de chez
## lui), il reprend la poursuite.

@export var arrival_distance: float = 0.8


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	var home_distance := enemy.global_position.distance_to(enemy.spawn_position)
	if home_distance < enemy.leash_distance * 0.5 and try_start_chase():
		return
	var to_home := enemy.spawn_position - enemy.global_position
	to_home.y = 0.0
	if to_home.length() <= arrival_distance:
		transition_to(&"Patrol")
		return
	enemy.navigate_to(enemy.spawn_position, enemy.get_chase_speed(), delta)
	enemy.play_animation(&"walk")
