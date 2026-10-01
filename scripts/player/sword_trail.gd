class_name SwordTrail
extends MeshInstance3D
## Traînée lumineuse derrière la lame pendant les attaques : à chaque image on note la
## position du pied et de la pointe de l'épée, puis on dessine un ruban qui s'efface
## (ImmediateMesh). Couleur selon le type de dégâts de l'arme équipée.

const TYPE_COLORS: Dictionary[DamageInfo.DamageType, Color] = {
	DamageInfo.DamageType.PHYSIQUE: Color(0.85, 0.95, 1.0),
	DamageInfo.DamageType.FEU: Color(1.0, 0.55, 0.15),
	DamageInfo.DamageType.GLACE: Color(0.5, 0.85, 1.0),
	DamageInfo.DamageType.FOUDRE: Color(1.0, 1.0, 0.5),
	DamageInfo.DamageType.MAGIE: Color(0.8, 0.5, 1.0),
}

## Durée de vie d'un point de la traînée (secondes).
@export var lifetime: float = 0.16
## Distance de la poignée au début / à la fin de la partie lumineuse (m).
@export var blade_start: float = 0.25
@export var blade_end: float = 1.05
@export var max_alpha: float = 0.75

## [pied, pointe, âge]
var _points: Array[Array] = []
var _immediate: ImmediateMesh

@onready var player: Player = owner as Player


func _ready() -> void:
	top_level = true
	_immediate = ImmediateMesh.new()
	mesh = _immediate
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material_override = material


func point_count() -> int:
	return _points.size()


func _physics_process(delta: float) -> void:
	global_transform = Transform3D.IDENTITY
	for point in _points:
		point[2] = float(point[2]) + delta
	_points = _points.filter(func(point: Array) -> bool: return float(point[2]) < lifetime)
	var attacking := player.state_machine.get_state_name() == &"Attack"
	if attacking and is_instance_valid(player.weapon_socket):
		var socket := player.weapon_socket.global_transform
		# La lame pointe vers -Z dans le repère de l'emplacement d'arme.
		_points.append([socket * Vector3(0, 0, -blade_start), socket * Vector3(0, 0, -blade_end), 0.0])
	_rebuild()


func _rebuild() -> void:
	_immediate.clear_surfaces()
	if _points.size() < 2:
		return
	var weapon := GameState.equipped_weapon
	var color: Color = TYPE_COLORS.get(weapon.damage_type if weapon else DamageInfo.DamageType.PHYSIQUE, Color.WHITE)
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for point in _points:
		var fade: float = 1.0 - float(point[2]) / lifetime
		_immediate.surface_set_color(Color(color, 0.0))
		_immediate.surface_add_vertex(point[0])
		_immediate.surface_set_color(Color(color, max_alpha * fade))
		_immediate.surface_add_vertex(point[1])
	_immediate.surface_end()
