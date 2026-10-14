extends SceneTree
func _initialize() -> void:
	var creatures: Array = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/concepts/incoming/map.storm_highlands/creatures.json"))
	var entries: Dictionary = {}
	var reports: Array = []
	for data: Dictionary in creatures:
		var id: String = data.id
		if id != "heath_runner":
			continue
		var source := Image.load_from_file(ProjectSettings.globalize_path(
			"res://assets/concepts/incoming/enemy." + id + "/source/sheet.png"))
		source.convert(Image.FORMAT_RGBA8)
		var cw: int = source.get_width() / 6
		var ch: int = source.get_height() / 3
		var transparent: int = 0
		for y in source.get_height():
			for x in source.get_width():
				if source.get_pixel(x, y).a < 0.01:
					transparent += 1
		assert(transparent > source.get_width() * source.get_height() / 4, "Fond opaque")
		var cell: int = 320 if data.tier == "boss" else 128
		var target: float = 250.0 if data.tier == "boss" else float(data.height) * 2.0
		var cuts: Array[Image] = []
		var rects: Array[Rect2i] = []
		for row in 3:
			for col in 6:
				var begin: int = col*cw
				var end: int = (col+1)*cw if col<5 else source.get_width()
				for edge: int in 2:
					var nominal: int = begin if edge == 0 else end
					if nominal == 0 or nominal >= source.get_width():
						continue
					var best: int = nominal
					var best_score: float = INF
					for x: int in range(maxi(1,nominal-40),mini(source.get_width()-1,nominal+40)):
						var score: float = absf(x-nominal)*.01
						for y: int in range(row*ch,(row+1)*ch):
							if source.get_pixel(x,y).a > .05:
								score += 1
						if score < best_score:
							best = x
							best_score = score
					if edge == 0:
						begin = best
					else:
						end = best
				var cut := source.get_region(Rect2i(begin,row*ch,end-begin,ch))
				cuts.append(cut)
				rects.append(cut.get_used_rect())
		var scale_factor: float = target / float(rects[0].size.y)
		for rect in rects:
			scale_factor = minf(scale_factor, float(cell - 12) / maxf(rect.size.x, rect.size.y))
		var sheet := Image.create(cell*6,cell*3,false,Image.FORMAT_RGBA8)
		var bounds: Array = []
		for index in 18:
			var rect: Rect2i = rects[index]
			var cut: Image = cuts[index].get_region(rect)
			cut.resize(maxi(1,roundi(rect.size.x*scale_factor)),maxi(1,roundi(rect.size.y*scale_factor)),Image.INTERPOLATE_LANCZOS)
			var pos := Vector2i((cell-cut.get_width())/2,cell-10-cut.get_height())
			sheet.blit_rect(cut,Rect2i(Vector2i.ZERO,cut.get_size()),Vector2i(index%6*cell,index/6*cell)+pos)
			bounds.append([pos.x,pos.y,cut.get_width(),cut.get_height()])
		sheet.save_png(ProjectSettings.globalize_path("res://assets/sprites/storm_highlands/"+id+"/sheet.png"))
		var icon := sheet.get_region(Rect2i(0,0,cell,cell))
		icon.save_png(ProjectSettings.globalize_path("res://assets/sprites/storm_highlands/"+id+"/icon.png"))
		var animations := {
			"move": {"row": 0, "frames": 6, "fps": 10, "loop": true},
			"attack": {"row": 1, "frames": 6, "fps": 12, "loop": false},
			"death": {"row": 2, "frames": 6, "fps": 12, "loop": false},
			"idle": {"row": 0, "frames": 1, "fps": 8, "loop": true},
		}
		var vid: String = ("boss." if data.tier == "boss" else "enemy.")+id
		entries[vid] = {
			"status": "final",
			"sheet": "res://assets/sprites/storm_highlands/" + id + "/sheet.png",
			"icon": "res://assets/sprites/storm_highlands/" + id + "/icon.png",
			"cell": [cell, cell], "anchor": [cell / 2, cell - 10], "scale": 0.5, "animations": animations,
		}
		var pixels: float = float(source.get_width() * source.get_height())
		reports.append({"id": id, "source_size": [source.get_width(), source.get_height()],
			"transparent_fraction": float(transparent) / pixels, "frames": 18, "cell": cell, "bounds": bounds})
		print(id," : alpha OK, 18 frames, cellule ",cell)
	var manifest_file := FileAccess.open("res://assets/concepts/incoming/enemy.heath_runner/manifest.fragment.json",FileAccess.WRITE)
	manifest_file.store_string(JSON.stringify({"entries":entries},"\t"))
	var report_file := FileAccess.open("res://assets/concepts/incoming/enemy.heath_runner/validation.json",FileAccess.WRITE)
	report_file.store_string(JSON.stringify(reports,"\t"))
	quit()
