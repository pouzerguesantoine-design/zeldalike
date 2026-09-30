extends CharacterBody3D
## Mannequin d'entraînement : encaisse les coups (chiffres de dégâts, flash blanc, recul,
## oscillation) sans jamais mourir. Sert à tester les armes et la magie.

## Freinage du recul (m/s par seconde).
@export var knockback_friction: float = 14.0
## Inclinaison maximale quand il est frappé (radians).
@export var wobble_angle: float = 0.4
@export var wobble_duration: float = 0.7

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _wobble_tween: Tween

@onready var visual: Node3D = $Visual
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	hurtbox.hit_received.connect(_on_hit_received)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, knockback_friction * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	move_and_slide()


func _on_hit_received(info: DamageInfo) -> void:
	# Vie infinie : on remet la jauge au maximum après chaque coup.
	health.heal(health.max_hp)
	var away := Vector3.FORWARD
	if info.source:
		away = global_position - info.source.global_position
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.001 else Vector3.FORWARD
	velocity.x = away.x * info.knockback
	velocity.z = away.z * info.knockback
	_wobble(away)


## Le haut du mannequin part dans la direction du coup puis revient en oscillant.
func _wobble(direction: Vector3) -> void:
	var axis := Vector3.UP.cross(direction).normalized()
	if _wobble_tween:
		_wobble_tween.kill()
	_wobble_tween = create_tween()
	_wobble_tween.tween_method(func(angle: float) -> void: visual.basis = Basis(axis, angle),
		wobble_angle, 0.0, wobble_duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
