class_name PlayerTuning
extends Resource
## Réglages de jeu du joueur (resources/balance/player_tuning.tres) : tout ce qui se
## règle pour l'équilibrage et le ressenti, modifiable dans l'inspecteur.

@export_group("Déplacement")
## Vitesses de base, multipliées par la stat Vitesse.
@export var walk_speed: float = 5.0
@export var run_speed: float = 9.0
## Vitesse de marche quand l'endurance est épuisée.
@export var exhausted_speed: float = 2.5
@export var ground_acceleration: float = 40.0
@export var ground_deceleration: float = 50.0
@export var air_acceleration: float = 12.0
## Vitesse de rotation du modèle vers la direction visée.
@export var rotation_speed: float = 12.0

@export_group("Saut")
@export var jump_velocity: float = 7.0
## Gravité renforcée à la descente : sauts plus nerveux.
@export var fall_gravity_multiplier: float = 1.6
## Vitesse verticale gardée si on relâche Espace pendant la montée.
@export var jump_cut_ratio: float = 0.5
## Délai pendant lequel on peut encore sauter après un rebord.
@export var coyote_time: float = 0.12
## Un appui sur Espace juste avant d'atterrir est mémorisé ce délai.
@export var jump_buffer_time: float = 0.15
## Tolérance avant de considérer qu'on a quitté le sol (terrain en triangles).
@export var ground_grace_time: float = 0.1

@export_group("Endurance")
@export var sprint_stamina_per_second: float = 20.0
@export var dodge_stamina_cost: float = 20.0
@export var stamina_regen_per_second: float = 30.0
## Délai sans effort avant que l'endurance remonte.
@export var stamina_regen_delay: float = 0.8
## Part de la jauge à récupérer après épuisement (1 = pleine, comme BotW).
@export var exhaustion_recovery_ratio: float = 1.0
@export var mana_regen_per_second: float = 4.0

@export_group("Roulade")
@export var dodge_speed: float = 11.0
@export var dodge_duration: float = 0.45
@export var dodge_invincibility: float = 0.35

@export_group("Combat")
## Durée du hit-stop quand un coup porte (secondes réelles).
@export var hit_stop_duration: float = 0.06
@export var critical_hit_stop_duration: float = 0.12
## Intensité du tremblement de caméra à l'impact (0 à 1).
@export var hit_shake: float = 0.35
@export var critical_hit_shake: float = 0.6

@export_group("Dégâts reçus")
@export var hurt_knockback: float = 6.0
@export var hurt_duration: float = 0.4
## Invincibilité après un coup reçu (secondes).
@export var invincibility_after_hit: float = 0.6
