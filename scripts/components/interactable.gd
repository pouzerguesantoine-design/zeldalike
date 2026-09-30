class_name Interactable
extends Area3D
## Composant d'interaction (calque 7 « interactables ») : une zone que le joueur peut
## activer avec E quand il est devant. Le propriétaire (coffre, porte, PNJ…) écoute
## `interacted` et règle `available` / le texte du message.

signal interacted(player: Player)

## Verbe affiché dans le message à l'écran, ex. « Ouvrir » → « Ouvrir [E] ».
@export var prompt: String = "Ouvrir"
## Faux : l'objet est ignoré par le détecteur (coffre déjà ouvert…).
@export var available: bool = true

## Optionnel : fonction qui renvoie le texte du message selon la situation
## (ex. porte : « Déverrouiller » si le joueur a une clé, sinon « Verrouillée »).
var prompt_provider: Callable


func _ready() -> void:
	monitoring = false
	monitorable = true


func get_prompt() -> String:
	return prompt_provider.call() if prompt_provider.is_valid() else prompt


func interact(player: Player) -> void:
	if available:
		interacted.emit(player)
