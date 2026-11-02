extends SceneTree
## Banc documentaire : sprites réels du manifeste, sans simulation ni changement du gameplay.
const ZOOM := 1.8
var sprites: Array[Sprite2D] = []
var phases: Array[Array] = []
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
	label.add_theme_color_override("font_color", Color("d9edf5"))
	root.add_child(label)
	return label


func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/asset_manifest.json"))["entries"]
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(
		_arg("--catalog", "res://docs/art/chapitre4_catalogue.json")))
	var page := int(_arg("--page", "0"))
	var steps := int(_arg("--steps", "36"))
	var offset := int(_arg("--offset", "0"))
	var out := _arg("--out", "/tmp/rift-chapitre4")
	DirAccess.make_dir_recursive_absolute(out)
	var background := ColorRect.new()
	background.color = Color("111e30")
	background.size = Vector2(1280, 720)
	root.add_child(background)
	_label("Le Glacier silencieux · banc visuel des sprites · zoom du monde ×1,8", Vector2(28, 18), 25)
	_label("Présentation seulement · aucune mécanique modifiée · sol et alertes exclus des planches", Vector2(28, 660), 16)
	var first := page * 7
	var last := mini(first + 7, catalog.size())
	if page == 2:
		first = 14
		last = catalog.size()
	for index: int in range(first, last):
		var item: Dictionary = catalog[index]
		var entry: Dictionary = manifest[item["visual_id"]]
		var position := index - first
		var foot := Vector2(170 + (position % 4) * 310, 290 + (position / 4) * 300)
		if page == 2:
			foot = Vector2(440 if position == 0 else 960, 540)
		var sprite := Sprite2D.new()
		sprite.texture = load(entry["sheet"])
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.region_enabled = true
		sprite.scale = Vector2.ONE * float(entry["scale"]) * ZOOM
		sprite.position = foot - Vector2(float(entry["anchor"][0]), float(entry["anchor"][1])) * sprite.scale
		root.add_child(sprite)
		var animations: Array = []
		for animation: Dictionary in item["animations"]:
			animations.append({"name": animation["name"], "data": entry["animations"][animation["name"]], "cell": entry["cell"]})
		phases.append(animations)
		sprites.append(sprite)
		_label(item["name"], Vector2(foot.x - 140, foot.y + 18), 18)
		labels.append(_label("", Vector2(foot.x - 140, foot.y + 43), 15))
	for step: int in steps:
		for index: int in sprites.size():
			var animation: Dictionary = phases[index][((step + offset) / 6) % phases[index].size()]
			var frame := (step + offset) % 6
			var cell: Array = animation["cell"]
			sprites[index].region_rect = Rect2(frame * int(cell[0]), int(animation["data"]["row"]) * int(cell[1]), cell[0], cell[1])
			labels[index].text = "%s · pose %d/6" % [animation["name"], frame + 1]
		await process_frame
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png(out.path_join("%03d.png" % step))
		if result != OK:
			quit(1)
			return
	print("Banc visuel : ", sprites.size(), " sprites, ", steps, " images à 1280 × 720")
	quit(0)
