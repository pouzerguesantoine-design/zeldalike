class_name PlayerCamera
extends Node3D
## Caméra orbitale à la 3e personne : CameraPivot (ce nœud) → SpringArm3D → Camera3D.
## Le pivot suit le joueur (top_level) et porte le lacet (yaw) et le tangage (pitch).
## En lock-on, la caméra s'aligne sur l'axe joueur → cible.

@export_group("Suivi")
## Point visé, relatif aux pieds du joueur.
@export var follow_offset: Vector3 = Vector3(0.0, 1.4, 0.0)
@export var follow_smoothing: float = 12.0

@export_group("Souris")
@export var mouse_sensitivity: float = 0.0025
@export var invert_y: bool = false
@export_range(-89.0, 0.0) var min_pitch_degrees: float = -65.0
@export_range(-89.0, 89.0) var max_pitch_degrees: float = 25.0
@export var default_pitch_degrees: float = -20.0
@export var rotation_smoothing: float = 18.0
@export var capture_mouse_on_start: bool = true

@export_group("Lock-on")
@export var lock_on_pitch_degrees: float = -18.0
@export var lock_on_smoothing: float = 8.0

@export_group("Tremblement")
## Décalage maximal de la caméra au plus fort du tremblement (m).
@export var shake_max_offset: float = 0.18
## Vitesse à laquelle le tremblement s'éteint (par seconde).
@export var shake_decay: float = 4.0

## Orientation visée ; la rotation réelle la rattrape avec lissage.
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
## Intensité courante du tremblement (0 à 1).
var _trauma: float = 0.0
## Vrai quand la souris est libérée (menu ouvert…), jusqu'à sa recapture.
var _mouse_released: bool = false
var _menu_open: bool = false
## Image physique du clic de recapture (ce clic ne doit pas attaquer).
var _recapture_frame: int = -10

@onready var player: Player = get_parent() as Player
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	top_level = true
	EventBus.game_menu_toggled.connect(_on_game_menu_toggled)
	spring_arm.add_excluded_object(player.get_rid())
	# Les enfants sont prêts avant le parent : attendre les @onready du joueur.
	if not player.is_node_ready():
		await player.ready
	snap_to(player.model.global_rotation.y, deg_to_rad(default_pitch_degrees))
	if capture_mouse_on_start:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if player.lock_on.has_target():
			return  # en lock-on, la caméra est pilotée par la cible
		var motion := event as InputEventMouseMotion
		var y_sign := -1.0 if invert_y else 1.0
		_target_yaw -= motion.relative.x * mouse_sensitivity
		_target_pitch -= motion.relative.y * mouse_sensitivity * y_sign
		_target_pitch = clampf(_target_pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	elif event is InputEventMouseButton and event.is_pressed() and not _menu_open \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		# La souris a été libérée (fenêtre quittée…) : un clic la recapture, sans attaquer.
		_capture_mouse()
		get_viewport().set_input_as_handled()


## Menus (inventaire, pause, mort) : souris libre pendant le menu, recapturée ensuite.
func _on_game_menu_toggled(is_open: bool) -> void:
	_menu_open = is_open
	if is_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mouse_released = true
	else:
		_capture_mouse()


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_released = false
	# Le clic qui ferme un menu ou recapture la souris ne doit pas déclencher d'attaque.
	_recapture_frame = Engine.get_physics_frames()


func _process(delta: float) -> void:
	# Tremblement : décalage aléatoire proportionnel au carré de l'intensité.
	if _trauma <= 0.0:
		return
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	var strength := _trauma * _trauma * shake_max_offset
	camera.h_offset = randf_range(-1.0, 1.0) * strength
	camera.v_offset = randf_range(-1.0, 1.0) * strength


func _physics_process(delta: float) -> void:
	var smoothing := rotation_smoothing
	if player.lock_on.has_target():
		var to_target := player.lock_on.get_target_point() - player.global_position
		if Vector2(to_target.x, to_target.z).length_squared() > 0.01:
			_target_yaw = atan2(-to_target.x, -to_target.z)
		_target_pitch = deg_to_rad(lock_on_pitch_degrees)
		smoothing = lock_on_smoothing

	var desired_position := player.global_position + follow_offset
	global_position = global_position.lerp(desired_position, 1.0 - exp(-follow_smoothing * delta))
	var weight := 1.0 - exp(-smoothing * delta)
	rotation.y = lerp_angle(rotation.y, _target_yaw, weight)
	rotation.x = lerpf(rotation.x, _target_pitch, weight)


## Lacet actuel de la caméra : sert de référence aux déplacements du joueur.
func get_yaw() -> float:
	return rotation.y


## Direction « avant » de la caméra, à plat.
func get_flat_forward() -> Vector3:
	return Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))


## Ajoute du tremblement (0 à 1, cumulable).
func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func is_shaking() -> bool:
	return _trauma > 0.0


## Les clics servent au combat sauf souris libérée ou clic de recapture.
func accepts_combat_clicks() -> bool:
	return not _mouse_released and Engine.get_physics_frames() > _recapture_frame + 1


## Replace doucement la caméra derrière le joueur (Tab sans cible, comme le Z-targeting).
func recenter_behind_player() -> void:
	_target_yaw = player.model.global_rotation.y
	_target_pitch = deg_to_rad(default_pitch_degrees)


## Place immédiatement la caméra (démarrage, réapparition…).
func snap_to(yaw: float, pitch: float) -> void:
	_target_yaw = yaw
	_target_pitch = pitch
	rotation = Vector3(pitch, yaw, 0.0)
	global_position = player.global_position + follow_offset
	reset_physics_interpolation()
