class_name InventoryMenu
extends MenuScreen
## Inventaire (touche I, jeu en pause), navigable à la souris ET au clavier
## (flèches + Entrée ; Tab change d'onglet).
##   Objets      : grille (icône + quantité), fiche de l'objet, Utiliser / Équiper / Jeter.
##   Équipement  : arme équipée, armes possédées, comparaison ▲▼ avant d'équiper, stats.

const PICKUP_SCENE := preload("res://scene/items/pickup.tscn")
const TYPE_NAMES := {
	ItemData.ItemType.CONSOMMABLE: "Consommable",
	ItemData.ItemType.ARME: "Arme",
	ItemData.ItemType.CLE: "Objet clé",
	ItemData.ItemType.MATERIAU: "Matériau",
	ItemData.ItemType.MONNAIE: "Monnaie",
}
const DAMAGE_TYPE_NAMES := ["Physique", "Feu", "Glace", "Foudre", "Magie"]
const BETTER_COLOR := Color(0.45, 1.0, 0.45)
const WORSE_COLOR := Color(1.0, 0.45, 0.4)
const SAME_COLOR := Color(0.75, 0.75, 0.75)
## Ordre d'affichage des types dans la grille.
const TYPE_ORDER := [ItemData.ItemType.ARME, ItemData.ItemType.CONSOMMABLE, ItemData.ItemType.CLE,
	ItemData.ItemType.MATERIAU]
const SLOT_SIZE := Vector2(84, 84)

var selected_item: ItemData
var selected_weapon: ItemData

@onready var tabs: TabContainer = %Tabs
@onready var item_grid: GridContainer = %ItemGrid
@onready var empty_label: Label = %EmptyLabel
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_name: Label = %DetailName
@onready var detail_type: Label = %DetailType
@onready var detail_description: Label = %DetailDescription
@onready var detail_effect: Label = %DetailEffect
@onready var use_button: Button = %UseButton
@onready var equip_button: Button = %EquipButton
@onready var drop_button: Button = %DropButton
@onready var message_label: Label = %MessageLabel
@onready var rupee_label: Label = %RupeeLabel
@onready var equipped_icon: TextureRect = %EquippedIcon
@onready var equipped_name: Label = %EquippedName
@onready var weapon_list: VBoxContainer = %WeaponList
@onready var compare_title: Label = %CompareTitle
@onready var compare_grid: GridContainer = %CompareGrid
@onready var equip_weapon_button: Button = %EquipWeaponButton
@onready var stats_grid: GridContainer = %StatsGrid


func _ready() -> void:
	super._ready()
	use_button.pressed.connect(use_selected)
	equip_button.pressed.connect(equip_selected)
	drop_button.pressed.connect(drop_selected)
	equip_weapon_button.pressed.connect(func() -> void: _equip(selected_weapon))
	tabs.tab_changed.connect(func(_tab: int) -> void: _focus_current_tab())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Tab (action lock_on) passe d'un onglet à l'autre.
	if event.is_action_pressed("lock_on"):
		tabs.current_tab = (tabs.current_tab + 1) % tabs.get_tab_count()
		get_viewport().set_input_as_handled()


func _on_opened() -> void:
	message_label.text = ""
	refresh()
	_focus_current_tab()


func refresh() -> void:
	rupee_label.text = "Rubis : %d" % GameState.rupees
	_refresh_items()
	_refresh_equipment_tab()


# --- Onglet Objets ---------------------------------------------------------------

func get_slots() -> Array[Button]:
	var slots: Array[Button] = []
	for child in item_grid.get_children():
		if child is Button and not child.is_queued_for_deletion():
			slots.append(child)
	return slots


func _sorted_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item_id in GameState.inventory:
		var item: ItemData = GameState.items.get(item_id)
		if item:
			result.append(item)
	result.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		var order_a := TYPE_ORDER.find(a.type)
		var order_b := TYPE_ORDER.find(b.type)
		return order_a < order_b if order_a != order_b else a.display_name < b.display_name)
	return result


func _refresh_items() -> void:
	for child in item_grid.get_children():
		item_grid.remove_child(child)
		child.queue_free()
	var items := _sorted_items()
	empty_label.visible = items.is_empty()
	for item in items:
		var slot := Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.icon = item.icon
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var count := GameState.get_item_count(item.id)
		slot.text = "×%d" % count if count > 1 else ""
		slot.tooltip_text = item.display_name
		if item.weapon and item.weapon == GameState.equipped_weapon:
			slot.text = "Équipée"
			slot.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.35))
		slot.focus_entered.connect(_select_item.bind(item))
		slot.pressed.connect(_select_item.bind(item))
		item_grid.add_child(slot)
	if selected_item == null or not items.has(selected_item):
		selected_item = items[0] if not items.is_empty() else null
	_refresh_details()


func _select_item(item: ItemData) -> void:
	selected_item = item
	_refresh_details()


func _refresh_details() -> void:
	var item := selected_item
	var has_item := item != null
	for control: Control in [detail_icon, detail_name, detail_type, detail_description, detail_effect,
			use_button, equip_button, drop_button]:
		control.visible = has_item
	if not has_item:
		return
	detail_icon.texture = item.icon
	detail_name.text = item.display_name
	detail_type.text = "%s — ×%d" % [TYPE_NAMES.get(item.type, ""), GameState.get_item_count(item.id)]
	detail_description.text = item.description
	detail_effect.text = _effect_text(item)
	use_button.disabled = not _can_use(item)
	equip_button.disabled = item.weapon == null or item.weapon == GameState.equipped_weapon
	drop_button.disabled = not _can_drop(item)


func _effect_text(item: ItemData) -> String:
	if item.heal_amount > 0:
		return "Effet : rend %d PV" % item.heal_amount
	if item.weapon:
		return "Dégâts : %s  •  %s" % [_format_number(_weapon_damage(item.weapon)), DAMAGE_TYPE_NAMES[item.weapon.damage_type]]
	if item.type == ItemData.ItemType.CLE:
		return "Ouvre une porte verrouillée"
	return "Valeur : %d rubis" % item.value if item.value > 0 else ""


func _can_use(item: ItemData) -> bool:
	return item.type == ItemData.ItemType.CONSOMMABLE and item.heal_amount > 0


func _can_drop(item: ItemData) -> bool:
	if item.type == ItemData.ItemType.CLE:
		return false
	return not (item.weapon and item.weapon == GameState.equipped_weapon)


## Utiliser : pour l'instant, les soins (potion).
func use_selected() -> void:
	var item := selected_item
	if item == null or not _can_use(item):
		return
	var player := _player()
	if player == null:
		return
	if player.health.hp >= player.health.max_hp:
		_message("Votre vie est déjà au maximum.")
		return
	player.health.heal(item.heal_amount)
	GameState.remove_item(item.id, 1)
	_message("Vous récupérez %d PV." % item.heal_amount)
	refresh()
	_focus_after_change()


func equip_selected() -> void:
	if selected_item and selected_item.weapon:
		_equip(selected_item)


## Jeter : l'objet tombe devant le joueur (il faudra marcher dessus pour le reprendre).
func drop_selected() -> void:
	var item := selected_item
	var player := _player()
	if item == null or player == null or not _can_drop(item):
		return
	GameState.remove_item(item.id, 1)
	var pickup := PICKUP_SCENE.instantiate() as Pickup
	pickup.item = item
	pickup.magnet_enabled = false
	pickup.pickup_delay = 1.5
	player.get_parent().add_child(pickup)
	pickup.global_position = player.global_position + player.get_forward() * 1.8
	_message("%s jeté(e)." % item.display_name)
	refresh()
	_focus_after_change()


# --- Onglet Équipement -----------------------------------------------------------

func _owned_weapons() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in _sorted_items():
		if item.weapon:
			result.append(item)
	return result


func _refresh_equipment_tab() -> void:
	var equipped := GameState.equipped_weapon
	equipped_icon.texture = equipped.icon if equipped else null
	equipped_name.text = equipped.display_name if equipped else "Aucune"
	for child in weapon_list.get_children():
		weapon_list.remove_child(child)
		child.queue_free()
	var weapons := _owned_weapons()
	for item in weapons:
		var button := Button.new()
		button.text = item.display_name + ("  (équipée)" if item.weapon == equipped else "")
		button.icon = item.icon
		button.expand_icon = true
		button.custom_minimum_size = Vector2(0, 52)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_entered.connect(_select_weapon.bind(item))
		button.pressed.connect(_select_weapon.bind(item))
		weapon_list.add_child(button)
	if selected_weapon == null or not weapons.has(selected_weapon):
		selected_weapon = weapons[0] if not weapons.is_empty() else null
	_refresh_comparison()
	_refresh_stats()


func _select_weapon(item: ItemData) -> void:
	selected_weapon = item
	_refresh_comparison()


## Tableau : statistique | valeur de l'arme choisie | ▲ / ▼ par rapport à l'arme équipée.
func _refresh_comparison() -> void:
	for child in compare_grid.get_children():
		compare_grid.remove_child(child)
		child.queue_free()
	var candidate := selected_weapon.weapon if selected_weapon else null
	var equipped := GameState.equipped_weapon
	equip_weapon_button.disabled = candidate == null or candidate == equipped
	if candidate == null:
		compare_title.text = "Aucune arme"
		return
	compare_title.text = "%s  vs  %s" % [candidate.display_name, equipped.display_name if equipped else "—"]
	_add_comparison_row("Dégâts", _weapon_damage(candidate), _weapon_damage(equipped) if equipped else 0.0, true)
	_add_comparison_row("Vitesse", candidate.attack_speed, equipped.attack_speed if equipped else 0.0, true)
	_add_comparison_row("Portée", candidate.reach, equipped.reach if equipped else 0.0, true)
	_add_comparison_row("Critique %", candidate.critical_chance * 100.0, equipped.critical_chance * 100.0 if equipped else 0.0, true)
	_add_comparison_row("Endurance / coup", candidate.stamina_cost, equipped.stamina_cost if equipped else 0.0, false)
	_add_row(compare_grid, "Type", DAMAGE_TYPE_NAMES[candidate.damage_type], "", SAME_COLOR)


## Renvoie la flèche affichée (utile aux tests) et ajoute la ligne.
func _add_comparison_row(stat: String, value: float, reference: float, higher_is_better: bool) -> String:
	var arrow := "="
	var color := SAME_COLOR
	if not is_equal_approx(value, reference):
		var better := (value > reference) == higher_is_better
		arrow = "▲" if value > reference else "▼"
		color = BETTER_COLOR if better else WORSE_COLOR
	_add_row(compare_grid, stat, _format_number(value), arrow, color)
	return arrow


func _add_row(grid: GridContainer, title: String, value: String, arrow: String, color: Color) -> void:
	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(value_label)
	if grid.columns >= 3:
		var arrow_label := Label.new()
		arrow_label.text = arrow
		arrow_label.custom_minimum_size = Vector2(28, 0)
		arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow_label.add_theme_color_override(&"font_color", color)
		grid.add_child(arrow_label)


## Flèches affichées dans la comparaison, par statistique (pour les tests).
func get_comparison_arrows() -> Dictionary:
	var result := {}
	var cells := compare_grid.get_children()
	for i in range(0, cells.size() - 2, 3):
		result[(cells[i] as Label).text] = (cells[i + 2] as Label).text
	return result


func _refresh_stats() -> void:
	for child in stats_grid.get_children():
		stats_grid.remove_child(child)
		child.queue_free()
	var stats := GameState.player_stats
	var player := _player()
	var rows := [
		["Niveau", str(stats.level)],
		["Expérience", "%d / %d" % [stats.xp, stats.get_xp_to_next()]],
		["Vie", "%d / %d" % [player.health.hp if player else stats.max_hp, stats.max_hp]],
		["Endurance", str(roundi(stats.max_stamina))],
		["Mana", str(roundi(stats.max_mana))],
		["Force", str(stats.force)],
		["Défense", str(stats.defense)],
		["Vitesse", str(stats.speed)],
	]
	for row in rows:
		_add_row(stats_grid, row[0], row[1], "", SAME_COLOR)


func _equip(item: ItemData) -> void:
	if item == null or item.weapon == null:
		return
	GameState.equip_weapon(item.weapon)
	_message("%s équipée." % item.display_name)
	refresh()
	_focus_after_change()


# --- Outils ----------------------------------------------------------------------

## Dégâts de base d'un coup (sans Force ni combo) : base × multiplicateur.
func _weapon_damage(weapon: WeaponData) -> float:
	return weapon.base_damage * weapon.damage_multiplier


func _format_number(value: float) -> String:
	return String.num(value, 2)


func _message(text: String) -> void:
	message_label.text = text


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _focus_current_tab() -> void:
	if not visible:
		return
	if tabs.current_tab == 0:
		var slots := get_slots()
		if not slots.is_empty():
			slots[0].grab_focus()
		else:
			tabs.get_tab_bar().grab_focus()
	else:
		if weapon_list.get_child_count() > 0:
			(weapon_list.get_child(0) as Control).grab_focus()


## Après une action, on garde le focus sur l'objet sélectionné s'il existe encore.
func _focus_after_change() -> void:
	if tabs.current_tab != 0:
		_focus_current_tab()
		return
	for slot in get_slots():
		if slot.tooltip_text == (selected_item.display_name if selected_item else ""):
			slot.grab_focus()
			return
	_focus_current_tab()
