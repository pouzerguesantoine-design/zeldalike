class_name Pickup
extends Area3D
## Objet ramassable (calque 6 « pickups », masque 2 « player »). Il flotte, tourne, est
## aspiré vers le joueur à courte distance et se ramasse au contact en affichant
## « +1 Potion ». Les objets « use_on_pickup » (cœurs) sont consommés tout de suite ;
## les autres vont dans l'inventaire de GameState.

@export var item: ItemData
@export var quantity: int = 1
@export var bob_height: float = 0.12
@export var bob_speed: float = 2.5
@export var spin_speed: float = 2.0
## Délai avant de pouvoir être ramassé (laisse le temps de voir le butin jaillir).
@export var pickup_delay: float = 0.4
@export var pop_duration: float = 0.45
@export var pop_height: float = 1.0
@export_group("Aspiration")
## Faux pour un objet jeté par le joueur : il faut marcher dessus pour le reprendre.
@export var magnet_enabled: bool = true
## Distance à laquelle l'objet file vers le joueur.
@export var magnet_radius: float = 2.5
@export var magnet_speed: float = 7.0
@export var magnet_acceleration: float = 25.0

const SPARKLE_FX := preload("res://scene/fx/pickup_sparkle.tscn")

var _age: float = 0.0
var _base_height: float
var _magnet_velocity: float = 0.0
var _pop_tween: Tween

@onready var sprite: Sprite3D = $Sprite3D


func _ready() -> void:
	sprite.texture = item.icon
	_base_height = sprite.position.y


func _process(delta: float) -> void:
	_age += delta
	sprite.position.y = _base_height + sin(_age * bob_speed) * bob_height
	sprite.rotation.y += spin_speed * delta


func _physics_process(delta: float) -> void:
	if _age < pickup_delay:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.health.is_dead():
		return
	for body in get_overlapping_bodies():
		if body == player:
			_collect(player)
			return
	# Aspiration : accélère vers le joueur quand il est assez près.
	var target := player.global_position + Vector3.UP * 0.4
	if magnet_enabled and global_position.distance_to(target) <= magnet_radius:
		if _pop_tween and _pop_tween.is_running():
			_pop_tween.kill()
		_magnet_velocity = minf(_magnet_velocity + magnet_acceleration * delta, magnet_speed)
		global_position = global_position.move_toward(target, _magnet_velocity * delta)
	else:
		_magnet_velocity = 0.0


## Fait jaillir l'objet de sa position actuelle jusqu'à `target` en arc de cercle.
func pop_to(target: Vector3) -> void:
	var start := global_position
	_pop_tween = create_tween()
	_pop_tween.tween_method(func(t: float) -> void:
		global_position = start.lerp(target, t) + Vector3.UP * sin(t * PI) * pop_height,
		0.0, 1.0, pop_duration)


func is_being_attracted() -> bool:
	return _magnet_velocity > 0.0


func _collect(player: Player) -> void:
	set_physics_process(false)
	if item.use_on_pickup:
		player.health.heal(item.heal_amount * quantity)
		EventBus.item_picked_up.emit(item, quantity)
	else:
		GameState.add_item(item, quantity)
	var color := Color(0.55, 1.0, 0.55) if item.type == ItemData.ItemType.MONNAIE else Color(1.0, 0.95, 0.7)
	var sound := &"pickup_item"
	if item.type == ItemData.ItemType.MONNAIE:
		sound = &"pickup_rupee"
	elif item.use_on_pickup:
		sound = &"pickup_heart"
	Sfx.play(self, sound)
	FxBurst.spawn(self, SPARKLE_FX, global_position + Vector3.UP * 0.5)
	FloatingText.spawn(get_tree(), "+%d %s" % [quantity, item.display_name], player.global_position + Vector3.UP * 2.2, color)
	queue_free()
