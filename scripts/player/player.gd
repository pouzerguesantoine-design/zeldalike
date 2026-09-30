class_name Player
extends CharacterBody3D
## Joueur. Ce script fournit les « briques » de mouvement (gravité, accélération,
## orientation, saut avec coyote time et buffer) et de combat (préparation des coups,
## lancer de sort, retour d'impact). Les décisions (quand marcher, sauter, attaquer…)
## sont prises par les états de la StateMachine (scripts/player/states/).

const LEVEL_UP_EFFECT := preload("res://scene/player/level_up_effect.tscn")
## Pose de repos de l'arme (pointe vers le bas, devant), identique à l'animation RESET.
const WEAPON_REST_ROTATION := Vector3(-1.0, 0.0, 0.0)

@export_group("Déplacement")
## Vitesses de base, multipliées par la stat Vitesse (voir get_walk_speed()).
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

@export_group("Combat")
## Sort lancé avec le clic droit.
@export var spell: SpellData
## Durée du hit-stop quand un coup porte (secondes réelles).
@export var hit_stop_duration: float = 0.06
@export var critical_hit_stop_duration: float = 0.12
## Intensité du tremblement de caméra à l'impact (0 à 1).
@export var hit_shake: float = 0.35
@export var critical_hit_shake: float = 0.6

@export_group("Dégâts reçus")
@export var hurt_knockback: float = 6.0
@export var hurt_duration: float = 0.4

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Mis à vrai par la piste de méthode des animations d'attaque (fenêtre d'enchaînement).
var combo_window_open: bool = false
## Effet « NIVEAU SUPÉRIEUR ! » en cours d'affichage (null sinon).
var level_up_effect: LevelUpEffect

var _time_since_on_floor: float = 0.0
var _jump_buffer_left: float = 0.0
var _jumped_since_on_floor: bool = false
var _weapon_model: Node3D

@onready var model: Node3D = $Model
## Pivot visuel au centre du corps : on le fait tourner pour la roulade, la chute…
@onready var visual: Node3D = $Model/Visual
## Emplacement de l'arme en main (deviendra un BoneAttachment3D au jalon 5).
@onready var weapon_socket: Node3D = $Model/Visual/WeaponSocket
@onready var weapon_hitbox: Hitbox = $Model/WeaponHitbox
@onready var magic_visual: Node3D = $Model/Visual/MagicOrb
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var camera_pivot: PlayerCamera = $CameraPivot
@onready var state_machine: StateMachine = $StateMachine
@onready var health: HealthComponent = $HealthComponent
@onready var stamina: StaminaComponent = $StaminaComponent
@onready var mana: ManaComponent = $ManaComponent
@onready var lock_on: LockOnComponent = $LockOnComponent


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	apply_stats(true)
	equip_weapon_visual(GameState.equipped_weapon)
	GameState.stats_changed.connect(apply_stats.bind(false))
	GameState.equipment_changed.connect(equip_weapon_visual)
	GameState.saving.connect(_on_game_saving)
	GameState.loaded.connect(_on_game_loaded)
	EventBus.level_up.connect(_on_level_up)
	EventBus.damage_dealt.connect(_on_damage_dealt)


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


## Attaque et magie ne partent pas quand la souris est libérée (Échap),
## ni sur le clic qui la recapture.
func combat_input_allowed() -> bool:
	return camera_pivot.accepts_combat_clicks()


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


func get_walk_speed() -> float:
	return walk_speed * GameState.player_stats.get_move_speed_multiplier()


func get_run_speed() -> float:
	return run_speed * GameState.player_stats.get_move_speed_multiplier()


func get_exhausted_speed() -> float:
	return exhausted_speed * GameState.player_stats.get_move_speed_multiplier()


## Vitesse horizontale à conserver en l'air (garde l'élan d'un sprint).
func get_air_speed() -> float:
	return maxf(get_walk_speed(), Vector2(velocity.x, velocity.z).length())


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


# --- Armes et combat -------------------------------------------------------------

func get_weapon() -> WeaponData:
	return GameState.equipped_weapon


## Place le modèle de l'arme dans la main et règle la portée de la zone de coup.
func equip_weapon_visual(weapon: WeaponData) -> void:
	if is_instance_valid(_weapon_model):
		# Retiré tout de suite (pas seulement à la fin de l'image) pour libérer son nom.
		weapon_socket.remove_child(_weapon_model)
		_weapon_model.queue_free()
		_weapon_model = null
	if weapon == null:
		return
	if weapon.model_scene:
		_weapon_model = weapon.model_scene.instantiate() as Node3D
		weapon_socket.add_child(_weapon_model)
	# La zone de coup démarre à 0,3 m du corps et s'étend sur la portée de l'arme.
	var shape := weapon_hitbox.get_node(^"CollisionShape3D").get(&"shape") as BoxShape3D
	shape.size.z = weapon.reach
	weapon_hitbox.position.z = -(0.3 + weapon.reach / 2.0)


## Prépare le DamageInfo du coup n° `combo_index` (tirage du critique compris).
func prepare_weapon_hit(combo_index: int) -> void:
	var weapon := get_weapon()
	var info := DamageInfo.new()
	info.is_critical = randf() < weapon.critical_chance
	info.raw_amount = DamageCalculator.compute_offense(
		weapon.base_damage, weapon.damage_multiplier, GameState.player_stats.force,
		weapon.get_combo_multiplier(combo_index), info.is_critical)
	info.damage_type = weapon.damage_type
	info.knockback = weapon.knockback
	if combo_index == weapon.get_combo_length() - 1:
		info.knockback *= weapon.finisher_knockback_multiplier
	info.source = self
	weapon_hitbox.damage_info = info
	combo_window_open = false


## Remet l'arme et la magie au repos (fin ou interruption d'une attaque / d'un sort).
func reset_combat_pose() -> void:
	anim.stop()
	weapon_hitbox.active = false
	combo_window_open = false
	weapon_socket.rotation = WEAPON_REST_ROTATION
	magic_visual.visible = false
	magic_visual.scale = Vector3.ONE


## Appelé par la piste de méthode des animations attack_N.
func _anim_open_combo_window() -> void:
	combo_window_open = true


## Appelé par la piste de méthode de l'animation « cast » : la boule d'énergie part.
func _anim_release_spell() -> void:
	if spell == null or not mana.try_consume(spell.mana_cost):
		return
	var info := DamageInfo.new()
	info.raw_amount = DamageCalculator.compute_offense(
		spell.base_damage, spell.damage_multiplier, GameState.player_stats.force, 1.0, false)
	info.damage_type = spell.damage_type
	info.knockback = spell.knockback
	info.source = self
	var target := lock_on.target if lock_on.has_target() else null
	var origin := magic_visual.global_position
	var direction := get_forward()
	if target:
		direction = lock_on.get_target_point() - origin
	var projectile := spell.projectile_scene.instantiate() as Projectile
	projectile.setup(info, spell, direction, target)
	get_parent().add_child(projectile)
	projectile.global_position = origin
	projectile.reset_physics_interpolation()


## Retour d'impact quand un de nos coups porte : hit-stop + tremblement de caméra.
## (Le flash blanc et le recul sont gérés côté cible.)
func _on_damage_dealt(_target: Node, info: DamageInfo) -> void:
	if info.source != self:
		return
	HitStop.freeze(get_tree(), critical_hit_stop_duration if info.is_critical else hit_stop_duration)
	camera_pivot.shake(critical_hit_shake if info.is_critical else hit_shake)


# --- Statistiques et niveaux -------------------------------------------------

## Reporte les stats de GameState sur les composants. `refill` remet vie, endurance
## et mana au maximum.
func apply_stats(refill: bool) -> void:
	var stats := GameState.player_stats
	health.set_max_hp(stats.max_hp, refill)
	stamina.set_max_stamina(stats.max_stamina, refill)
	mana.set_max_mana(stats.max_mana, refill)
	hurtbox.defense = stats.defense


func _on_level_up(new_level: int) -> void:
	if health.is_dead():
		return
	apply_stats(true)
	# Un seul effet à la fois : s'il reste celui d'un niveau précédent, il est remplacé.
	if is_instance_valid(level_up_effect):
		level_up_effect.queue_free()
	level_up_effect = LEVEL_UP_EFFECT.instantiate() as LevelUpEffect
	level_up_effect.level = new_level
	add_child(level_up_effect)


func _on_game_saving() -> void:
	GameState.data["player"] = {"hp": health.hp, "mana": mana.mana}


func _on_game_loaded() -> void:
	var saved: Dictionary = GameState.data.get("player", {})
	if saved.has("hp"):
		health.set_hp(int(saved["hp"]))
	if saved.has("mana"):
		mana.set_mana(float(saved["mana"]))


# --- Dégâts ------------------------------------------------------------------

func _on_damaged(_amount: int, source: Node) -> void:
	if not health.is_dead():
		state_machine.transition_to(&"Hurt", {"source": source})


func _on_died() -> void:
	state_machine.transition_to(&"Dead")
