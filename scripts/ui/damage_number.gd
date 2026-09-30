class_name DamageNumber
extends Label3D
## Chiffre de dégâts flottant : monte, puis s'efface. Couleur selon le type de dégâts ;
## les critiques sont plus gros, jaunes et suivis d'un « ! ».

const TYPE_COLORS: Dictionary[DamageInfo.DamageType, Color] = {
	DamageInfo.DamageType.PHYSIQUE: Color(1.0, 1.0, 1.0),
	DamageInfo.DamageType.FEU: Color(1.0, 0.55, 0.15),
	DamageInfo.DamageType.GLACE: Color(0.45, 0.8, 1.0),
	DamageInfo.DamageType.FOUDRE: Color(0.95, 0.95, 0.55),
	DamageInfo.DamageType.MAGIE: Color(0.75, 0.45, 1.0),
}
const CRITICAL_COLOR := Color(1.0, 0.85, 0.0)

@export var rise_height: float = 1.0
@export var duration: float = 0.9
@export var critical_scale: float = 1.6

## Coup à afficher (à renseigner avant add_child).
var info: DamageInfo


func _ready() -> void:
	text = str(info.amount)
	modulate = TYPE_COLORS.get(info.damage_type, Color.WHITE)
	if info.is_critical:
		text += " !"
		modulate = CRITICAL_COLOR
		font_size = roundi(font_size * critical_scale)

	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y + rise_height, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tween.tween_property(self, "outline_modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tween.chain().tween_callback(queue_free)
