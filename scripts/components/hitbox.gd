class_name Hitbox
extends Area3D
## Zone qui porte un coup. Elle n'inflige des dégâts que lorsque `active` est vrai :
## pour les armes, `active` est piloté par une piste de l'AnimationPlayer (frames actives).
## Chaque Hurtbox n'est touchée qu'une fois par activation.
##
## Calques : joueur → calque 4 (player_hitbox), masque 3 (enemies) ;
##           ennemi → calque 5 (enemy_hitbox), masque 2 (player).

## Un coup a été accepté par une Hurtbox (après Défense et invincibilité).
signal hit_landed(hurtbox: Hurtbox, info: DamageInfo)

@export var active: bool = false:
	set(value):
		if value and not active:
			_already_hit.clear()
		active = value

## Modèle du coup, préparé par le propriétaire avant l'activation (copié à chaque touche).
var damage_info: DamageInfo

var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	# La détection reste allumée en permanence ; seul `active` décide des dégâts
	# (changer `monitoring` en plein calcul physique est interdit par Godot).
	monitoring = true
	monitorable = false


func _physics_process(_delta: float) -> void:
	if not active or damage_info == null:
		return
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null or _already_hit.has(hurtbox) or hurtbox.get_parent() == damage_info.source:
			continue
		_already_hit.append(hurtbox)
		var info := damage_info.copy()
		if hurtbox.receive_hit(info):
			hit_landed.emit(hurtbox, info)
