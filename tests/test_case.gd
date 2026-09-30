extends Node
## Base des scènes de test (tests/test_jalonX.tscn). Une scène de test hérite de ce
## script via `extends "res://tests/test_case.gd"` et redéfinit run().
##   Logique seule :     godot --headless --path . res://tests/test_jalonX.tscn
##   Avec capture PNG :  godot --path . res://tests/test_jalonX.tscn -- chemin/capture.png
## Code de sortie : 0 = tout est OK, 1 = échecs, 2 = délai dépassé.

## Un test bloqué échoue au bout de ce délai au lieu de tourner sans fin.
@export var timeout_seconds: float = 90.0

var failures: int = 0


func _ready() -> void:
	get_tree().create_timer(timeout_seconds).timeout.connect(_on_timeout)
	_run_and_quit.call_deferred()


## À redéfinir : le contenu du test.
func run() -> void:
	pass


func _run_and_quit() -> void:
	await run()
	print("\n%s : %d échec(s)" % ["SUCCÈS" if failures == 0 else "ÉCHEC", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _on_timeout() -> void:
	print("[ÉCHEC]  délai dépassé (%d s)" % timeout_seconds)
	get_tree().quit(2)


func check(condition: bool, label: String) -> void:
	print(("  [OK]     " if condition else "  [ÉCHEC]  ") + label)
	if not condition:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Instancie le niveau principal comme enfant du test et renvoie son joueur.
func load_main() -> Node:
	var main: Node = load("res://scene/world/main.tscn").instantiate()
	add_child(main)
	return main


func teleport(body: Node3D, position: Vector3) -> void:
	body.global_position = position
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
	body.reset_physics_interpolation()


## Simule un appui + relâchement d'action (passe par _unhandled_input).
func send_action(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


## Enregistre une capture si un chemin est passé après « -- » (et si le rendu est actif).
func save_screenshot_if_requested() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args[0])
	print("  capture : ", args[0])


## Supprime un fichier user:// créé par un test.
func delete_user_file(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
