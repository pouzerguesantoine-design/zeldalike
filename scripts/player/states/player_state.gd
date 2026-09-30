class_name PlayerState
extends State
## Base des états du joueur : accès typé au Player et transitions communes.

var player: Player:
	get:
		return actor as Player


## Actions déclenchables depuis les états au sol (Idle, Walk, Run).
## Renvoie true si une transition a eu lieu : l'état appelant doit alors s'arrêter.
func try_ground_actions() -> bool:
	if player.try_consume_jump():
		transition_to(&"Jump")
		return true
	if not player.is_grounded():
		transition_to(&"Fall")
		return true
	if Input.is_action_just_pressed("dodge") and player.stamina.try_consume(player.dodge_stamina_cost):
		transition_to(&"Dodge")
		return true
	if Input.is_action_just_pressed("interact") and player.interaction.try_interact():
		return true
	if player.combat_input_allowed():
		# Attaquer coûte de l'endurance : impossible pendant l'épuisement.
		if Input.is_action_just_pressed("attack") and player.get_weapon() \
				and player.stamina.try_consume(player.get_weapon().stamina_cost):
			transition_to(&"Attack")
			return true
		# Le sort ne part que si le mana couvre tout son coût.
		if Input.is_action_just_pressed("magic") and player.spell \
				and player.mana.can_afford(player.spell.mana_cost):
			transition_to(&"Magic")
			return true
	return false


## État de locomotion au sol correspondant aux entrées : Idle, Walk ou Run.
func ground_state_from_input() -> StringName:
	if player.get_input_vector().is_zero_approx():
		return &"Idle"
	if Input.is_action_pressed("sprint") and player.stamina.can_use():
		return &"Run"
	return &"Walk"


## État à rejoindre à la fin d'une action (roulade, attaque, coup reçu…).
func state_after_action() -> StringName:
	return ground_state_from_input() if player.is_grounded() else &"Fall"


## Déplacement aérien commun à Jump et Fall.
func air_move(speed: float, delta: float) -> void:
	player.apply_gravity(delta)
	var direction := player.get_move_direction()
	player.move_horizontally(direction, speed, delta)
	player.update_facing(direction, delta)
