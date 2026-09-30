extends EnemyState
## Attaque en trois temps, entièrement décrits par l'animation « attack » :
##   1. télégraphie lisible (« ! » rouge + mouvement de préparation), l'ennemi suit le joueur
##      du regard ;
##   2. piste de méthode _anim_commit_attack() : le coup part (bond du Slime) ;
##   3. piste de propriété AttackHitbox:active pendant les frames actives, puis récupération.
## À la fin : recharge, puis retour en poursuite.


func enter(_msg: Dictionary) -> void:
	enemy.prepare_attack()
	enemy.play_action(&"attack")


func exit() -> void:
	enemy.reset_attack()


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	if not enemy.attack_committed:
		enemy.face_player(delta)
	enemy.stop_moving(delta)
	if not enemy.anim.is_playing():
		enemy.attack_cooldown_left = enemy.attack_cooldown
		transition_to(&"Chase")
