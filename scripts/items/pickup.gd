class_name Pickup
extends Area3D
## Objet ramassable (calque 6 « pickups », masque 2 « player »). Il flotte, tourne, et se
## ramasse au contact du joueur. Les objets « use_on_pickup » (cœurs) sont consommés tout
## de suite ; les autres vont dans l'inventaire de GameState.
## (Aspiration vers le joueur et texte « +1 … » : jalon 6.)

@export var item: ItemData
@export var quantity: int = 1
@export var bob_height: float = 0.12
@export var bob_speed: float = 2.5
@export var spin_speed: float = 2.0
## Délai avant de pouvoir être ramassé (laisse le temps de voir le butin jaillir).
@export var pickup_delay: float = 0.4
@export var pop_duration: float = 0.45
@export var pop_height: float = 1.0

var _age: float = 0.0
var _base_height: float

@onready var sprite: Sprite3D = $Sprite3D


func _ready() -> void:
	sprite.texture = item.icon
	_base_height = sprite.position.y


func _process(delta: float) -> void:
	_age += delta
	sprite.position.y = _base_height + sin(_age * bob_speed) * bob_height
	sprite.rotation.y += spin_speed * delta


func _physics_process(_delta: float) -> void:
	if _age < pickup_delay:
		return
	for body in get_overlapping_bodies():
		if body is Player and not (body as Player).health.is_dead():
			_collect(body as Player)
			return


## Fait jaillir l'objet de sa position actuelle jusqu'à `target` en arc de cercle.
func pop_to(target: Vector3) -> void:
	var start := global_position
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		global_position = start.lerp(target, t) + Vector3.UP * sin(t * PI) * pop_height,
		0.0, 1.0, pop_duration)


func _collect(player: Player) -> void:
	set_physics_process(false)
	if item.use_on_pickup:
		player.health.heal(item.heal_amount * quantity)
		EventBus.item_picked_up.emit(item, quantity)
	else:
		GameState.add_item(item, quantity)
	queue_free()
