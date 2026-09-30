class_name LootEntry
extends Resource
## Une ligne d'une LootTable.

@export var item: ItemData
## Poids relatif lors du tirage d'une entrée (plus il est grand, plus elle sort souvent).
@export var weight: float = 1.0
@export var min_quantity: int = 1
@export var max_quantity: int = 1
## Probabilité que l'entrée tirée donne vraiment l'objet (0 à 1).
@export_range(0.0, 1.0) var chance: float = 1.0
