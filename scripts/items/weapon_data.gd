class_name WeaponData
extends Resource
## Arme de corps à corps. Une arme = un fichier .tres dans resources/weapons/
## (chargé automatiquement par GameState).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
## Modèle 3D tenu en main (.glb au jalon 5 ; scène en primitives en attendant).
## Convention : la poignée à l'origine, la lame vers -Z.
@export var model_scene: PackedScene

@export_group("Dégâts")
@export var base_damage: float = 5.0
@export var damage_multiplier: float = 1.0
@export var damage_type: DamageInfo.DamageType = DamageInfo.DamageType.PHYSIQUE
## Multiplicateur de chaque coup du combo (le 3e coup est le coup final).
@export var combo_multipliers: Array[float] = [1.0, 1.2, 1.6]
@export_range(0.0, 1.0) var critical_chance: float = 0.1
## Recul infligé (m/s) ; le coup final du combo le multiplie par finisher_knockback_multiplier.
@export var knockback: float = 4.0
@export var finisher_knockback_multiplier: float = 1.5

@export_group("Maniement")
## Multiplicateur de vitesse des animations d'attaque (1 = normal).
@export var attack_speed: float = 1.0
## Portée (m) : profondeur de la zone de coup devant le joueur.
@export var reach: float = 1.6
@export var stamina_cost: float = 8.0


## Multiplicateur du coup n° `combo_index` (0, 1, 2…).
func get_combo_multiplier(combo_index: int) -> float:
	if combo_multipliers.is_empty():
		return 1.0
	return combo_multipliers[mini(combo_index, combo_multipliers.size() - 1)]


func get_combo_length() -> int:
	return maxi(combo_multipliers.size(), 1)
