class_name MenuScreen
extends CanvasLayer
## Base des menus plein écran (inventaire, pause, écran de mort) : met le jeu en pause,
## libère la souris (EventBus.game_menu_toggled) et donne le focus clavier.
## Les menus tournent pendant la pause (process_mode = ALWAYS).

signal opened
signal closed

## Faux pour l'écran de mort : le monde continue de tourner derrière.
@export var pauses_game: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	if pauses_game:
		get_tree().paused = true
	EventBus.game_menu_toggled.emit(true)
	_on_opened()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	if pauses_game:
		get_tree().paused = false
	EventBus.game_menu_toggled.emit(false)
	closed.emit()


## À redéfinir : rafraîchir le contenu et donner le focus au premier bouton.
func _on_opened() -> void:
	pass
