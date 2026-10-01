class_name Door
extends Node3D
## Porte (scène héritée de door.glb) : E pour l'ouvrir → animation « open » (la collision
## du battant suit l'animation). Si `required_key` est renseignée, il faut cet objet dans
## l'inventaire (consommé si `consume_key`). État sauvegardé : drapeau « door:<door_id> ».

@export var door_id: StringName
## Clé nécessaire (vide : porte libre).
@export var required_key: ItemData
@export var consume_key: bool = true

var is_open: bool = false

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.prompt_provider = _get_prompt
	interactable.interacted.connect(_on_interacted)
	GameState.loaded.connect(_apply_saved_state)
	_apply_saved_state()


func is_locked() -> bool:
	return required_key != null and not is_open


func _get_prompt() -> String:
	if required_key == null:
		return "Ouvrir"
	return "Déverrouiller" if GameState.get_item_count(required_key.id) > 0 else "Verrouillée"


func _on_interacted(_player: Player) -> void:
	var message_position := global_position + Vector3.UP * 2.4
	if required_key:
		if GameState.get_item_count(required_key.id) <= 0:
			Sfx.play(self, &"door_locked", global_position)
			FloatingText.spawn(get_tree(), "Il faut une %s !" % required_key.display_name.to_lower(),
				message_position, Color(1.0, 0.55, 0.45))
			return
		if consume_key:
			GameState.remove_item(required_key.id, 1)
		FloatingText.spawn(get_tree(), "Porte déverrouillée", message_position, Color(1.0, 0.9, 0.4))
	open()


func open() -> void:
	if is_open:
		return
	_set_open(true)
	GameState.set_flag(_flag())
	anim.play(&"open")
	Sfx.play(self, &"door_open", global_position)


func _set_open(value: bool) -> void:
	is_open = value
	interactable.available = not value


func _apply_saved_state() -> void:
	if GameState.has_flag(_flag()):
		_set_open(true)
		anim.play(&"open")
		anim.seek(anim.current_animation_length, true)


func _flag() -> StringName:
	return StringName("door:%s" % door_id)
