class_name InteractionPrompt
extends CanvasLayer
## Message en bas de l'écran quand un objet est activable : « Ouvrir [E] ».
## (Sera intégré au HUD du jalon 7.)

## Touche affichée (E est à la même place en AZERTY et en QWERTY).
@export var key_label: String = "E"

var _target: Interactable

@onready var panel: Control = $Panel
@onready var label: Label = $Panel/Label


func _ready() -> void:
	panel.visible = false
	EventBus.interaction_target_changed.connect(func(target: Interactable) -> void: _target = target)


func _process(_delta: float) -> void:
	# Mis à jour à chaque image : le texte peut changer (ex. clé ramassée).
	var show := is_instance_valid(_target) and _target.available
	panel.visible = show
	if show:
		label.text = "%s  [%s]" % [_target.get_prompt(), key_label]


func get_text() -> String:
	return label.text if panel.visible else ""
