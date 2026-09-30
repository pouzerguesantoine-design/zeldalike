class_name SavePoint
extends Node3D
## Point de sauvegarde (statue de cristal) : E pour sauvegarder. Comme les statues de
## Zelda, elle rend toute la vie, l'endurance et le mana. On y réapparaît après une mort
## (la position sauvegardée est celle du joueur, juste devant la statue).

@export var float_height: float = 0.12
@export var spin_speed: float = 1.2

var _time: float = 0.0

@onready var crystal: Node3D = $Crystal
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)


func _process(delta: float) -> void:
	_time += delta
	crystal.rotation.y += spin_speed * delta
	crystal.position.y = 1.55 + sin(_time * 2.0) * float_height


func _on_interacted(player: Player) -> void:
	player.apply_stats(true)
	var saved := GameState.save_game()
	var message := "Partie sauvegardée" if saved else "La sauvegarde a échoué"
	FloatingText.spawn(get_tree(), message, global_position + Vector3.UP * 2.6, Color(0.6, 0.95, 1.0))
	var tween := create_tween()
	tween.tween_property(crystal, "scale", Vector3.ONE * 1.4, 0.15)
	tween.tween_property(crystal, "scale", Vector3.ONE, 0.3)
