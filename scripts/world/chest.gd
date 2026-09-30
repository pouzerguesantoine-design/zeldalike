class_name Chest
extends Node3D
## Coffre (scène héritée de chest.glb) : E pour l'ouvrir → animation « open », le butin
## tiré de la LootTable jaillit devant le coffre. L'état ouvert est sauvegardé
## (drapeau GameState « chest:<chest_id> »).

const PICKUP_SCENE := preload("res://scene/items/pickup.tscn")

## Identifiant unique dans le monde (sert à la sauvegarde).
@export var chest_id: StringName
@export var loot_table: LootTable
## Délai entre le début de l'ouverture et l'apparition du butin (secondes).
@export var loot_delay: float = 0.3

var is_open: bool = false

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(func(_player: Player) -> void: open())
	GameState.loaded.connect(_apply_saved_state)
	_apply_saved_state()


func open() -> void:
	if is_open:
		return
	_set_open(true)
	GameState.set_flag(_flag())
	anim.play(&"open")
	await get_tree().create_timer(loot_delay).timeout
	_spawn_loot()


func _spawn_loot() -> void:
	if loot_table == null:
		return
	var front := -global_basis.z.normalized()
	var side := global_basis.x.normalized()
	var drops := loot_table.roll()
	for i in drops.size():
		var pickup := PICKUP_SCENE.instantiate() as Pickup
		pickup.item = drops[i]["item"]
		pickup.quantity = drops[i]["quantity"]
		get_parent().add_child(pickup)
		pickup.global_position = global_position + Vector3.UP * 0.6
		var spread := (i - (drops.size() - 1) / 2.0) * 0.7
		pickup.pop_to(global_position + front * 1.3 + side * spread)


func _set_open(value: bool) -> void:
	is_open = value
	interactable.available = not value


## Remet l'état sauvegardé : couvercle ouvert (fin de l'animation) si le drapeau existe.
func _apply_saved_state() -> void:
	if GameState.has_flag(_flag()):
		_set_open(true)
		anim.play(&"open")
		anim.seek(anim.current_animation_length, true)
	elif is_open:
		# Chargement d'une sauvegarde où ce coffre était encore fermé : couvercle rabattu.
		_set_open(false)
		anim.play(&"open")
		anim.seek(0.0, true)
		anim.pause()


func _flag() -> StringName:
	return StringName("chest:%s" % chest_id)
