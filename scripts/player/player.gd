class_name Player
extends CharacterBody3D
## Joueur. Ce script fournit les « briques » de mouvement (gravité, accélération,
## orientation, saut avec coyote time et buffer). Les décisions (quand marcher,
## sauter, rouler…) sont prises par les états de la StateMachine
## (scripts/player/states/).

@export_group("Déplacement")
@export var walk_speed: float = 5.0
@export var run_speed: float = 9.0
## Vitesse de marche quand l'endurance est épuisée.
@export var exhausted_speed: float = 2.5
@export var ground_acceleration: float = 40.0
@export var ground_deceleration: float = 50.0
@export var air_acceleration: float = 12.0
## Vitesse de rotation du modèle vers la direction visée.
@export var rotation_speed: float = 12.0

@export_group("Saut")
@export var jump_velocity: float = 7.0
## Gravité renforcée à la descente : sauts plus nerveux.
@export var fall_gravity_multiplier: float = 1.6
## Vitesse verticale conservée si on relâche Espace pendant la montée (saut court).
@export_range(0.0, 1.0) var jump_cut_ratio: float = 0.5
## Délai pendant lequel on peut encore sauter après avoir quitté un rebord.
@export var coyote_time: float = 0.12
## Un appui sur Espace juste avant d'atterrir est mémorisé pendant ce délai.
@export var jump_buffer_time: float = 0.15

@export_group("Endurance")
@export var sprint_stamina_per_second: float = 20.0
@export var dodge_stamina_cost: float = 20.0

@export_group("Roulade")
@export var dodge_speed: float = 11.0
@export var dodge_duration: float = 0.45
@export var dodge_invincibility: float = 0.35

@export_group("Dégâts reçus")
@export var hurt_knockback: float = 6.0
@export var hurt_duration: float = 0.4

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _time_since_on_floor: float = 0.0
var _jump_buffer_left: float = 0.0
var _jumped_since_on_floor: bool = false

@onready var model: Node3D = $Model
## Pivot visuel au centre du corps : on le fait tourner pour la roulade, la chute…
@onready var visual: Node3D = $Model/Visual
@onready var sword_visual: Node3D = $Model/Visual/Sword
@onready var magic_visual: Node3D = $Model/Visual/MagicOrb
@onready var camera_pivot: PlayerCamera = $CameraPivot
@onready var state_machine: StateMachine = $StateMachine
@onready var health: HealthComponent = $HealthComponent
@onready var stamina: StaminaComponent = $StaminaComponent
@onready var lock_on: LockOnComponent = $LockOnComponent


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	# Ordre volontaire : minuteries de saut → logique de l'état → déplacement.
	_update_jump_timers(delta)
	state_machine.physics_update(delta)
	move_and_slide()


# --- Entrées -----------------------------------------------------------------

func get_input_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


## Direction de déplacement dans le monde, relative à l'orientation de la caméra.
func get_move_direction() -> Vector3:
	var input := get_input_vector()
	return Basis(Vector3.UP, camera_pivot.get_yaw()) * Vector3(input.x, 0.0, input.y)


## Attaque et magie ne partent que si la souris est capturée
## (le clic qui recapture la souris ne doit pas déclencher d'attaque).
func combat_input_allowed() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


# --- Mouvement ---------------------------------------------------------------

func apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var multiplier := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
	velocity.y -= gravity * multiplier * delta


## Accélère (ou freine) la vitesse horizontale vers `direction * speed`.
func move_horizontally(direction: Vector3, speed: float, delta: float) -> void:
	var rate: float
	if not is_on_floor():
		rate = air_acceleration
	elif direction.is_zero_approx():
		rate = ground_deceleration
	else:
		rate = ground_acceleration
	var target := Vector2(direction.x, direction.z) * speed
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y


## Vitesse horizontale à conserver en l'air (garde l'élan d'un sprint).
func get_air_speed() -> float:
	return maxf(walk_speed, Vector2(velocity.x, velocity.z).length())


# --- Orientation -------------------------------------------------------------

## Direction vers laquelle regarde le modèle (à plat).
func get_forward() -> Vector3:
	var forward := -model.global_basis.z
	forward.y = 0.0
	return forward.normalized()


## Tourne progressivement le modèle vers `direction`.
func face_direction(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 1.0 - exp(-rotation_speed * delta))


func face_direction_instant(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	model.rotation.y = atan2(-direction.x, -direction.z)


## Oriente le modèle : vers la cible en lock-on (déplacement en strafe) si `strafe`,
## sinon vers la direction de déplacement.
func update_facing(move_direction: Vector3, delta: float, strafe: bool = true) -> void:
	if strafe and lock_on.has_target():
		face_direction(lock_on.get_target_point() - global_position, delta)
	else:
		face_direction(move_direction, delta)


# --- Saut (coyote time + buffer) -----------------------------------------------

func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		_time_since_on_floor = 0.0
		_jumped_since_on_floor = false
	else:
		_time_since_on_floor += delta
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = jump_buffer_time
	else:
		_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)


## Au sol, ou en l'air depuis moins de `coyote_time` sans avoir sauté.
func can_jump() -> bool:
	return is_on_floor() or (_time_since_on_floor <= coyote_time and not _jumped_since_on_floor)


## Renvoie true (et consomme la demande) si un saut demandé récemment peut partir.
func try_consume_jump() -> bool:
	if _jump_buffer_left > 0.0 and can_jump():
		_jump_buffer_left = 0.0
		_jumped_since_on_floor = true
		return true
	return false


# --- Dégâts ------------------------------------------------------------------

func _on_damaged(_amount: int, source: Node) -> void:
	if not health.is_dead():
		state_machine.transition_to(&"Hurt", {"source": source})


func _on_died() -> void:
	state_machine.transition_to(&"Dead")
