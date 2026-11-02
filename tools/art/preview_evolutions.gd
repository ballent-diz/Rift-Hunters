extends SceneTree
## Comparaison au même zoom : forme de base à gauche, évolution à droite.
const ZOOM := 1.8
var sprites: Array[Sprite2D] = []
var definitions: Array[Dictionary] = []
var animation_names: Array[Array] = []
var labels: Array[Label] = []


func _initialize() -> void:
	call_deferred("_run")


func _arg(key: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(key + "="):
			return arg.trim_prefix(key + "=")
	return fallback


func _label(text: String, at: Vector2, size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e4edf5"))
	root.add_child(label)
	return label


func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/asset_manifest.json"))["entries"]
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/evolutions_catalogue.json"))
	var page := int(_arg("--page", "0"))
	var out := _arg("--out", "/tmp/rift-evolutions")
	var steps := int(_arg("--steps", "40"))
	DirAccess.make_dir_recursive_absolute(out)
	var background := ColorRect.new()
	background.color = Color("142134")
	background.size = Vector2(1280, 720)
	root.add_child(background)
	_label("Évolutions des Échos · base à gauche, évolution à droite · même zoom du monde ×1,8", Vector2(24, 18), 24)
	_label("Sprites réellement chargés · mêmes animations, nombres de poses, cadences et boucles", Vector2(24, 674), 17)
	for index: int in range(page * 4, mini(page * 4 + 4, catalog.size())):
		var item: Dictionary = catalog[index]
		var local_index := index - page * 4
		for side: int in 2:
			var entry: Dictionary = manifest[item["base"] if side == 0 else item["visual_id"]]
			var foot := Vector2((local_index % 2) * 640 + 160 + side * 290, 270 + (local_index / 2) * 300)
			var sprite := Sprite2D.new()
			sprite.texture = load(entry["sheet"])
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.centered = false
			sprite.region_enabled = true
			sprite.scale = Vector2.ONE * float(entry["scale"]) * ZOOM
			sprite.position = foot - Vector2(entry["anchor"][0], entry["anchor"][1]) * sprite.scale
			root.add_child(sprite)
			sprites.append(sprite)
			definitions.append(entry)
			var names: Array = []
			for animation: Dictionary in item["animations"]:
				names.append(animation["name"])
			animation_names.append(names)
			_label(item["base"].trim_prefix("monster.") if side == 0 else item["name"], foot + Vector2(-130, 18))
			labels.append(_label("", foot + Vector2(-130, 44), 15))
	for step: int in steps:
		for index: int in sprites.size():
			var entry: Dictionary = definitions[index]
			var name: String = animation_names[index][(step / 8) % animation_names[index].size()]
			var animation: Dictionary = entry["animations"][name]
			var count: int = animation["frames"]
			var frame: int = (step % 8) % count if animation["loop"] else mini(step % 8, count - 1)
			var cell: Array = entry["cell"]
			sprites[index].region_rect = Rect2(frame * int(cell[0]), int(animation["row"]) * int(cell[1]), cell[0], cell[1])
			labels[index].text = "%s · %d/%d" % [name, frame + 1, count]
		await process_frame
		await RenderingServer.frame_post_draw
		var code := root.get_texture().get_image().save_png(out.path_join("%03d.png" % step))
		if code != OK:
			quit(1)
			return
	print("ÉVOLUTIONS : ", sprites.size() / 2, " comparaisons, ", steps, " images 1280 × 720")
	quit(0)
