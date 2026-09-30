class_name Projectile
extends Area3D
## Projectile (calque 8 « projectiles », masque 1 « world » pour exploser contre le décor).
## Il porte une Hitbox enfant qui touche les Hurtbox. S'il a une cible, il s'oriente
## progressivement vers elle (tête chercheuse douce).

var speed: float = 14.0
var homing_turn_speed: float = 5.0
var lifetime: float = 2.5
var direction: Vector3 = Vector3.FORWARD
var target: Node3D
var damage_info: DamageInfo

@onready var hitbox: Hitbox = $Hitbox


## À appeler avant add_child.
func setup(info: DamageInfo, spell: SpellData, start_direction: Vector3, homing_target: Node3D) -> void:
	speed = spell.projectile_speed
	homing_turn_speed = spell.homing_turn_speed
	lifetime = spell.lifetime
	direction = start_direction.normalized()
	target = homing_target
	damage_info = info


func _ready() -> void:
	hitbox.damage_info = damage_info
	hitbox.active = true
	hitbox.hit_landed.connect(func(_hurtbox: Hurtbox, _info: DamageInfo) -> void: _explode())
	body_entered.connect(func(_body: Node3D) -> void: _explode())


func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		var wanted := (_aim_point() - global_position).normalized()
		var angle := direction.angle_to(wanted)
		if angle > 0.001:
			direction = direction.slerp(wanted, minf(1.0, homing_turn_speed * delta / angle))
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_explode()


## Point visé : la Hurtbox de la cible si elle en a une, sinon 1 m au-dessus de ses pieds.
func _aim_point() -> Vector3:
	var hurtbox := target.get_node_or_null(^"Hurtbox") as Node3D
	return hurtbox.global_position if hurtbox else target.global_position + Vector3.UP


func _explode() -> void:
	# Les particules d'impact arriveront au jalon 8.
	set_physics_process(false)
	hitbox.active = false
	queue_free()
