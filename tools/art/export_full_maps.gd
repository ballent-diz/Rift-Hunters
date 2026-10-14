extends SceneTree
## Exporte une seule image de chaque carte complète à partir des panneaux réellement utilisés en jeu.
func _initialize() -> void:
	var out := ProjectSettings.globalize_path("user://full-maps")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	for id: String in ["cascade_ruins", "storm_highlands"]:
		var root := ProjectSettings.globalize_path("res://assets/environments/" + id + "/")
		var first: Image = Image.load_from_file(root + "map.webp")
		first.convert(Image.FORMAT_RGB8)
		var full := Image.create(first.get_width()*3,first.get_height(),false,Image.FORMAT_RGB8)
		for column: int in 3:
			var filename := "map.webp" if column == 0 else "map_%d.webp" % column
			var tile: Image = Image.load_from_file(root + filename)
			tile.convert(Image.FORMAT_RGB8)
			assert(tile.get_size() == first.get_size())
			full.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),Vector2i(column*tile.get_width(),0))
		full.save_png(out.path_join(id+"-complet.png"))
		var ratio: float = 2000.0/maxf(full.get_width(),full.get_height())
		full.resize(roundi(full.get_width()*ratio),roundi(full.get_height()*ratio),Image.INTERPOLATE_LANCZOS)
		full.save_png(out.path_join(id+"-vue-entiere.png"))
		print("Carte entière exportée : ", id)
	quit()
