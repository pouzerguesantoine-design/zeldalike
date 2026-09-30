extends Node3D
## Script de niveau.
## - L'île (scene/world/island.tscn) utilise un maillage de navigation CUIT À L'AVANCE
##   (resources/navigation/island_navmesh.tres, régénéré par tools/godot/bake_navmesh.tscn).
## - Le terrain d'entraînement (main.tscn) le cuit au chargement (`bake_navigation_on_ready`).

## Cuit la NavigationRegion3D au lancement (pratique pour un niveau de test qui change souvent).
@export var bake_navigation_on_ready: bool = true

@onready var navigation_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	if bake_navigation_on_ready:
		# Cuisson synchrone : quelques millisecondes pour un petit niveau.
		navigation_region.bake_navigation_mesh(false)
