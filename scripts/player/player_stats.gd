class_name PlayerStats
extends Resource
## Statistiques du joueur : niveau, XP et caractéristiques.
## Les valeurs de départ et les gains par niveau se règlent dans
## resources/stats/player_base_stats.tres ; GameState en garde une copie qui évolue.

@export_group("Progression")
@export var level: int = 1
## XP accumulée dans le niveau en cours (repart de 0 à chaque niveau, surplus conservé).
@export var xp: int = 0
@export var max_level: int = 50

@export_group("Caractéristiques")
@export var max_hp: int = 30
@export var max_stamina: float = 100.0
## Force : s'ajoute aux dégâts de l'arme (voir DamageCalculator).
@export var force: int = 2
## Défense : chaque point retire 0,5 aux dégâts reçus.
@export var defense: int = 1
## Vitesse : modifie la vitesse de marche et de course.
@export var speed: int = 10

@export_group("Gain par niveau")
@export var hp_per_level: int = 5
@export var stamina_per_level: float = 10.0
@export var force_per_level: int = 2
@export var defense_per_level: int = 1
@export var speed_per_level: int = 1

@export_group("Effet de la Vitesse")
## Valeur de Vitesse qui correspond à la vitesse de déplacement de base (×1).
@export var reference_speed: int = 10
## Bonus de vitesse de déplacement par point au-dessus de la référence (0.02 = +2 %).
@export var move_bonus_per_speed_point: float = 0.02

## Champs écrits dans la sauvegarde (les réglages de progression restent dans le .tres).
const SAVED_FIELDS: Array[StringName] = [&"level", &"xp", &"max_hp", &"max_stamina", &"force", &"defense", &"speed"]


## XP nécessaire pour passer au niveau suivant : 100 × niveau^1,5.
func get_xp_to_next() -> int:
	return roundi(100.0 * pow(level, 1.5))


func is_max_level() -> bool:
	return level >= max_level


## Multiplicateur appliqué aux vitesses de déplacement du joueur (jamais sous ×0,5).
func get_move_speed_multiplier() -> float:
	return maxf(0.5, 1.0 + (speed - reference_speed) * move_bonus_per_speed_point)


## Ajoute de l'XP et fait monter de niveau autant de fois que nécessaire.
## Renvoie le nombre de niveaux gagnés.
func add_xp(amount: int) -> int:
	if amount <= 0 or is_max_level():
		return 0
	xp += amount
	var levels_gained := 0
	while not is_max_level() and xp >= get_xp_to_next():
		xp -= get_xp_to_next()
		_level_up()
		levels_gained += 1
	if is_max_level():
		xp = 0
	return levels_gained


func _level_up() -> void:
	level += 1
	max_hp += hp_per_level
	max_stamina += stamina_per_level
	force += force_per_level
	defense += defense_per_level
	speed += speed_per_level


func to_dict() -> Dictionary:
	var result := {}
	for field in SAVED_FIELDS:
		result[field] = get(field)
	return result


func from_dict(values: Dictionary) -> void:
	for field in SAVED_FIELDS:
		if values.has(field):
			# Le JSON ne connaît que des nombres flottants : on reconvertit dans le type du champ.
			set(field, type_convert(values[field], typeof(get(field))))
