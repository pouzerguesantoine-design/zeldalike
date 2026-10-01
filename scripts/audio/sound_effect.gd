class_name SoundEffect
extends Resource
## Un effet sonore et ses réglages (volume, variation de hauteur, bus, 3D ou non).

@export var id: StringName
@export var stream: AudioStream
@export_range(-40.0, 12.0) var volume_db: float = 0.0
## Variation aléatoire de hauteur (0,1 = ±10 %) : évite la répétition mécanique.
@export_range(0.0, 0.5) var pitch_variation: float = 0.05
## Son spatialisé (entendu depuis sa position) ou non (interface, jingles).
@export var positional: bool = true
@export var bus: StringName = &"SFX"
