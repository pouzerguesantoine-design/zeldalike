class_name DamageInfo
extends RefCounted
## Description d'un coup porté : transmise de la Hitbox à la Hurtbox (jalon 3),
## puis diffusée via EventBus.damage_dealt.

enum DamageType { PHYSIQUE, FEU, GLACE, FOUDRE, MAGIE }

var amount: int = 1
var damage_type: DamageType = DamageType.PHYSIQUE
## Force de recul appliquée à la cible (m/s).
var knockback: float = 0.0
var is_critical: bool = false
## Nœud à l'origine du coup (joueur, ennemi, projectile…).
var source: Node


func _init(p_amount: int = 1, p_type: DamageType = DamageType.PHYSIQUE, p_source: Node = null) -> void:
	amount = p_amount
	damage_type = p_type
	source = p_source
