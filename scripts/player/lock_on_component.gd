class_name LockOnComponent
extends Node
## Verrouillage de cible (Z-targeting). Tab / clic molette : verrouille la cible la
## plus proche dans un cône devant la caméra, ou relâche. Molette : cible suivante /
## précédente. Relâché automatiquement si la cible disparaît, sort du groupe
## (ex. ennemi mort) ou s'éloigne trop.
##
## Une cible est un Node3D du groupe `target_group`. S'il possède un enfant Marker3D
## nommé « LockOnPoint », le marqueur et la caméra visent ce point.

signal target_changed(target: Node3D)

@export var target_group: StringName = &"lockable"
@export var max_range: float = 15.0
@export_range(0.0, 180.0) var cone_half_angle_degrees: float = 50.0
## Distance au-delà de laquelle une cible verrouillée est relâchée.
@export var break_distance: float = 20.0
## Hauteur visée quand la cible n'a pas de LockOnPoint.
@export var default_point_height: float = 1.0
## Calques qui bloquent la ligne de vue (1 = world).
@export_flags_3d_physics var line_of_sight_mask: int = 1
@export var marker_scene: PackedScene

var target: Node3D
var _marker: Node3D
var _marker_time: float = 0.0

@onready var player: Player = get_parent() as Player


func _ready() -> void:
	if marker_scene:
		_marker = marker_scene.instantiate() as Node3D
		add_child(_marker)
		_marker.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("lock_on"):
		toggle()
	elif has_target() and event.is_action_pressed("target_next"):
		cycle_target(1)
	elif has_target() and event.is_action_pressed("target_prev"):
		cycle_target(-1)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	if not _is_still_valid(target):
		release()
		return
	# Le marqueur flotte et tourne au-dessus de la cible.
	_marker_time += delta
	_marker.global_position = get_target_point() + Vector3.UP * (0.1 * sin(_marker_time * 4.0))
	_marker.rotation.y = _marker_time * 3.0


func has_target() -> bool:
	return target != null


func get_target_point() -> Vector3:
	return _point_of(target)


func toggle() -> void:
	if has_target():
		release()
		return
	if player.health.is_dead():
		return
	var candidates := _find_candidates()
	if candidates.is_empty():
		player.camera_pivot.recenter_behind_player()
		return
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _distance_to(a) < _distance_to(b))
	_set_target(candidates[0])


## Passe à la cible suivante (+1, vers la droite) ou précédente (-1).
func cycle_target(step: int) -> void:
	var candidates := _find_candidates()
	if not candidates.has(target):
		candidates.append(target)
	if candidates.size() < 2:
		return
	# Tri de gauche à droite selon l'angle vu depuis la caméra.
	var forward := player.camera_pivot.get_flat_forward()
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _signed_angle(forward, a) > _signed_angle(forward, b))
	var index := candidates.find(target)
	_set_target(candidates[posmod(index + step, candidates.size())])


func release() -> void:
	_set_target(null)


func _set_target(new_target: Node3D) -> void:
	if new_target == target:
		return
	target = new_target
	_marker.visible = target != null
	if target:
		_marker.global_position = get_target_point()
		_marker.reset_physics_interpolation()
	target_changed.emit(target)
	EventBus.lock_on_target_changed.emit(target)


func _find_candidates() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var forward := player.camera_pivot.get_flat_forward()
	for node in get_tree().get_nodes_in_group(target_group):
		var candidate := node as Node3D
		if candidate == null or not candidate.is_visible_in_tree():
			continue
		var distance := _distance_to(candidate)
		if distance > max_range or distance < 0.01:
			continue
		var to_candidate := candidate.global_position - player.global_position
		to_candidate.y = 0.0
		if rad_to_deg(forward.angle_to(to_candidate)) > cone_half_angle_degrees:
			continue
		if not _has_line_of_sight(candidate):
			continue
		result.append(candidate)
	return result


func _is_still_valid(candidate: Node3D) -> bool:
	return is_instance_valid(candidate) \
		and candidate.is_inside_tree() \
		and candidate.is_in_group(target_group) \
		and _distance_to(candidate) <= break_distance \
		and not player.health.is_dead()


func _has_line_of_sight(candidate: Node3D) -> bool:
	var eye := player.global_position + Vector3.UP * 1.5
	var query := PhysicsRayQueryParameters3D.create(eye, _point_of(candidate), line_of_sight_mask)
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _point_of(candidate: Node3D) -> Vector3:
	var point := candidate.get_node_or_null(^"LockOnPoint") as Node3D
	if point:
		return point.global_position
	return candidate.global_position + Vector3.UP * default_point_height


func _distance_to(candidate: Node3D) -> float:
	return player.global_position.distance_to(candidate.global_position)


func _signed_angle(forward: Vector3, candidate: Node3D) -> float:
	var to_candidate := candidate.global_position - player.global_position
	to_candidate.y = 0.0
	return forward.signed_angle_to(to_candidate, Vector3.UP)
