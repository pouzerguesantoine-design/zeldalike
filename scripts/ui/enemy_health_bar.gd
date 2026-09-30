class_name EnemyHealthBar
extends Sprite3D
## Barre de vie 3D au-dessus d'un ennemi (SubViewport rendu dans un Sprite3D en billboard).
## Cachée au départ : elle apparaît après le premier coup reçu ou pendant le lock-on.
## La barre rouge descend en douceur, suivie d'une « barre fantôme » claire retardée.

@export var smooth_duration: float = 0.2
@export var ghost_delay: float = 0.35
@export var ghost_duration: float = 0.4

var _health: HealthComponent
var _enemy: Node3D
var _revealed: bool = false
var _locked_on: bool = false
var _tween: Tween

@onready var bar: ProgressBar = $SubViewport/Ghost/Bar
@onready var ghost: ProgressBar = $SubViewport/Ghost


func _ready() -> void:
	visible = false
	EventBus.lock_on_target_changed.connect(_on_lock_on_target_changed)


## À appeler par l'ennemi une fois ses composants prêts.
func setup(health: HealthComponent, enemy: Node3D) -> void:
	_health = health
	_enemy = enemy
	bar.value = 100.0
	ghost.value = 100.0
	health.health_changed.connect(_on_health_changed)
	health.died.connect(func() -> void: visible = false)


func get_ratio() -> float:
	return bar.value / 100.0


func _on_health_changed(hp: int, max_hp: int) -> void:
	var percent := 100.0 * hp / maxf(max_hp, 1)
	_revealed = true
	_update_visibility()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(bar, "value", percent, smooth_duration)
	_tween.tween_property(ghost, "value", percent, ghost_duration).set_delay(ghost_delay)


func _on_lock_on_target_changed(target: Node3D) -> void:
	_locked_on = target != null and target == _enemy
	_update_visibility()


func _update_visibility() -> void:
	visible = (_revealed or _locked_on) and _health != null and not _health.is_dead()
