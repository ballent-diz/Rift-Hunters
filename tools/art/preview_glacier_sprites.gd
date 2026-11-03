extends Node
## Banc graphique du Glacier : fichiers réels, caméra du jeu, aucune simulation de combat.

var root: Window

var _sprites: Array[Sprite2D] = []
var _entries: Array[Dictionary] = []
var _names: Array[Array] = []
var _labels: Array[Label] = []


func _ready() -> void:
	root = get_tree().root
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


func _sprite(entry: Dictionary, foot: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(entry["sheet"])
	assert(sprite.texture != null)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.region_enabled = true
	sprite.scale = Vector2.ONE * float(entry["scale"]) * GameDB.balance.camera_zoom
	sprite.position = foot - Vector2(entry["anchor"][0], entry["anchor"][1]) * sprite.scale
	root.add_child(sprite)
	return sprite


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var out := _arg("--out", "/tmp/rift-glacier")
	DirAccess.make_dir_recursive_absolute(out)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_arg("--catalog", "")))
	var background := ColorRect.new()
	background.color = Color("111e30")
	background.size = Vector2(1280, 720)
	root.add_child(background)
	_label("Glacier silencieux · " + str(catalog["lot"]) + " · zoom du jeu", Vector2(24, 18), 24)
	_label("Banc graphique hors partie · cellules et échelle du manifeste", Vector2(24, 680), 16)
	var ids: Array = catalog["sprites"]
	for index: int in ids.size():
		var item: Dictionary = ids[index]
		var entry: Dictionary = Assets.entry(StringName(item["id"]))
		assert(entry["status"] == "final")
		var foot := Vector2(160 + (index % 4) * 320, 220 + (index / 4) * 300)
		if ids.size() == 1:
			foot = Vector2(640, 440)
		_sprites.append(_sprite(entry, foot))
		_entries.append(entry)
		_names.append(item["animations"])
		_label(item["name"], Vector2(foot.x - 145, foot.y + 20))
		_labels.append(_label("", Vector2(foot.x - 145, foot.y + 47), 16))
	var hunter_entry: Dictionary = Assets.entry(&"player.hunter")
	var hunter := _sprite(hunter_entry, Vector2(1150, 640))
	var idle: Dictionary = hunter_entry["animations"]["idle"]
	hunter.region_rect = Rect2(0, idle["row"] * hunter_entry["cell"][1],
		hunter_entry["cell"][0], hunter_entry["cell"][1])
	_label("Chasseur · même zoom", Vector2(1020, 652), 16)
	var steps := int(_arg("--steps", "36"))
	for step: int in steps:
		for index: int in _sprites.size():
			var names: Array = _names[index]
			var name: String = names[(step / 6) % names.size()]
			var anim: Dictionary = _entries[index]["animations"][name]
			var cell: Array = _entries[index]["cell"]
			var frame := step % int(anim["frames"])
			_sprites[index].region_rect = Rect2(frame * cell[0], anim["row"] * cell[1], cell[0], cell[1])
			_labels[index].text = "%s · pose %d/%d" % [name, frame + 1, anim["frames"]]
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		assert(image.get_size() == Vector2i(1280, 720))
		assert(image.save_png(out.path_join("%03d.png" % step)) == OK)
	print("GLACIER_PREVIEW_OK : ", ids.size(), " sprites ; ", steps, " captures ; zoom ", GameDB.balance.camera_zoom)
	get_tree().quit(0)
