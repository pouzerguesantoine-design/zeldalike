class_name DamageInfo
extends RefCounted
## Description d'un coup porté. L'attaquant remplit `raw_amount` (partie offensive de la
## formule) ; la Hurtbox de la cible calcule `amount` (après Défense et résistances),
## puis le coup est diffusé via EventBus.damage_dealt.

enum DamageType { PHYSIQUE, FEU, GLACE, FOUDRE, MAGIE }

## Dégâts avant Défense : (base × mult + Force) × combo × critique.
var raw_amount: float = 1.0
## Dégâts finaux réellement infligés (renseignés par la Hurtbox).
var amount: int = 0
var damage_type: DamageType = DamageType.PHYSIQUE
## Force de recul appliquée à la cible (m/s).
var knockback: float = 0.0
var is_critical: bool = false
## Nœud à l'origine du coup (joueur, ennemi…) : sert au recul et à ignorer ses propres coups.
var source: Node3D


func copy() -> DamageInfo:
	var result := DamageInfo.new()
	result.raw_amount = raw_amount
	result.amount = amount
	result.damage_type = damage_type
	result.knockback = knockback
	result.is_critical = is_critical
	result.source = source
	return result
