class_name GrassField
extends Node3D
## Herbe dense animée par le vent : des milliers de brins répartis sur le sol plat de l'île
## (rayons vers le bas : jamais sur les maisons, rochers, troncs, plages), regroupés en
## blocs MultiMeshInstance3D pour que la caméra n'affiche que ceux qui sont visibles.
## La densité dépend de la qualité graphique ; les brins s'écartent sous les pieds du joueur.

const GRASS_SHADER := preload("res://assets/shaders/grass.gdshader")
## Brins par m² selon la qualité (Bas, Moyen, Haut).
const DENSITY: Array[float] = [0.6, 2.5, 5.0]
## Distance d'affichage des blocs selon la qualité (m).
const VIEW_DISTANCE: Array[float] = [35.0, 55.0, 90.0]

@export var radius: float = 41.0
@export var chunk_size: float = 10.0
## Zones sans herbe (x, z, largeur, profondeur) : rivière, donjon…
@export var excluded_areas: Array[Rect2] = []
## Hauteur des brins (m) : à hauteur de cheville / mi-mollet.
@export var blade_height: Vector2 = Vector2(0.16, 0.34)
@export var seed_value: int = 7

var blade_count: int = 0

var _material: ShaderMaterial
var _player: Node3D


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = GRASS_SHADER
	GameState.graphics_quality_changed.connect(func(_quality: int) -> void: rebuild())
	# Le décor doit être dans l'espace physique avant de lancer les rayons.
	await get_tree().physics_frame
	rebuild()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	if _player:
		_material.set_shader_parameter(&"player_position", _player.global_position)


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	var quality := GameState.graphics_quality
	var spacing := 1.0 / sqrt(DENSITY[quality])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var space := get_world_3d().direct_space_state
	var chunks: Dictionary[Vector2i, Array] = {}
	blade_count = 0
	var steps := int(radius * 2.0 / spacing)
	for ix in steps:
		for iz in steps:
			var x := -radius + (ix + rng.randf()) * spacing
			var z := -radius + (iz + rng.randf()) * spacing
			if Vector2(x, z).length() > radius or _is_excluded(x, z):
				continue
			# Rayon vers le bas : seulement sur le sol plat (pas sur un décor ni la plage).
			var query := PhysicsRayQueryParameters3D.create(Vector3(x, 6.0, z), Vector3(x, -3.0, z), 1)
			var hit := space.intersect_ray(query)
			if hit.is_empty() or absf(hit.position.y) > 0.05:
				continue
			var key := Vector2i(floori(x / chunk_size), floori(z / chunk_size))
			if not chunks.has(key):
				chunks[key] = []
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(blade_height.x, blade_height.y) / 0.5)
			chunks[key].append(Transform3D(basis, Vector3(x, 0.0, z)))
			blade_count += 1
	var blade := _blade_mesh()
	for key in chunks:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = blade
		var transforms: Array = chunks[key]
		multimesh.instance_count = transforms.size()
		for i in transforms.size():
			multimesh.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = _material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = VIEW_DISTANCE[quality]
		instance.visibility_range_end_margin = 8.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(instance)


func _is_excluded(x: float, z: float) -> bool:
	for area in excluded_areas:
		if area.has_point(Vector2(x, z)):
			return true
	return false


## Un brin : bande effilée de 3 segments, haute de 0,5 m (UV.y = 0 au pied, 1 à la pointe).
static func _blade_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var segments := 3
	for i in segments + 1:
		var t := float(i) / segments
		var half_width := 0.035 * (1.0 - t)
		var bend := t * t * 0.08
		vertices.append(Vector3(-half_width, t * 0.5, bend))
		vertices.append(Vector3(half_width, t * 0.5, bend))
		uvs.append(Vector2(0.0, t))
		uvs.append(Vector2(1.0, t))
		normals.append(Vector3(0, 0.3, -1).normalized())
		normals.append(Vector3(0, 0.3, -1).normalized())
	var indices := PackedInt32Array()
	for i in segments:
		var a := i * 2
		indices.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
