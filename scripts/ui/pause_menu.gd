class_name PauseMenu
extends MenuScreen
## Menu pause (Échap) : Reprendre, Sauvegarder, Charger, Quitter (vers l'écran titre).
## Navigable à la souris et au clavier (flèches + Entrée, Échap pour reprendre).

@onready var resume_button: Button = %ResumeButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var quit_button: Button = %QuitButton
@onready var graphics_option: OptionButton = %GraphicsOption
@onready var message_label: Label = %MessageLabel


func _ready() -> void:
	super._ready()
	resume_button.pressed.connect(close)
	save_button.pressed.connect(save)
	load_button.pressed.connect(func() -> void: GameState.continue_game())
	quit_button.pressed.connect(func() -> void: GameState.go_to_title())
	graphics_option.item_selected.connect(func(index: int) -> void: GameState.set_graphics_quality(index))


func _on_opened() -> void:
	message_label.text = ""
	load_button.disabled = not GameState.has_save()
	graphics_option.select(GameState.graphics_quality)
	resume_button.grab_focus.call_deferred()


func save() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player and player.health.is_dead():
		return
	if GameState.save_game():
		Sfx.play(self, &"save_game")
		message_label.text = "Partie sauvegardée."
		load_button.disabled = false
	else:
		message_label.text = "La sauvegarde a échoué."
