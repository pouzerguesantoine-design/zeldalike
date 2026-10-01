extends SceneTree
## Assemble les captures avant / après côte à côte (avant à gauche, après à droite) :
## docs/screenshots/comparaison_<nom>.png. Lancer :
##   godot --headless --path . -s res://tools/godot/compare_screenshots.gd

const FOLDER := "res://docs/screenshots/"
const NAMES := ["village", "combat", "donjon", "inventaire", "titre"]
const HALF_WIDTH := 960
const GAP := 12


func _initialize() -> void:
	for shot_name: String in NAMES:
		var before := Image.load_from_file(ProjectSettings.globalize_path(FOLDER + "avant_%s.png" % shot_name))
		var after := Image.load_from_file(ProjectSettings.globalize_path(FOLDER + "apres_%s.png" % shot_name))
		if before == null or after == null:
			push_error("Capture manquante : %s" % shot_name)
			continue
		var height := int(before.get_height() * float(HALF_WIDTH) / before.get_width())
		before.resize(HALF_WIDTH, height, Image.INTERPOLATE_LANCZOS)
		after.resize(HALF_WIDTH, height, Image.INTERPOLATE_LANCZOS)
		var combined := Image.create(HALF_WIDTH * 2 + GAP, height, false, before.get_format())
		combined.fill(Color(1, 1, 1))
		combined.blit_rect(before, Rect2i(0, 0, HALF_WIDTH, height), Vector2i.ZERO)
		combined.blit_rect(after, Rect2i(0, 0, HALF_WIDTH, height), Vector2i(HALF_WIDTH + GAP, 0))
		var path := FOLDER + "comparaison_%s.png" % shot_name
		combined.save_png(ProjectSettings.globalize_path(path))
		print("comparaison : ", path)
	quit()
