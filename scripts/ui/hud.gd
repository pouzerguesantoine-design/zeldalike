class_name HUD
extends CanvasLayer
## Interface en jeu :
##   en haut à gauche : cœurs (10 PV par cœur, remplis par quarts), endurance, mana ;
##   en haut à droite : rubis ; en bas à gauche : niveau + barre d'XP ;
##   en bas à droite : arme équipée et sort ; lock-on : bandes noires + nom de la cible.

const HEART_FULL := preload("res://assets/textures/ui/heart_full.svg")
const HEART_EMPTY := preload("res://assets/textures/ui/heart_empty.svg")
const HP_PER_HEART := 10
const STAMINA_COLOR := Color(0.36, 0.86, 0.36)
const STAMINA_EXHAUSTED_COLOR := Color(0.95, 0.3, 0.25)

@export_group("Endurance")
## La jauge disparaît après être restée pleine ce délai (comme la roue de BotW).
@export var stamina_hide_delay: float = 1.2
@export var ghost_delay: float = 0.35
@export var ghost_duration: float = 0.45
@export_group("Lock-on")
@export var letterbox_height: float = 56.0
@export var letterbox_duration: float = 0.25

var _player: Player
var _hearts: Array[TextureProgressBar] = []
var _displayed_rupees: float = 0.0
var _stamina_full_time: float = 0.0
var _stamina_tween: Tween
var _mana_tween: Tween
var _letterbox_tween: Tween
var _time: float = 0.0

@onready var hearts_box: HBoxContainer = %Hearts
@onready var stamina_group: Control = %StaminaGroup
@onready var stamina_ghost: ProgressBar = %StaminaGhost
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var mana_bar: ProgressBar = %ManaBar
@onready var rupee_label: Label = %RupeeLabel
@onready var level_label: Label = %LevelLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var xp_label: Label = %XpLabel
@onready var weapon_icon: TextureRect = %WeaponIcon
@onready var weapon_label: Label = %WeaponLabel
@onready var spell_icon: TextureRect = %SpellIcon
@onready var spell_label: Label = %SpellLabel
@onready var letterbox_top: ColorRect = %LetterboxTop
@onready var letterbox_bottom: ColorRect = %LetterboxBottom
@onready var target_label: Label = %TargetLabel


func _ready() -> void:
	_set_letterbox(0.0)
	target_label.visible = false
	# Le joueur est prêt après nous (ordre de l'arbre) : on attend une image.
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return
	_player.health.health_changed.connect(_on_health_changed)
	_player.stamina.stamina_changed.connect(_on_stamina_changed)
	_player.mana.mana_changed.connect(_on_mana_changed)
	GameState.stats_changed.connect(_refresh_level)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.equipment_changed.connect(func(_weapon: WeaponData) -> void: _refresh_equipment())
	EventBus.lock_on_target_changed.connect(_on_lock_on_target_changed)
	_on_health_changed(_player.health.hp, _player.health.max_hp)
	_on_stamina_changed(_player.stamina.stamina, _player.stamina.max_stamina)
	_on_mana_changed(_player.mana.mana, _player.mana.max_mana)
	_refresh_level()
	_displayed_rupees = GameState.rupees
	rupee_label.text = "%03d" % GameState.rupees
	_refresh_equipment()


func _process(delta: float) -> void:
	_time += delta
	# Compteur de rubis qui défile vers la vraie valeur.
	if not is_equal_approx(_displayed_rupees, GameState.rupees):
		_displayed_rupees = move_toward(_displayed_rupees, GameState.rupees, maxf(20.0, absf(GameState.rupees - _displayed_rupees) * 4.0) * delta)
		rupee_label.text = "%03d" % roundi(_displayed_rupees)
	# Endurance : s'efface quand elle reste pleine.
	if _player and _player.stamina.stamina >= _player.stamina.max_stamina:
		_stamina_full_time += delta
	else:
		_stamina_full_time = 0.0
	var target_alpha := 0.0 if _stamina_full_time > stamina_hide_delay else 1.0
	stamina_group.modulate.a = move_toward(stamina_group.modulate.a, target_alpha, delta * 3.0)
	# Vie basse : le dernier cœur bat.
	if _player:
		var low := _player.health.hp > 0 and _player.health.hp <= HP_PER_HEART
		for heart in _hearts:
			heart.scale = Vector2.ONE
		if low and not _hearts.is_empty():
			var pulse := 1.0 + 0.15 * absf(sin(_time * 6.0))
			var index := clampi(ceili(float(_player.health.hp) / HP_PER_HEART) - 1, 0, _hearts.size() - 1)
			_hearts[index].pivot_offset = _hearts[index].size / 2.0
			_hearts[index].scale = Vector2.ONE * pulse


# --- Vie ---------------------------------------------------------------------

func get_heart_count() -> int:
	return _hearts.size()


## Remplissage d'un cœur (0 à 10).
func get_heart_value(index: int) -> float:
	return _hearts[index].value


func _on_health_changed(hp: int, max_hp: int) -> void:
	var count := ceili(float(max_hp) / HP_PER_HEART)
	while _hearts.size() < count:
		var heart := TextureProgressBar.new()
		heart.texture_under = HEART_EMPTY
		heart.texture_progress = HEART_FULL
		heart.fill_mode = TextureProgressBar.FILL_CLOCKWISE
		heart.max_value = HP_PER_HEART
		heart.step = 0.01
		hearts_box.add_child(heart)
		_hearts.append(heart)
	while _hearts.size() > count:
		_hearts.pop_back().queue_free()
	var previous_total := 0.0
	for heart in _hearts:
		previous_total += heart.value
	for i in _hearts.size():
		_hearts[i].value = clampf(hp - i * HP_PER_HEART, 0.0, HP_PER_HEART)
	if hp < previous_total:
		# Coup reçu : les cœurs clignotent en rouge.
		hearts_box.modulate = Color(1.0, 0.35, 0.35)
		create_tween().tween_property(hearts_box, "modulate", Color.WHITE, 0.35)


# --- Endurance et mana ---------------------------------------------------------

func _on_stamina_changed(value: float, max_value: float) -> void:
	var percent := 100.0 * value / maxf(max_value, 1.0)
	stamina_bar.value = percent
	var exhausted := _player != null and _player.stamina.is_exhausted
	(stamina_bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color = STAMINA_EXHAUSTED_COLOR if exhausted else STAMINA_COLOR
	if percent >= stamina_ghost.value:
		stamina_ghost.value = percent
		return
	# La barre fantôme reste en place tant que l'endurance baisse, puis rattrape la vraie
	# barre après un court délai (on voit ce que la dernière action a coûté).
	if _stamina_tween:
		_stamina_tween.kill()
	_stamina_tween = create_tween()
	_stamina_tween.tween_interval(ghost_delay)
	_stamina_tween.tween_property(stamina_ghost, "value", percent, ghost_duration)


func _on_mana_changed(value: float, max_value: float) -> void:
	var percent := 100.0 * value / maxf(max_value, 1.0)
	if _mana_tween:
		_mana_tween.kill()
	_mana_tween = create_tween()
	_mana_tween.tween_property(mana_bar, "value", percent, 0.15)


# --- Niveau, rubis, équipement ---------------------------------------------------

func _refresh_level() -> void:
	var stats := GameState.player_stats
	level_label.text = "Niv. %d" % stats.level
	xp_bar.max_value = stats.get_xp_to_next()
	xp_bar.value = stats.xp
	xp_label.text = "%d / %d XP" % [stats.xp, stats.get_xp_to_next()] if not stats.is_max_level() else "Niveau max"


func _on_inventory_changed() -> void:
	# Petit rebond du compteur quand des rubis arrivent.
	rupee_label.pivot_offset = rupee_label.size / 2.0
	rupee_label.scale = Vector2.ONE * 1.25
	create_tween().tween_property(rupee_label, "scale", Vector2.ONE, 0.25)


func _refresh_equipment() -> void:
	var weapon := GameState.equipped_weapon
	weapon_icon.texture = weapon.icon if weapon else null
	weapon_label.text = weapon.display_name if weapon else ""
	if _player and _player.spell:
		spell_icon.texture = _player.spell.icon
		spell_label.text = "%d PM" % _player.spell.mana_cost


# --- Lock-on ---------------------------------------------------------------------

func is_letterbox_visible() -> bool:
	return letterbox_top.size.y > 1.0


func _on_lock_on_target_changed(target: Node3D) -> void:
	var locked := target != null
	target_label.visible = locked
	if locked:
		var stats: Variant = target.get("stats")
		target_label.text = "◆ %s" % (stats.display_name if stats is EnemyStats else "Cible")
	if _letterbox_tween:
		_letterbox_tween.kill()
	_letterbox_tween = create_tween()
	_letterbox_tween.tween_method(_set_letterbox, letterbox_top.size.y, letterbox_height if locked else 0.0, letterbox_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_letterbox(height: float) -> void:
	letterbox_top.offset_bottom = height
	letterbox_bottom.offset_top = -height
