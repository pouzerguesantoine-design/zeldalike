extends SceneTree
## Génère l'icône Windows du jeu (assets/textures/icon.ico) à partir du logo SVG :
## une image PNG par taille (16 à 256 px) regroupées dans un fichier .ico ; et le logo de
## l'écran de démarrage (assets/textures/logo.png, le splash n'accepte que le PNG). Lancer :
##   godot --headless --path . -s res://tools/godot/make_icon.gd

const LOGO := "res://assets/textures/logo.svg"
const OUTPUT := "res://assets/textures/icon.ico"
const SPLASH := "res://assets/textures/logo.png"
const SIZES: Array[int] = [16, 24, 32, 48, 64, 128, 256]
const LOGO_SIZE := 256.0


func _initialize() -> void:
	var svg := FileAccess.get_file_as_string(LOGO)
	var pngs: Array[PackedByteArray] = []
	for size in SIZES:
		var image := Image.new()
		image.load_svg_from_string(svg, size / LOGO_SIZE)
		pngs.append(image.save_png_to_buffer())
		if size == 256:
			image.save_png(ProjectSettings.globalize_path(SPLASH))
	# En-tête ICO (petit-boutiste) : réservé, type 1 = icône, nombre d'images.
	var out := StreamPeerBuffer.new()
	out.put_u16(0)
	out.put_u16(1)
	out.put_u16(SIZES.size())
	var offset := 6 + 16 * SIZES.size()
	for i in SIZES.size():
		var size := SIZES[i]
		out.put_u8(size % 256)  # 256 s'écrit 0
		out.put_u8(size % 256)
		out.put_u8(0)  # pas de palette
		out.put_u8(0)
		out.put_u16(1)  # plans
		out.put_u16(32)  # bits par pixel
		out.put_u32(pngs[i].size())
		out.put_u32(offset)
		offset += pngs[i].size()
	for png in pngs:
		out.put_data(png)
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_buffer(out.data_array)
	file.close()
	print("icône : ", OUTPUT, " (", out.data_array.size(), " octets)")
	quit()
