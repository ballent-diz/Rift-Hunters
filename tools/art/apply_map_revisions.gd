extends SceneTree
## Assemble les retouches aux deux résolutions : champ de collision et présentation détaillée.
func _initialize() -> void:
	var out := ProjectSettings.globalize_path("user://map-revisions")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/art/map_revisions.json"))
	var factor: int = int(recipe.display_factor)
	for id: String in ["cascade_ruins", "storm_highlands"]:
		var folder := "map.three_rifts" if id == "cascade_ruins" else "map.storm_highlands"
		var base_path := "res://assets/concepts/incoming/" + folder + "/source/"
		var source: Image = Image.load_from_file(ProjectSettings.globalize_path(base_path + "map_detailed.png"))
		source.convert(Image.FORMAT_RGB8)
		var display: Image = source.duplicate()
		display.resize(source.get_width() * factor, source.get_height() * factor, Image.INTERPOLATE_LANCZOS)
		for job: Dictionary in recipe.jobs:
			if job.map != id:
				continue
			var patch: Image = Image.load_from_file(ProjectSettings.globalize_path(job.patch))
			patch.convert(Image.FORMAT_RGB8)
			var v: Array = job.rect
			var rect := Rect2i(v[0], v[1], v[2], v[3])
			_blend(source, patch, rect, 20)
			# Retenir les détails générés : ne pas remonter une retouche préalablement réduite.
			_blend(display, patch, Rect2i(rect.position * factor, rect.size * factor), 20 * factor)
		source.save_png(ProjectSettings.globalize_path(base_path + "map_revised.png"))
		# Trois panneaux de texture, exactement contigus, constituent une seule carte continue.
		var width: int = display.get_width() / 3
		for column: int in 3:
			display.get_region(Rect2i(column * width, 0, width, display.get_height())).save_png(
				out.path_join("%s_%d.png" % [id, column]))
		print(id, " : source ", source.get_size(), ", présentation ", display.get_size())
	quit()

func _blend(base: Image, original: Image, rect: Rect2i, feather: int) -> void:
	assert(Rect2i(Vector2i.ZERO, base.get_size()).encloses(rect))
	var patch: Image = original.duplicate()
	patch.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_LANCZOS)
	for y: int in rect.size.y:
		for x: int in rect.size.x:
			var edge: int = mini(mini(x, rect.size.x - 1 - x), mini(y, rect.size.y - 1 - y))
			var amount: float = clampf(float(edge) / feather, 0.0, 1.0)
			var p := rect.position + Vector2i(x, y)
			base.set_pixelv(p, base.get_pixelv(p).lerp(patch.get_pixel(x, y), amount))
