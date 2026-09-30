class_name DamageCalculator
extends RefCounted
## Formule de dégâts unique du jeu (documentée dans CLAUDE.md) :
##   dégâts = (base_arme × multiplicateur_arme + Force) × multiplicateur_combo
##            × (critique ? 1,5 : 1) − Défense_cible × 0,5
##   puis × multiplicateur de type (faiblesse / résistance), minimum 1.

const CRITICAL_MULTIPLIER := 1.5
const DEFENSE_FACTOR := 0.5


static func compute(
		weapon_base_damage: float,
		weapon_multiplier: float,
		attacker_force: int,
		combo_multiplier: float,
		is_critical: bool,
		target_defense: int,
		type_multiplier: float = 1.0) -> int:
	var damage := (weapon_base_damage * weapon_multiplier + attacker_force) * combo_multiplier
	if is_critical:
		damage *= CRITICAL_MULTIPLIER
	damage -= target_defense * DEFENSE_FACTOR
	damage *= type_multiplier
	return maxi(1, roundi(damage))


## Multiplicateur de type lu dans un dictionnaire {DamageInfo.DamageType: float}
## (ex. {FEU: 2.0} = faible au feu, {GLACE: 0.5} = résistant). 1.0 si absent.
static func type_multiplier(resistances: Dictionary, damage_type: DamageInfo.DamageType) -> float:
	return float(resistances.get(damage_type, 1.0))
