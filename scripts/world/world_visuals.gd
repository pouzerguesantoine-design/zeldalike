class_name WorldVisuals
extends WorldEnvironment
## Environnement de l'île selon la qualité graphique (GameState.graphics_quality) :
##   Bas    : sans GI, SSAO, brouillard volumétrique ni éclat ; ombres courtes et dures.
##   Moyen  : SSAO + éclat ; ombres douces.
##   Haut   : + SDFGI (lumière indirecte), brouillard volumétrique, ombres longues et douces.
## Tonemap ACES, étalonnage chaud et saturé et brouillard léger restent actifs partout.

@export var sun: DirectionalLight3D

const SHADOW_DISTANCE: Array[float] = [45.0, 70.0, 100.0]
## Taille apparente du soleil (adoucit les ombres) par qualité.
const SUN_ANGULAR_SIZE: Array[float] = [0.0, 0.5, 1.0]


func _ready() -> void:
	GameState.graphics_quality_changed.connect(apply_quality)
	apply_quality(GameState.graphics_quality)


func apply_quality(quality: int) -> void:
	var high := quality == GameState.Quality.HAUT
	var medium_or_more := quality >= GameState.Quality.MOYEN
	environment.sdfgi_enabled = high
	environment.volumetric_fog_enabled = high
	environment.ssao_enabled = medium_or_more
	environment.glow_enabled = medium_or_more
	if sun:
		sun.directional_shadow_max_distance = SHADOW_DISTANCE[quality]
		sun.light_angular_distance = SUN_ANGULAR_SIZE[quality]
