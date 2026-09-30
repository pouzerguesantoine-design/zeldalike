class_name DamageCalculator
extends RefCounted
## Formule de dégâts unique du jeu (documentée dans CLAUDE.md) :
##   dégâts = (base_arme × multiplicateur_arme + Force) × multiplicateur_combo
##            × (critique ? 1,5 : 1) − Défense_cible × 0,5
##   puis × multiplicateur de type (faiblesse / résistance), arrondi, minimum 1.
## Elle est coupée en deux : la partie offensive est calculée par l'attaquant
## (compute_offense → DamageInfo.raw_amount), la partie défensive par la Hurtbox (compute_final).

const CRITICAL_MULTIPLIER := 1.5
const DEFENSE_FACTOR := 0.5


static func compute_offense(
		weapon_base_damage: float,
		weapon_multiplier: float,
		attacker_force: int,
		combo_multiplier: float,
		is_critical: bool) -> float:
	var damage := (weapon_base_damage * weapon_multiplier + attacker_force) * combo_multiplier
	if is_critical:
		damage *= CRITICAL_MULTIPLIER
	return damage


static func compute_final(raw_amount: float, target_defense: int, type_multiplier: float = 1.0) -> int:
	return maxi(1, roundi((raw_amount - target_defense * DEFENSE_FACTOR) * type_multiplier))


## Formule complète en un appel (pratique pour les tests et l'équilibrage).
static func compute(
		weapon_base_damage: float,
		weapon_multiplier: float,
		attacker_force: int,
		combo_multiplier: float,
		is_critical: bool,
		target_defense: int,
		type_multiplier: float = 1.0) -> int:
	var raw := compute_offense(weapon_base_damage, weapon_multiplier, attacker_force, combo_multiplier, is_critical)
	return compute_final(raw, target_defense, type_multiplier)


## Multiplicateur de type lu dans un dictionnaire {DamageInfo.DamageType: float}
## (ex. {FEU: 2.0} = faible au feu, {GLACE: 0.5} = résistant). 1.0 si absent.
static func type_multiplier(resistances: Dictionary, damage_type: DamageInfo.DamageType) -> float:
	return float(resistances.get(damage_type, 1.0))
