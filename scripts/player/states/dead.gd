extends PlayerState
## Mort : le personnage s'effondre, plus aucune commande.
## La réapparition (écran de mort) arrive au jalon 7.


func enter(_msg: Dictionary) -> void:
	player.lock_on.release()
	EventBus.player_died.emit()
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(player.visual, "rotation:x", -PI / 2.0, 0.6)
	tween.parallel().tween_property(player.visual, "position:y", 0.45, 0.6)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_horizontally(Vector3.ZERO, 0.0, delta)
