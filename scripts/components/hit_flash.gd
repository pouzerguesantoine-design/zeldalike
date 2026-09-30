class_name HitFlash
extends Node
## Flash blanc quand la Hurtbox encaisse un coup : tous les MeshInstance3D sous
## `visual_root` reçoivent un matériau blanc par-dessus pendant `duration`.

@export var hurtbox: Hurtbox
@export var visual_root: Node3D
@export var duration: float = 0.1
@export var flash_color: Color = Color.WHITE

var _material: StandardMaterial3D
var _time_left: float = 0.0


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = flash_color
	hurtbox.hit_received.connect(func(_info: DamageInfo) -> void: flash())


func flash() -> void:
	_time_left = duration
	_set_overlay(_material)


func is_flashing() -> bool:
	return _time_left > 0.0


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_set_overlay(null)


func _set_overlay(material: Material) -> void:
	for mesh in visual_root.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = material
