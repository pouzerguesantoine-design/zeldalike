class_name GameUI
extends Node
## Regroupe toute l'interface d'un niveau (scene/ui/game_ui.tscn) : HUD, message
## d'interaction, inventaire, pause, écran de mort. Gère les touches globales :
## Échap (pause / fermer) et I (inventaire). Tourne même quand le jeu est en pause.

@onready var hud: HUD = $HUD
@onready var interaction_prompt: InteractionPrompt = $InteractionPrompt
@onready var inventory: InventoryMenu = $InventoryMenu
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var death_screen: DeathScreen = $DeathScreen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if death_screen.is_open():
		return
	if event.is_action_pressed("pause"):
		if inventory.is_open():
			inventory.close()
		elif pause_menu.is_open():
			pause_menu.close()
		elif _player_alive():
			pause_menu.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and not pause_menu.is_open():
		if inventory.is_open():
			inventory.close()
		elif _player_alive():
			inventory.open()
		get_viewport().set_input_as_handled()


func _player_alive() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	return player != null and not player.health.is_dead()
