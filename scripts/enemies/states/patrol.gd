extends EnemyState
## Patrouille : suit les points de patrouille en boucle (avec une pause à chacun), ou erre
## au hasard autour du point d'apparition s'il n'y en a pas. Repère le joueur → Chase.

## Distance à laquelle un point de patrouille est considéré comme atteint.
@export var arrival_distance: float = 0.6

var _point_index: int = 0
var _target: Vector3
var _wait_left: float = 0.0


func enter(_msg: Dictionary) -> void:
	_wait_left = 0.0
	_target = _next_target()


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	if try_start_chase():
		return
	if _wait_left > 0.0:
		_wait_left -= delta
		enemy.stop_moving(delta)
		enemy.play_animation(&"idle")
		if _wait_left <= 0.0:
			_target = _next_target()
		return
	var to_target := _target - enemy.global_position
	to_target.y = 0.0
	if to_target.length() <= arrival_distance:
		_wait_left = enemy.patrol_wait_time
		return
	enemy.navigate_to(_target, enemy.get_patrol_speed(), delta)
	enemy.play_animation(&"walk")


func _next_target() -> Vector3:
	if enemy.patrol_points.is_empty():
		return enemy.random_wander_point()
	var point := enemy.patrol_points[_point_index % enemy.patrol_points.size()]
	_point_index += 1
	return point.global_position
