extends SceneTree
## Réinsère des raccords générés. Retire uniquement les marges blanches automatiques, puis fond les bords.
func _initialize() -> void:
	var mode := "vertical"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
	var root := "res://assets/concepts/incoming/map.storm_highlands/source/"
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(root+"map_detailed.png"))
	image.convert(Image.FORMAT_RGB8)
	var jobs: Array = JSON.parse_string(FileAccess.get_file_as_string(root+"seams/"+mode+".json"))
	for job: Dictionary in jobs:
		var patch: Image = Image.load_from_file(ProjectSettings.globalize_path(root+"seams/"+job.id+".png"))
		patch.convert(Image.FORMAT_RGB8)
		if mode == "horizontal":
			patch.rotate_90(CLOCKWISE)
		var left := 0
		var right: int = patch.get_width()-1
		while left < right and _white_column(patch,left):
			left += 1
		while right > left and _white_column(patch,right):
			right -= 1
		patch = patch.get_region(Rect2i(left,0,right-left+1,patch.get_height()))
		if mode == "horizontal":
			patch.rotate_90(COUNTERCLOCKWISE)
		var values: Array = job.rect
		var rect := Rect2i(int(values[0]),int(values[1]),int(values[2]),int(values[3]))
		patch.resize(rect.size.x,rect.size.y,Image.INTERPOLATE_LANCZOS)
		for y: int in rect.size.y:
			for x: int in rect.size.x:
				var edge: float = minf(minf(x,rect.size.x-1-x),minf(y,rect.size.y-1-y))
				var amount: float = clampf(edge/24.0,0.0,1.0)
				var point := rect.position+Vector2i(x,y)
				image.set_pixelv(point,image.get_pixelv(point).lerp(patch.get_pixel(x,y),amount))
	image.save_png(ProjectSettings.globalize_path(root+"map_detailed.png"))
	if mode == "vertical":
		for row: int in 2:
			for column: int in 3:
				var rect := Rect2i(column*1254,(row+1)*1254-180,1254,360)
				# Contrôle visuel des raccords (dossier de travail hors du dépôt).
				var out_dir: String = ProjectSettings.globalize_path("res://").path_join("../quality-regions")
				DirAccess.make_dir_recursive_absolute(out_dir)
				image.get_region(rect).save_png(out_dir.path_join("seam_h%d_%d.png" % [column, row]))
	quit()

func _white_column(image: Image,x: int) -> bool:
	var white := 0
	for y: int in image.get_height():
		var color: Color = image.get_pixel(x,y)
		if color.r > .98 and color.g > .98 and color.b > .98:
			white += 1
	return white > image.get_height()*.98
