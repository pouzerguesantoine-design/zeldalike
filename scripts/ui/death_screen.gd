class_name DeathScreen
extends MenuScreen
## Écran de mort : apparaît en fondu peu après la chute du héros.
## « Réapparaître » reprend au dernier point de sauvegarde (ou recommence une partie).

## Délai entre la mort et l'apparition de l'écran (laisse voir l'animation).
@export var show_delay: float = 1.6
@export var fade_duration: float = 0.8

@onready var root: Control = $Root
@onready var respawn_button: Button = %RespawnButton
@onready var title_button: Button = %TitleButton
@onready var hint_label: Label = %HintLabel


func _ready() -> void:
	pauses_game = false
	super._ready()
	respawn_button.pressed.connect(func() -> void: GameState.continue_game())
	title_button.pressed.connect(func() -> void: GameState.go_to_title())
	EventBus.player_died.connect(show_after_delay)


func show_after_delay() -> void:
	await get_tree().create_timer(show_delay).timeout
	open()


func _on_opened() -> void:
	hint_label.text = "Vous reprendrez au dernier point de sauvegarde." if GameState.has_save() \
		else "Aucune sauvegarde : une nouvelle partie commencera."
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, fade_duration)
	respawn_button.grab_focus.call_deferred()
