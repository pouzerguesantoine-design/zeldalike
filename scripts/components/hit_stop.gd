class_name HitStop
extends RefCounted
## Hit-stop : ralentit presque totalement le jeu quelques centièmes de seconde à l'impact
## pour donner du poids aux coups. Les gels qui se chevauchent sont comptés.

static var _active_freezes: int = 0


static func freeze(tree: SceneTree, duration: float, time_scale: float = 0.05) -> void:
	_active_freezes += 1
	Engine.time_scale = time_scale
	# Minuterie en temps réel (ignore_time_scale), sinon elle serait elle-même ralentie.
	await tree.create_timer(duration, true, false, true).timeout
	_active_freezes -= 1
	if _active_freezes == 0:
		Engine.time_scale = 1.0


static func is_active() -> bool:
	return _active_freezes > 0
