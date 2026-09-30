extends PlayerState
## Lancer de sort : joue l'animation « cast » ; sa piste de méthode appelle
## player._anim_release_spell() au bon moment (mana payé à cet instant).
## Sans lock-on, le personnage se tourne d'abord dans l'axe de la caméra pour viser.


func enter(_msg: Dictionary) -> void:
	if not player.lock_on.has_target():
		player.face_direction_instant(player.camera_pivot.get_flat_forward())
	player.anim.stop()
	player.anim.play(&"cast")


func exit() -> void:
	player.reset_combat_pose()


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_horizontally(Vector3.ZERO, 0.0, delta)
	player.update_facing(Vector3.ZERO, delta)
	if not player.anim.is_playing():
		transition_to(state_after_action())
