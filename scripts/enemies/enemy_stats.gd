class_name EnemyStats
extends Resource
## Caractéristiques d'un type d'ennemi (fichiers .tres dans resources/stats/).
## Le comportement (portées, délais…) se règle sur la scène de l'ennemi.

@export var display_name: String
@export var max_hp: int = 20
## Force : s'ajoute aux dégâts de base de l'attaque (formule commune).
@export var force: int = 1
@export var defense: int = 0
## Vitesse de poursuite (m/s) ; la patrouille va moins vite.
@export var speed: float = 3.0
@export var xp_reward: int = 20
## Dégâts de base de l'attaque (équivalent des dégâts de l'arme du joueur).
@export var attack_damage: float = 4.0
@export var attack_knockback: float = 6.0
## Faiblesses / résistances : {DamageInfo.DamageType: multiplicateur}, ex. {FEU: 1.5}.
@export var resistances: Dictionary = {}
