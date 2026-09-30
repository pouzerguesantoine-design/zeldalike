extends EnemyState
## Mort : animation, collisions coupées, XP donnée, butin lâché, puis disparition.

var _elapsed: float


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	enemy.reset_attack()
	enemy.disable_collisions()
	enemy.anim.stop()
	enemy.anim.play(&"death")
	GameState.add_xp(enemy.stats.xp_reward)
	EventBus.enemy_died.emit(enemy)
	enemy.drop_loot()


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_gravity(delta)
	enemy.stop_moving(delta)
	if _elapsed >= enemy.despawn_delay:
		enemy.queue_free()
