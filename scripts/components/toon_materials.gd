class_name ToonMaterials
extends RefCounted
## Convertit les matériaux importés des .glb (StandardMaterial3D) en cel-shading :
## `ToonMaterials.apply(nœud)` parcourt les MeshInstance3D et remplace chaque surface par un
## ShaderMaterial (assets/shaders/toon.gdshader) de même couleur ; le feuillage des arbres
## (« Foliage », « Needles ») reçoit la variante qui ondule au vent. Les matériaux
## transparents (gelée du Slime…) gardent leur matériau, passé en éclairage « toon ».
## Les conversions sont mises en cache : un matériau d'origine = un matériau converti.

const TOON_SHADER := preload("res://assets/shaders/toon.gdshader")
const FOLIAGE_SHADER := preload("res://assets/shaders/toon_foliage.gdshader")
const FOLIAGE_NAMES: Array[String] = ["Foliage", "Needles"]

static var _cache: Dictionary[int, Material] = {}


static func apply(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var foliage := FOLIAGE_NAMES.any(func(part: String) -> bool: return String(mesh_instance.name).contains(part))
		for surface in mesh_instance.mesh.get_surface_count():
			var converted := convert_material(mesh_instance.get_active_material(surface), foliage)
			if converted:
				mesh_instance.set_surface_override_material(surface, converted)


static func convert_material(material: Material, foliage: bool = false) -> Material:
	var standard := material as BaseMaterial3D
	if standard == null:
		return null
	var key := standard.get_instance_id() * 2 + (1 if foliage else 0)
	if _cache.has(key):
		return _cache[key]
	var result: Material
	if standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		var copy := standard.duplicate() as BaseMaterial3D
		copy.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		copy.specular_mode = BaseMaterial3D.SPECULAR_TOON
		result = copy
	else:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = FOLIAGE_SHADER if foliage else TOON_SHADER
		shader_material.set_shader_parameter(&"albedo", standard.albedo_color)
		if standard.emission_enabled and not foliage:
			shader_material.set_shader_parameter(&"emission_color", standard.emission)
			shader_material.set_shader_parameter(&"emission_energy", standard.emission_energy_multiplier)
		result = shader_material
	_cache[key] = result
	return result


static func is_toon(material: Material) -> bool:
	var shader_material := material as ShaderMaterial
	return shader_material != null and shader_material.shader in [TOON_SHADER, FOLIAGE_SHADER]
