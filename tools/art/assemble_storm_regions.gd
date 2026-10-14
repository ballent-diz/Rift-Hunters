extends SceneTree
## Assemble les régions générées en une texture unique, sans modifier leurs détails.
func _initialize() -> void:
	var region: Image = Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/concepts/incoming/map.storm_highlands/source/regions/0_0.png"))
	var side: int = region.get_width()
	var whole := Image.create(side*3,side*3,false,Image.FORMAT_RGB8)
	for y: int in 3:
		for x: int in 3:
			var tile: Image = Image.load_from_file(ProjectSettings.globalize_path(
				"res://assets/concepts/incoming/map.storm_highlands/source/regions/%d_%d.png" % [x, y]))
			tile.convert(Image.FORMAT_RGB8)
			if tile.get_size() != Vector2i(side,side):
				tile.resize(side,side,Image.INTERPOLATE_LANCZOS)
			whole.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),Vector2i(x*side,y*side))
	whole.save_png(ProjectSettings.globalize_path("res://assets/concepts/incoming/map.storm_highlands/source/map_detailed.png"))
	quit()
