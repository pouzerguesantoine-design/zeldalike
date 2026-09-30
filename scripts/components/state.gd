class_name State
extends Node
## État générique d'une StateMachine. Chaque état est un nœud enfant de la machine ;
## son nom de nœud sert d'identifiant pour les transitions (ex. &"Idle").

## Machine qui possède cet état (assignée par la StateMachine).
var state_machine: StateMachine
## Nœud contrôlé (joueur, ennemi…), assigné par la StateMachine.
var actor: Node


## Appelé en entrant dans l'état. `msg` transporte des données optionnelles.
func enter(_msg: Dictionary) -> void:
	pass


## Appelé en quittant l'état.
func exit() -> void:
	pass


## Appelé à chaque image (_process).
func update(_delta: float) -> void:
	pass


## Appelé à chaque pas physique.
func physics_update(_delta: float) -> void:
	pass


## Reçoit les entrées non consommées (_unhandled_input).
func handle_input(_event: InputEvent) -> void:
	pass


## Raccourci : demande à la machine de passer à l'état `state_name`.
func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	state_machine.transition_to(state_name, msg)
