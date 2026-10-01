class_name DayNightCycle
extends Node
## Cycle jour / nuit simple : fait tourner le soleil et la lune, et fait varier les
## couleurs du ciel, de la lumière, de l'ambiance et du brouillard selon l'heure.
## Les nuits restent lisibles (clair de lune bleuté), comme dans Zelda.

signal hour_changed(hour: float)

@export var sun: DirectionalLight3D
@export var moon: DirectionalLight3D
@export var world_environment: WorldEnvironment
## Durée d'une journée complète (minutes réelles).
@export var day_length_minutes: float = 10.0
## Heure au lancement (0 à 24).
@export_range(0.0, 24.0) var hour: float = 9.5
## Faux : l'heure reste fixe (captures d'écran, tests).
@export var running: bool = true
@export var sun_max_energy: float = 1.3
@export var moon_energy: float = 0.4
## Orientation de la course du soleil (degrés autour de l'axe vertical).
@export var sun_azimuth_degrees: float = 35.0

# Couleurs par moment de la journée : [nuit, aube/crépuscule, jour].
const SKY_TOP: Array[Color] = [Color(0.03, 0.06, 0.17), Color(0.32, 0.4, 0.68), Color(0.2, 0.46, 0.88)]
const SKY_HORIZON: Array[Color] = [Color(0.1, 0.15, 0.3), Color(1.0, 0.62, 0.42), Color(0.66, 0.82, 0.96)]
const SUN_COLOR: Array[Color] = [Color(0.6, 0.7, 1.0), Color(1.0, 0.62, 0.38), Color(1.0, 0.95, 0.86)]
const FOG_COLOR: Array[Color] = [Color(0.1, 0.14, 0.26), Color(0.95, 0.7, 0.55), Color(0.72, 0.84, 0.96)]
const AMBIENT_ENERGY: Array[float] = [0.35, 0.5, 0.6]


func _ready() -> void:
	apply_hour()


func _process(delta: float) -> void:
	if running:
		set_hour(fmod(hour + delta * 24.0 / (day_length_minutes * 60.0), 24.0))


func set_hour(value: float) -> void:
	hour = fposmod(value, 24.0)
	apply_hour()
	hour_changed.emit(hour)


func is_night() -> bool:
	return hour < 5.5 or hour > 19.0


func apply_hour() -> void:
	# Hauteur du soleil : lever à 6 h, zénith à 12 h, coucher à 18 h.
	var day_progress := (hour - 6.0) / 12.0
	var elevation := sin(day_progress * PI)
	var sun_angle := day_progress * 180.0
	if sun:
		sun.rotation_degrees = Vector3(-sun_angle, sun_azimuth_degrees, 0.0)
		sun.light_energy = sun_max_energy * clampf(elevation * 2.0, 0.0, 1.0)
		sun.visible = sun.light_energy > 0.01
	if moon:
		moon.rotation_degrees = Vector3(-(sun_angle + 180.0), sun_azimuth_degrees + 20.0, 0.0)
		moon.light_energy = moon_energy * clampf(-elevation * 2.0, 0.0, 1.0)
		moon.visible = moon.light_energy > 0.01
	# Mélange nuit → aube → jour selon la hauteur du soleil.
	var daylight := clampf(elevation * 2.5, -1.0, 1.0)
	var weights := _blend_weights(daylight)
	if sun:
		sun.light_color = _mix(SUN_COLOR, weights)
	if world_environment:
		var environment := world_environment.environment
		environment.ambient_light_energy = _mix_float(AMBIENT_ENERGY, weights)
		environment.fog_light_color = _mix(FOG_COLOR, weights)
		environment.volumetric_fog_albedo = _mix(FOG_COLOR, weights).lightened(0.4)
		var sky := environment.sky.sky_material as ProceduralSkyMaterial if environment.sky else null
		if sky:
			sky.sky_top_color = _mix(SKY_TOP, weights)
			sky.sky_horizon_color = _mix(SKY_HORIZON, weights)
			sky.ground_horizon_color = sky.sky_horizon_color


## Poids [nuit, aube, jour] : -1 = nuit noire, 0 = horizon, 1 = plein jour.
func _blend_weights(daylight: float) -> Vector3:
	if daylight < 0.0:
		return Vector3(-daylight, 1.0 + daylight, 0.0)
	return Vector3(0.0, 1.0 - daylight, daylight)


func _mix(colors: Array[Color], weights: Vector3) -> Color:
	return colors[0] * weights.x + colors[1] * weights.y + colors[2] * weights.z


func _mix_float(values: Array[float], weights: Vector3) -> float:
	return values[0] * weights.x + values[1] * weights.y + values[2] * weights.z
