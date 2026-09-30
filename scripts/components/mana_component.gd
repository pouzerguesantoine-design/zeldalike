class_name ManaComponent
extends Node
## Mana : jauge des sorts. Contrairement à l'endurance, un sort n'est lancé que si le
## mana suffit pour son coût complet ; la régénération est lente et continue.

signal mana_changed(value: float, max_value: float)

@export var max_mana: float = 50.0
@export var regen_per_second: float = 4.0

var mana: float


func _ready() -> void:
	mana = max_mana


func _physics_process(delta: float) -> void:
	if mana < max_mana:
		_set_mana(mana + regen_per_second * delta)


func can_afford(cost: float) -> bool:
	return mana >= cost


func try_consume(cost: float) -> bool:
	if not can_afford(cost):
		return false
	_set_mana(mana - cost)
	return true


## Change le maximum (montée de niveau…). `refill` remplit la jauge.
func set_max_mana(value: float, refill: bool) -> void:
	max_mana = maxf(value, 1.0)
	_set_mana(max_mana if refill else minf(mana, max_mana))


## Fixe directement le mana (chargement d'une sauvegarde).
func set_mana(value: float) -> void:
	_set_mana(value)


func _set_mana(value: float) -> void:
	mana = clampf(value, 0.0, max_mana)
	mana_changed.emit(mana, max_mana)
