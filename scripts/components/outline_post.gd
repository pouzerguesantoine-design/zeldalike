class_name OutlinePost
extends MeshInstance3D
## Quad plein écran collé à une caméra qui trace les contours encrés
## (assets/shaders/outline_post.gdshader). Masqué en qualité « Bas ».


func _ready() -> void:
	GameState.graphics_quality_changed.connect(_apply)
	_apply(GameState.graphics_quality)


func _apply(quality: int) -> void:
	visible = quality >= GameState.Quality.MOYEN
