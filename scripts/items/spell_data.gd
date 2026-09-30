class_name SpellData
extends Resource
## Sort lancé avec le clic droit (fichiers .tres dans resources/spells/).
## Les dégâts suivent la formule commune, avec la Force du lanceur et un combo de 1.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var projectile_scene: PackedScene

@export_group("Coût et dégâts")
@export var mana_cost: float = 10.0
@export var base_damage: float = 6.0
@export var damage_multiplier: float = 1.0
@export var damage_type: DamageInfo.DamageType = DamageInfo.DamageType.MAGIE
@export var knockback: float = 3.0

@export_group("Projectile")
@export var projectile_speed: float = 14.0
## Vitesse de virage vers la cible verrouillée (radians par seconde).
@export var homing_turn_speed: float = 5.0
@export var lifetime: float = 2.5
