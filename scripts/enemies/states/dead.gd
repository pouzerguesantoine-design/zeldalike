extends EnemyState
## Mort : animation, collisions coupées, XP donnée, butin lâché, puis disparition
## (le modèle rétrécit juste avant d'être retiré).

## Durée du rétrécissement final (secondes).
@export var vanish_duration: float = 0.35

var _elapsed: float
var _vanishing: bool


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	_vanishing = false
	enemy.reset_attack()
	enemy.disable_collisions()
	enemy.play_action(&"death")
	enemy.play_death_effects()
	GameState.add_xp(enemy.stats.xp_reward)
	EventBus.enemy_died.emit(enemy)
	enemy.drop_loot()


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_gravity(delta)
	enemy.stop_moving(delta)
	if not _vanishing and _elapsed >= enemy.despawn_delay - vanish_duration:
		_vanishing = true
		enemy.create_tween().tween_property(enemy.visual, "scale", Vector3.ONE * 0.01, vanish_duration)
	if _elapsed >= enemy.despawn_delay:
		enemy.queue_free()
