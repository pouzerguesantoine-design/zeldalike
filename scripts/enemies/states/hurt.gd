extends EnemyState
## Coup reçu : l'ennemi est sonné un court instant (le recul est donné par
## Enemy._on_hit_received), son attaque en cours est annulée, puis il riposte (Chase).

var _elapsed: float


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	enemy.reset_attack()
	enemy.anim.stop()
	enemy.anim.play(&"hurt")


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_gravity(delta)
	enemy.stop_moving(delta)
	if _elapsed >= enemy.hurt_duration:
		transition_to(&"Chase")
