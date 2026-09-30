extends PlayerState
## Mort : le personnage s'effondre (animation « death »), plus aucune commande.
## La réapparition (écran de mort) arrive au jalon 7.


func enter(_msg: Dictionary) -> void:
	player.lock_on.release()
	player.play_body_animation(&"death", true)
	EventBus.player_died.emit()


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_horizontally(Vector3.ZERO, 0.0, delta)
