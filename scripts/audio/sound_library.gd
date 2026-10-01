class_name SoundLibrary
extends Resource
## Catalogue des effets sonores du jeu (resources/audio/sound_library.tres), réglable dans
## l'inspecteur. Les sons sont générés par tools/audio/generate_sounds.py (CC0).

@export var effects: Array[SoundEffect] = []

var _by_id: Dictionary[StringName, SoundEffect] = {}


func get_effect(id: StringName) -> SoundEffect:
	if _by_id.size() != effects.size():
		_by_id.clear()
		for effect in effects:
			_by_id[effect.id] = effect
	return _by_id.get(id)
