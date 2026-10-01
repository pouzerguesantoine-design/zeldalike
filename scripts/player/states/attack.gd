extends PlayerState
## Combo au corps à corps (3 coups avec les armes actuelles). Chaque coup joue sa propre
## animation (attack_1, attack_2, attack_3) : ses pistes activent la Hitbox pendant les
## frames actives puis ouvrent la fenêtre d'enchaînement (player.combo_window_open).
## Un clic pendant le coup est mémorisé (buffer) et déclenche le coup suivant dès
## l'ouverture de la fenêtre. La roulade peut annuler la fin d'un coup.
## L'endurance du 1er coup est payée dans PlayerState.try_ground_actions.

const ANIMATIONS: Array[StringName] = [&"attack_1", &"attack_2", &"attack_3"]

## Petit pas en avant au début de chaque coup.
@export var lunge_speed: float = 3.5
@export var lunge_duration: float = 0.1

var _combo_index: int
var _attack_buffered: bool
var _elapsed: float


func enter(_msg: Dictionary) -> void:
	_combo_index = 0
	_start_hit()


func exit() -> void:
	player.reset_combat_pose()


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	if _elapsed < lunge_duration:
		var lunge := player.get_forward() * lunge_speed
		player.velocity.x = lunge.x
		player.velocity.z = lunge.z
	else:
		player.move_horizontally(Vector3.ZERO, 0.0, delta)
	player.update_facing(Vector3.ZERO, delta)

	if Input.is_action_just_pressed("attack") and player.combat_input_allowed():
		_attack_buffered = true

	if player.combo_window_open:
		var weapon := player.get_weapon()
		if _attack_buffered and _combo_index < mini(weapon.get_combo_length(), ANIMATIONS.size()) - 1 \
				and player.stamina.try_consume(weapon.stamina_cost):
			_combo_index += 1
			_start_hit()
			return
		if Input.is_action_just_pressed("dodge") and player.stamina.try_consume(player.dodge_stamina_cost):
			transition_to(&"Dodge")
			return

	if not player.anim.is_playing():
		transition_to(state_after_action())


func _start_hit() -> void:
	_elapsed = 0.0
	_attack_buffered = false
	# Entre deux coups, on peut réorienter l'attaque avec les touches (hors lock-on).
	var direction := player.get_move_direction()
	if not player.lock_on.has_target() and not direction.is_zero_approx():
		player.face_direction_instant(direction)
	player.prepare_weapon_hit(_combo_index)
	# Deux lecteurs démarrés ensemble à la même vitesse : l'AnimationPlayer « gameplay »
	# (frames actives, fenêtre d'enchaînement) et l'AnimationTree du corps.
	var speed := player.get_weapon().attack_speed
	player.anim.stop()
	player.anim.play(ANIMATIONS[_combo_index], -1, speed)
	player.set_attack_animation_speed(ANIMATIONS[_combo_index], speed)
	player.play_body_animation(ANIMATIONS[_combo_index], true)
	Sfx.play(player, &"sword_swing", player.global_position + Vector3.UP)
