extends SceneTree
## Agrandissement de présentation ×2 ; les détails viennent des régions originales, pas d’un lissage IA.
func _initialize() -> void:
	var out: String = ProjectSettings.globalize_path("user://map-art")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	for id: String in ["cascade_ruins","storm_highlands"]:
		var folder: String = "map.three_rifts" if id == "cascade_ruins" else "map.storm_highlands"
		var path: String = ProjectSettings.globalize_path("res://assets/concepts/incoming/"+folder+"/source/map_detailed.png")
		var image: Image = Image.load_from_file(path)
		image.convert(Image.FORMAT_RGB8)
		image.resize(image.get_width()*2,image.get_height()*2,Image.INTERPOLATE_LANCZOS)
		image.save_png(out.path_join(id+"-final.png"))
	quit()
