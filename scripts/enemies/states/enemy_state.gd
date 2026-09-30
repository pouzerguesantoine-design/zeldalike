class_name EnemyState
extends State
## Base des états des ennemis : accès typé à l'Enemy.

var enemy: Enemy:
	get:
		return actor as Enemy


## Passe en poursuite si le joueur est repéré. Renvoie true si la transition a eu lieu.
func try_start_chase() -> bool:
	if enemy.can_see_player():
		transition_to(&"Chase")
		return true
	return false
