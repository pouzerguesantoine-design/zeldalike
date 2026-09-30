extends Node3D
## Script de niveau : cuit le maillage de navigation au chargement (à partir des
## collisions statiques enfants de la NavigationRegion3D), pour que les ennemis
## trouvent leur chemin autour des obstacles.

@onready var navigation_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	# Cuisson synchrone : le niveau de test est petit (quelques millisecondes).
	navigation_region.bake_navigation_mesh(false)
