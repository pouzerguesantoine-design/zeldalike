extends Node
## Cuit le maillage de navigation de l'île et l'enregistre dans sa ressource
## (resources/navigation/island_navmesh.tres), comme le bouton « Précalculer le
## NavigationMesh » de l'éditeur. À relancer après toute modification du décor :
##   godot --headless --path . res://tools/godot/bake_navmesh.tscn
## (Lancé comme une scène, et non avec -s, pour que les autoloads existent.)

const LEVEL := "res://scene/world/island.tscn"


func _ready() -> void:
	var level: Node = load(LEVEL).instantiate()
	# On ne garde que le décor : les ennemis et le joueur n'influencent pas la cuisson.
	for node_name in ["Enemies", "Player"]:
		var node := level.get_node_or_null(NodePath(node_name))
		if node:
			level.remove_child(node)
			node.free()
	add_child(level)
	await get_tree().physics_frame
	var region := level.get_node("NavigationRegion3D") as NavigationRegion3D
	region.bake_navigation_mesh(false)
	var navmesh := region.navigation_mesh
	var error := ResourceSaver.save(navmesh, navmesh.resource_path)
	print("Navigation cuite : %d polygones → %s (%s)" % [navmesh.get_polygon_count(), navmesh.resource_path, error_string(error)])
	get_tree().quit(0 if error == OK and navmesh.get_polygon_count() > 0 else 1)
