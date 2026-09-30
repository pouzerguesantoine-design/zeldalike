class_name LootTable
extends Resource
## Table de butin (fichiers .tres dans resources/loot_tables/).
## Tirage : `rolls` fois, on choisit une entrée au hasard selon les poids, puis elle
## donne son objet avec la probabilité `chance`, en quantité entre min et max.
## Les entrées de `guaranteed` sont, elles, testées une fois chacune avec leur `chance`.

@export var entries: Array[LootEntry] = []
@export var rolls: int = 1
## Entrées testées indépendamment à chaque mort (ex. rubis presque toujours donnés).
@export var guaranteed: Array[LootEntry] = []


## Renvoie une liste de {"item": ItemData, "quantity": int}, un objet par ligne.
func roll(rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var quantities: Dictionary[ItemData, int] = {}
	for entry in guaranteed:
		_try_entry(entry, rng, quantities)
	var total_weight := 0.0
	for entry in entries:
		total_weight += maxf(entry.weight, 0.0)
	if total_weight > 0.0:
		for i in rolls:
			_try_entry(_pick_weighted(rng.randf() * total_weight), rng, quantities)
	var result: Array[Dictionary] = []
	for item in quantities:
		result.append({"item": item, "quantity": quantities[item]})
	return result


func _pick_weighted(threshold: float) -> LootEntry:
	for entry in entries:
		threshold -= maxf(entry.weight, 0.0)
		if threshold <= 0.0:
			return entry
	return entries.back()


func _try_entry(entry: LootEntry, rng: RandomNumberGenerator, quantities: Dictionary[ItemData, int]) -> void:
	if entry == null or entry.item == null or rng.randf() >= entry.chance:
		return
	var quantity := rng.randi_range(entry.min_quantity, maxi(entry.min_quantity, entry.max_quantity))
	quantities[entry.item] = quantities.get(entry.item, 0) + quantity
