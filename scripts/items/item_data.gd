class_name ItemData
extends Resource
## Objet du jeu (un fichier .tres dans resources/items/, chargé par GameState).
## Utilisé par l'inventaire, les tables de loot et les objets ramassables.

## CLE = objet clé (« CLÉ »), MONNAIE = rubis.
enum ItemType { CONSOMMABLE, ARME, CLE, MATERIAU, MONNAIE }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var type: ItemType = ItemType.MATERIAU
@export var stackable: bool = true
@export var max_quantity: int = 99

@export_group("Effets")
## Vie rendue quand l'objet est utilisé (ou ramassé si use_on_pickup).
@export var heal_amount: int = 0
## Consommé immédiatement au ramassage au lieu d'aller dans l'inventaire (ex. cœur).
@export var use_on_pickup: bool = false
## Valeur en rubis (type MONNAIE) ou prix de revente.
@export var value: int = 0
## Arme correspondante (type ARME).
@export var weapon: WeaponData
