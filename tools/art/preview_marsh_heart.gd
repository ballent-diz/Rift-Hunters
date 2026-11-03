extends Node
## Contrôle graphique hors partie : même caméra et mêmes acteurs que les cartes de référence.

const DEFAULT_OUT := "res://docs/previews/marsh-heart/"

var _world: Node2D
var _hunter: EntityVisual
var _echo: EntityVisual
var _caption: Label
var _overview_image: Image
var _out := DEFAULT_OUT


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var sample_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sample="):
			sample_path = arg.trim_prefix("--sample=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if not _out.ends_with("/"):
		_out += "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	AudioServer.set_bus_mute(0, true)
	Profile.read_only = true
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	_world = Node2D.new()
	add_child(_world)
	_caption = Label.new()
	_caption.position = Vector2(24, 12)
	_caption.add_theme_font_size_override("font_size", 18)
	_caption.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.03))
	_caption.add_theme_constant_override("outline_size", 6)
	add_child(_caption)
	var map_root: Node2D
	if sample_path.is_empty():
		map_root = _map("marsh_heart", true)
		_world.visible = false
		var overview := Sprite2D.new()
		overview.texture = ImageTexture.create_from_image(_overview_image)
		overview.centered = false
		overview.position = Vector2(420, 45)
		add_child(overview)
		_caption.text = "CARTE 15 · CŒUR DES MARAIS · VUE ENTIÈRE · CONTRÔLE GRAPHIQUE HORS PARTIE"
		await _save("apercu_720p.png")
		overview.queue_free()
		_world.visible = true
	else:
		map_root = _sample(sample_path)
	_actors()
	if sample_path.is_empty():
		var specs: Array = [
			["terrasse_nord", Vector2(1672, 1150)],
			["temple", Vector2(1672, 2750)],
			["chaussee_inondable", Vector2(1010, 2435)],
			["pont_sec", Vector2(1010, 3010)],
			["clairiere_vase", Vector2(1570, 4160)],
		]
		for spec: Array in specs:
			_set_camera(spec[1])
			_caption.text = "CŒUR DES MARAIS · " + String(spec[0]) + " · ZOOM DU JEU · CHASSEUR ET ÉCHO"
			await _save(String(spec[0]) + "_zoom_jeu.png")
	else:
		_set_camera(Vector2(717.3, 676.8))
		_caption.text = "CARTE 15 · TÉMOIN DU TEMPLE · ZOOM DU JEU · CHASSEUR ET ÉCHO"
		await _save("temoin_zoom_jeu.png")
	map_root.queue_free()
	await get_tree().process_frame
	_map("cascade_ruins")
	_set_camera(Vector2(2700, 500))
	_caption.text = "RÉFÉRENCE · RUINES DES CASCADES · MÊME ZOOM, CHASSEUR ET ÉCHO"
	await _save("reference_ruines_zoom_jeu.png")
	print("MARSH_HEART_PREVIEWS_OK · témoin seulement : ", not sample_path.is_empty())
	get_tree().quit()


func _actors() -> void:
	_hunter = EntityVisual.new()
	_hunter.setup(GameDB.balance.player_visual)
	_world.add_child(_hunter)
	_echo = EntityVisual.new()
	_echo.setup(GameDB.monster(&"mossback").visual)
	_world.add_child(_echo)
	for actor: EntityVisual in [_hunter, _echo]:
		actor.z_index = 2
		if actor._anim:
			actor._anim.pause()
			actor._anim.frame = 0


func _sample(path: String) -> Node2D:
	var root := Node2D.new()
	_world.add_child(root)
	var image := Image.load_from_file(path)
	assert(image != null and not image.is_empty())
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.centered = false
	sprite.scale = Vector2.ONE / 2.25
	root.add_child(sprite)
	return root


func _map(folder: String, make_overview: bool = false) -> Node2D:
	var root := Node2D.new()
	_world.add_child(root)
	var names: Array[String] = ["map.webp", "map_1.webp"]
	if folder == "cascade_ruins":
		names.append("map_2.webp")
	if make_overview:
		_overview_image = Image.create(440, 660, false, Image.FORMAT_RGB8)
	for i: int in names.size():
		var path: String = "res://assets/environments/" + folder + "/" + names[i]
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert(image != null and not image.is_empty(), path)
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.centered = false
		sprite.scale = Vector2.ONE / 2.25
		sprite.position = Vector2(i * 1672, 0)
		root.add_child(sprite)
		if make_overview:
			var small := image.duplicate() as Image
			small.convert(Image.FORMAT_RGB8)
			small.resize(220, 660, Image.INTERPOLATE_LANCZOS)
			_overview_image.blit_rect(small, Rect2i(0, 0, 220, 660), Vector2i(i * 220, 0))
	return root


func _set_camera(center: Vector2) -> void:
	var zoom: float = GameDB.balance.camera_zoom
	_world.scale = Vector2.ONE * zoom
	_world.position = Vector2(640, 360) - center * zoom
	_hunter.position = center
	_echo.position = center + Vector2(55, 20)


func _save(filename: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1280, 720))
	assert(image.save_png(_out + filename) == OK)
