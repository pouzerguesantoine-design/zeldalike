class_name HealthComponent
extends Node
## Points de vie réutilisables (joueur, ennemis, objets destructibles),
## avec invincibilité temporaire (i-frames).

signal damaged(amount: int, source: Node)
signal healed(amount: int)
signal died
signal health_changed(hp: int, max_hp: int)

@export var max_hp: int = 30
## Invincibilité accordée automatiquement après chaque coup reçu (secondes).
@export var invincibility_after_hit: float = 0.6

var hp: int
var _invincible_left: float = 0.0


func _ready() -> void:
	hp = max_hp


func _physics_process(delta: float) -> void:
	if _invincible_left > 0.0:
		_invincible_left = maxf(_invincible_left - delta, 0.0)


func is_dead() -> bool:
	return hp <= 0


func is_invincible() -> bool:
	return _invincible_left > 0.0


## Rend invincible pendant `duration` secondes (ne raccourcit jamais une invincibilité en cours).
func set_invincible(duration: float) -> void:
	_invincible_left = maxf(_invincible_left, duration)


## Inflige des dégâts. Renvoie false s'ils sont ignorés (déjà mort ou invincible).
func take_damage(amount: int, source: Node = null) -> bool:
	if is_dead() or is_invincible() or amount <= 0:
		return false
	hp = maxi(hp - amount, 0)
	health_changed.emit(hp, max_hp)
	damaged.emit(amount, source)
	if hp == 0:
		died.emit()
	else:
		set_invincible(invincibility_after_hit)
	return true


## Change le maximum (montée de niveau…). `refill` remet la vie au maximum.
func set_max_hp(value: int, refill: bool) -> void:
	max_hp = maxi(value, 1)
	hp = max_hp if refill else mini(hp, max_hp)
	health_changed.emit(hp, max_hp)


## Fixe directement la vie (chargement d'une sauvegarde).
func set_hp(value: int) -> void:
	hp = clampi(value, 1, max_hp)
	health_changed.emit(hp, max_hp)


func heal(amount: int) -> void:
	if is_dead() or amount <= 0:
		return
	var before := hp
	hp = mini(hp + amount, max_hp)
	if hp != before:
		health_changed.emit(hp, max_hp)
		healed.emit(hp - before)
