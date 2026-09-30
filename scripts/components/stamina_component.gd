class_name StaminaComponent
extends Node
## Endurance : consommation, régénération après un délai et épuisement façon BotW
## (jauge vidée → plus de sprint ni de roulade tant qu'elle n'est pas remontée).

signal stamina_changed(value: float, max_value: float)
signal exhausted
signal recovered

@export var max_stamina: float = 100.0
@export var regen_per_second: float = 30.0
## Délai sans consommation avant que la régénération reprenne (secondes).
@export var regen_delay: float = 0.8
## Part de la jauge à récupérer après un épuisement (1.0 = pleine, comme dans BotW).
@export_range(0.0, 1.0) var exhaustion_recovery_ratio: float = 1.0

var stamina: float
var is_exhausted: bool = false
var _regen_wait: float = 0.0


func _ready() -> void:
	stamina = max_stamina


func _physics_process(delta: float) -> void:
	if _regen_wait > 0.0:
		_regen_wait -= delta
		return
	if stamina < max_stamina:
		_set_stamina(stamina + regen_per_second * delta)
	if is_exhausted and stamina >= max_stamina * exhaustion_recovery_ratio:
		is_exhausted = false
		recovered.emit()


func can_use() -> bool:
	return not is_exhausted and stamina > 0.0


## Tente de consommer `cost`. Comme dans BotW, l'action est permise tant que la
## jauge n'est pas vide (le coût peut dépasser le reste) ; la vider provoque l'épuisement.
func try_consume(cost: float) -> bool:
	if not can_use():
		return false
	_set_stamina(stamina - cost)
	_regen_wait = regen_delay
	if stamina <= 0.0:
		is_exhausted = true
		exhausted.emit()
	return true


func _set_stamina(value: float) -> void:
	stamina = clampf(value, 0.0, max_stamina)
	stamina_changed.emit(stamina, max_stamina)
