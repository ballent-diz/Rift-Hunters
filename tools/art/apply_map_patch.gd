extends SceneTree
## Réinsère une retouche locale générée, sans modifier le reste de la carte.
## --base=<image agrandie> --patch=<retouche> --out=<PNG complet>
const REGION := Rect2i(2780, 1303, 695, 695)
const FEATHER := 32.0


func _initialize() -> void:
	var values: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var separator: int = arg.find("=")
		if separator >= 0:
			values[arg.substr(2, separator - 2)] = arg.substr(separator + 1)
	if not values.has("base") or not values.has("patch") or not values.has("out"):
		printerr("Arguments requis : --base, --patch, --out")
		quit(1)
		return
	var base: Image = Image.load_from_file(ProjectSettings.globalize_path(values["base"]))
	var patch: Image = Image.load_from_file(ProjectSettings.globalize_path(values["patch"]))
	if base == null or patch == null or not Rect2i(Vector2i.ZERO, base.get_size()).encloses(REGION):
		printerr("Images absentes ou région hors de la carte")
		quit(1)
		return
	base.convert(Image.FORMAT_RGBA8)
	patch.convert(Image.FORMAT_RGBA8)
	patch.resize(REGION.size.x, REGION.size.y, Image.INTERPOLATE_LANCZOS)
	for y: int in REGION.size.y:
		for x: int in REGION.size.x:
			var edge: float = minf(minf(x, REGION.size.x - 1 - x), minf(y, REGION.size.y - 1 - y))
			var amount: float = clampf(edge / FEATHER, 0, 1)
			var point: Vector2i = REGION.position + Vector2i(x, y)
			base.set_pixelv(point, base.get_pixelv(point).lerp(patch.get_pixel(x, y), amount))
	var result: Error = base.save_png(ProjectSettings.globalize_path(values["out"]))
	print("Retouche locale assemblée : ", values["out"])
	quit(0 if result == OK else 1)
