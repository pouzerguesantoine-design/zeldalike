extends CharacterBody3D
## Joueur : déplacements ZQSD / flèches, gravité, rotation fluide, attaque sur Espace.

@export var speed: float = 6.0
@export var acceleration: float = 30.0
@export var rotation_speed: float = 12.0
@export var attack_duration: float = 0.25
@export var attack_cooldown: float = 0.4
@export var attack_damage: int = 1

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_attacking: bool = false
var _cooldown_left: float = 0.0

@onready var model: Node3D = $Model
@onready var attack_area: Area3D = $Model/AttackArea
@onready var sword_mesh: MeshInstance3D = $Model/AttackArea/SwordMesh


func _ready() -> void:
	attack_area.monitoring = false
	sword_mesh.visible = false


func _physics_process(delta: float) -> void:
	# Gravité
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Déplacement dans le plan XZ (caméra fixe : "avant" = -Z)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	if is_attacking:
		direction = Vector3.ZERO  # le joueur s'arrête pendant le coup

	var target_velocity := direction * speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	# Rotation fluide vers la direction de déplacement
	if direction.length_squared() > 0.001:
		var target_angle := atan2(-direction.x, -direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)

	move_and_slide()

	# Attaque
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if Input.is_action_just_pressed("attack") and not is_attacking and _cooldown_left == 0.0:
		_attack()


func _attack() -> void:
	is_attacking = true
	_cooldown_left = attack_cooldown
	attack_area.monitoring = true
	sword_mesh.visible = true

	# Attendre une frame physique pour que l'Area3D détecte les corps
	await get_tree().physics_frame
	await get_tree().physics_frame
	for body in attack_area.get_overlapping_bodies():
		if body != self and body.has_method("take_damage"):
			body.take_damage(attack_damage)

	await get_tree().create_timer(attack_duration).timeout
	attack_area.monitoring = false
	sword_mesh.visible = false
	is_attacking = false
