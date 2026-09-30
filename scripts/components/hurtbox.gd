class_name Hurtbox
extends Area3D
## Zone qui encaisse les coups des Hitbox. Calcule les dégâts finaux (Défense,
## résistances), les transmet au HealthComponent, fait apparaître un chiffre de dégâts
## et diffuse EventBus.damage_dealt. Le recul est laissé au propriétaire (signal hit_received).
##
## Calques : joueur → calque 2 (player) ; ennemis → calque 3 (enemies). Masque vide.

const DAMAGE_NUMBER := preload("res://scene/ui/damage_number.tscn")

## Coup encaissé (info.amount contient les dégâts finaux).
signal hit_received(info: DamageInfo)

@export var health: HealthComponent
## Défense de la cible (mise à jour par le propriétaire, ex. stats du joueur).
@export var defense: int = 0
## Faiblesses / résistances : {DamageInfo.DamageType: multiplicateur}.
@export var resistances: Dictionary = {}
@export var show_damage_numbers: bool = true
## Hauteur d'apparition du chiffre de dégâts au-dessus de la Hurtbox.
@export var damage_number_height: float = 1.0


func _ready() -> void:
	monitoring = false
	monitorable = true


## Applique un coup. Renvoie false s'il est ignoré (cible invincible ou déjà morte).
func receive_hit(info: DamageInfo) -> bool:
	var multiplier := DamageCalculator.type_multiplier(resistances, info.damage_type)
	info.amount = DamageCalculator.compute_final(info.raw_amount, defense, multiplier)
	if health and not health.take_damage(info.amount, info.source):
		return false
	hit_received.emit(info)
	EventBus.damage_dealt.emit(get_parent(), info)
	if show_damage_numbers:
		_spawn_damage_number(info)
	return true


func _spawn_damage_number(info: DamageInfo) -> void:
	var number := DAMAGE_NUMBER.instantiate() as DamageNumber
	number.info = info
	var parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(number)
	number.global_position = global_position + Vector3.UP * damage_number_height \
		+ Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
