class_name StateMachine
extends Node
## Machine à états générique, réutilisable pour le joueur ET les ennemis.
## Les états sont les nœuds enfants (scripts héritant de State).

signal state_changed(from_state: StringName, to_state: StringName)

## État actif au démarrage (par défaut : premier enfant).
@export var initial_state: State
## Nœud contrôlé par les états (par défaut : le parent).
@export var actor: Node
## Si false, le propriétaire appelle lui-même physics_update() (utile pour
## ordonner : minuteries → état → move_and_slide).
@export var auto_process_physics: bool = true

var current_state: State
var _states: Dictionary[StringName, State] = {}


func _ready() -> void:
	if actor == null:
		actor = get_parent()
	for child in get_children():
		if child is State:
			var state := child as State
			state.state_machine = self
			state.actor = actor
			_states[state.name] = state
	set_physics_process(auto_process_physics)

	# Les enfants sont prêts avant le parent : on attend que l'acteur ait
	# initialisé ses @onready avant d'entrer dans le premier état.
	if not actor.is_node_ready():
		await actor.ready
	if initial_state == null and not _states.is_empty():
		initial_state = _states.values()[0]
	current_state = initial_state
	if current_state:
		current_state.enter({})


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


## Fait avancer l'état actif d'un pas physique.
func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


## Change d'état (on peut ré-entrer dans l'état courant, ex. Hurt → Hurt).
func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	if not _states.has(state_name):
		push_error("StateMachine '%s' : état inconnu '%s'" % [get_path(), state_name])
		return
	var previous := current_state
	if previous:
		previous.exit()
	current_state = _states[state_name]
	current_state.enter(msg)
	state_changed.emit(previous.name if previous else &"", state_name)


func get_state_name() -> StringName:
	return current_state.name if current_state else &""
