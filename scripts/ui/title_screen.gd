class_name TitleScreen
extends Control
## Écran titre : l'île tourne lentement en arrière-plan (rendue dans un SubViewport, sans
## joueur ni interface). Nouvelle partie / Continuer (si une sauvegarde existe) / Quitter.

const LEVEL := "res://scene/world/island.tscn"

@export var orbit_radius: float = 46.0
@export var orbit_height: float = 24.0
@export var orbit_speed: float = 0.06

var _angle: float = 0.6

@onready var viewport: SubViewport = %PreviewViewport
@onready var preview_camera: Camera3D = %PreviewCamera
@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var island: Node = load(LEVEL).instantiate()
	# Décor seul : pas de joueur (ni sa caméra) ni d'interface dans l'aperçu.
	for node_name in ["Player", "GameUI"]:
		var node := island.get_node_or_null(NodePath(node_name))
		if node:
			island.remove_child(node)
			node.free()
	viewport.add_child(island)
	new_game_button.pressed.connect(func() -> void: GameState.start_new_game())
	continue_button.pressed.connect(func() -> void: GameState.continue_game())
	quit_button.pressed.connect(func() -> void: GameState.quit_game())
	continue_button.disabled = not GameState.has_save()
	get_viewport().gui_focus_changed.connect(func(_control: Control) -> void: Sfx.play(self, &"ui_move"))
	(continue_button if not continue_button.disabled else new_game_button).grab_focus.call_deferred()


func _process(delta: float) -> void:
	_angle += orbit_speed * delta
	preview_camera.position = Vector3(cos(_angle) * orbit_radius, orbit_height, sin(_angle) * orbit_radius)
	preview_camera.look_at(Vector3(0, 0, -2))
