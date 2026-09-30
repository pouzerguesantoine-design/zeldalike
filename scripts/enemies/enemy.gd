class_name Enemy
extends CharacterBody3D
## Ennemi générique (scène de base scene/enemies/enemy.tscn, héritée par slime.tscn et
## goblin.tscn). Ce script fournit les briques (perception, navigation, attaque, butin) ;
## les décisions sont prises par les états (scripts/enemies/states/) :
## Patrol → Chase → Attack, Return (retour au point d'apparition), Hurt, Dead.

const PICKUP_SCENE := preload("res://scene/items/pickup.tscn")

@export var stats: EnemyStats
@export var loot_table: LootTable
## Points de patrouille (dans l'ordre, en boucle). Vide : errance autour du point d'apparition.
@export var patrol_points: Array[Marker3D] = []

@export_group("Perception")
## Rayon de la zone de détection (m).
@export var detection_range: float = 9.0
## Demi-angle du champ de vision (degrés).
@export_range(0.0, 180.0) var view_half_angle: float = 70.0
## En dessous de cette distance, le joueur est détecté même dans le dos.
@export var close_detection_range: float = 2.5
## Hauteur des yeux (pour la ligne de vue).
@export var eye_height: float = 1.0

@export_group("Poursuite")
## Délai hors de vue avant d'abandonner la poursuite (secondes).
@export var lose_sight_time: float = 3.0
## Distance maximale au point d'apparition avant d'abandonner.
@export var leash_distance: float = 20.0

@export_group("Attaque")
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.2

@export_group("Patrouille")
@export var wander_radius: float = 5.0
@export_range(0.0, 1.0) var patrol_speed_factor: float = 0.45
@export var patrol_wait_time: float = 1.5

@export_group("Déplacement")
@export var acceleration: float = 20.0
@export var rotation_speed: float = 8.0
## Déplacement par petits bonds (Slime) au lieu de marcher.
@export var hop_movement: bool = false
@export var hop_velocity: float = 4.0
@export var hop_interval: float = 0.35
## Élan donné par _anim_lunge() pendant l'attaque (0 = pas de bond).
@export var lunge_speed: float = 0.0
@export var lunge_up_velocity: float = 0.0

@export_group("Réactions")
@export var hurt_duration: float = 0.35
@export var despawn_delay: float = 1.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_position: Vector3
var attack_cooldown_left: float = 0.0
## Vrai à partir du moment où l'attaque est lancée (fin de la télégraphie) : l'ennemi
## ne se retourne plus vers le joueur.
var attack_committed: bool = false

var _player_in_detection_area: bool = false
var _hop_cooldown_left: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var model: Node3D = $Model
@onready var visual: Node3D = $Model/Visual
@onready var telegraph: Node3D = $Model/Visual/Telegraph
@onready var attack_hitbox: Hitbox = $Model/AttackHitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: HealthComponent = $HealthComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var detection_area: Area3D = $DetectionArea
@onready var sight_ray: RayCast3D = $SightRay
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var state_machine: StateMachine = $StateMachine
@onready var health_bar: EnemyHealthBar = $HealthBar


func _ready() -> void:
	_rng.randomize()
	spawn_position = global_position
	health.set_max_hp(stats.max_hp, true)
	hurtbox.defense = stats.defense
	hurtbox.resistances = stats.resistances
	health_bar.setup(health, self)
	(detection_area.get_node(^"CollisionShape3D").get(&"shape") as SphereShape3D).radius = detection_range
	detection_area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player: _player_in_detection_area = true)
	detection_area.body_exited.connect(func(body: Node3D) -> void:
		if body is Player: _player_in_detection_area = false)
	health.damaged.connect(_on_damaged)
	health.died.connect(func() -> void: state_machine.transition_to(&"Dead"))
	hurtbox.hit_received.connect(_on_hit_received)
	telegraph.visible = false


func _physics_process(delta: float) -> void:
	attack_cooldown_left = maxf(attack_cooldown_left - delta, 0.0)
	_hop_cooldown_left = maxf(_hop_cooldown_left - delta, 0.0)
	state_machine.physics_update(delta)
	move_and_slide()


# --- Perception ------------------------------------------------------------------

func get_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func distance_to_player() -> float:
	var player := get_player()
	return global_position.distance_to(player.global_position) if player else INF


## Le joueur est-il repéré ? Il faut qu'il soit dans la zone de détection, vivant, dans le
## champ de vision (sauf s'il est tout près) et que la ligne de vue ne soit pas coupée.
func can_see_player() -> bool:
	var player := get_player()
	if player == null or player.health.is_dead() or not _player_in_detection_area:
		return false
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > close_detection_range \
			and rad_to_deg(get_forward().angle_to(to_player)) > view_half_angle:
		return false
	return has_line_of_sight_to(player.global_position + Vector3.UP * 1.0)


func has_line_of_sight_to(point: Vector3) -> bool:
	sight_ray.global_position = global_position + Vector3.UP * eye_height
	sight_ray.target_position = sight_ray.to_local(point)
	sight_ray.force_raycast_update()
	return not sight_ray.is_colliding()


# --- Déplacement -------------------------------------------------------------------

func get_forward() -> Vector3:
	var forward := -model.global_basis.z
	forward.y = 0.0
	return forward.normalized()


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func get_chase_speed() -> float:
	return stats.speed


func get_patrol_speed() -> float:
	return stats.speed * patrol_speed_factor


## Se dirige vers `target` en suivant le maillage de navigation.
func navigate_to(target: Vector3, speed: float, delta: float) -> void:
	if nav_agent.target_position.distance_squared_to(target) > 0.25:
		nav_agent.target_position = target
	var next_point := target
	# Tant que la carte de navigation n'est pas prête, on va tout droit.
	if NavigationServer3D.map_get_iteration_id(nav_agent.get_navigation_map()) > 0:
		next_point = nav_agent.get_next_path_position()
	var direction := next_point - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0025:
		# Point du chemin à la verticale (ou chemin fini) : on vise directement la cible.
		direction = target - global_position
		direction.y = 0.0
	move_in_direction(direction.normalized() if direction.length_squared() > 0.0025 else Vector3.ZERO, speed, delta)


## Avance dans `direction` (marche, ou petits bonds pour le Slime) et se tourne vers elle.
func move_in_direction(direction: Vector3, speed: float, delta: float) -> void:
	if direction.is_zero_approx():
		stop_moving(delta)
		return
	face_direction(direction, delta)
	if hop_movement:
		if is_on_floor():
			if _hop_cooldown_left <= 0.0:
				velocity = direction * speed + Vector3.UP * hop_velocity
				_hop_cooldown_left = hop_interval
			else:
				stop_moving(delta)
		return
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2(direction.x, direction.z) * speed, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y


## Freine au sol (en l'air, l'élan est conservé).
func stop_moving(delta: float) -> void:
	if not is_on_floor():
		return
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y


func face_direction(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 1.0 - exp(-rotation_speed * delta))


func face_player(delta: float) -> void:
	var player := get_player()
	if player:
		face_direction(player.global_position - global_position, delta)


## Point au hasard sur le maillage de navigation, autour du point d'apparition.
func random_wander_point() -> Vector3:
	var angle := _rng.randf() * TAU
	var distance := sqrt(_rng.randf()) * wander_radius
	var point := spawn_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
	var map := nav_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		point = NavigationServer3D.map_get_closest_point(map, point)
	return point


func play_animation(animation: StringName) -> void:
	if anim.current_animation != animation and anim.has_animation(animation):
		anim.play(animation)


# --- Combat --------------------------------------------------------------------

## Prépare le coup de l'ennemi (formule commune : base + Force, sans combo ni critique).
func prepare_attack() -> void:
	var info := DamageInfo.new()
	info.raw_amount = DamageCalculator.compute_offense(stats.attack_damage, 1.0, stats.force, 1.0, false)
	info.knockback = stats.attack_knockback
	info.source = self
	attack_hitbox.damage_info = info
	attack_committed = false


## Piste de méthode de l'animation « attack » : fin de la télégraphie, le coup part.
func _anim_commit_attack() -> void:
	attack_committed = true
	if lunge_speed > 0.0:
		var forward := get_forward()
		velocity = forward * lunge_speed + Vector3.UP * lunge_up_velocity


## Remet l'attaque au repos (fin, ou interruption par un coup reçu).
func reset_attack() -> void:
	attack_hitbox.active = false
	telegraph.visible = false
	attack_committed = false


func _on_damaged(_amount: int, _source: Node) -> void:
	if not health.is_dead():
		state_machine.transition_to(&"Hurt")


## Recul à l'opposé de l'attaquant.
func _on_hit_received(info: DamageInfo) -> void:
	var away := -get_forward()
	if info.source:
		away = global_position - info.source.global_position
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.001 else -get_forward()
	velocity = away * info.knockback + Vector3.UP * 2.0


# --- Mort et butin -------------------------------------------------------------

## Désactive les collisions, retire l'ennemi des cibles verrouillables et des groupes.
func disable_collisions() -> void:
	remove_from_group(&"lockable")
	remove_from_group(&"enemies")
	collision_layer = 0
	hurtbox.set_deferred(&"monitorable", false)
	attack_hitbox.active = false
	detection_area.set_deferred(&"monitoring", false)


## Fait jaillir le butin tiré de la LootTable autour de l'ennemi.
func drop_loot() -> Array[Pickup]:
	var pickups: Array[Pickup] = []
	if loot_table == null:
		return pickups
	for drop in loot_table.roll(_rng):
		var pickup := PICKUP_SCENE.instantiate() as Pickup
		pickup.item = drop["item"]
		pickup.quantity = drop["quantity"]
		get_parent().add_child(pickup)
		pickup.global_position = global_position + Vector3.UP * 0.5
		var offset := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).limit_length(1.2)
		pickup.pop_to(global_position + offset)
		pickups.append(pickup)
	return pickups
