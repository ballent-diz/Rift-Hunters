extends Node
## Contrôle visuel de la carte 14 : vrais sprites et zoom du jeu, aucune collision simulée.

const OUT := "res://docs/previews/reflection-wells/"
const TILE_NAMES: Array[String] = ["map.webp", "map_1.webp", "map_2.webp"]

var _world: Node2D
var _hunter: EntityVisual
var _echo: EntityVisual
var _caption: Label
var _overview_image: Image


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	AudioServer.set_bus_mute(0, true)
	Profile.read_only = true
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUT)
	_world = Node2D.new()
	add_child(_world)
	var map_root: Node2D = _map("reflection_wells", true)
	_caption = Label.new()
	_caption.position = Vector2(24, 12)
	_caption.add_theme_font_size_override("font_size", 19)
	_caption.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.03))
	_caption.add_theme_constant_override("outline_size", 6)
	add_child(_caption)
	_world.visible = false
	var overview := Sprite2D.new()
	overview.texture = ImageTexture.create_from_image(_overview_image)
	overview.centered = false
	overview.position = Vector2(310, 45)
	add_child(overview)
	_caption.text = "CARTE 14 · PUITS DES REFLETS · VUE ENTIÈRE · CONTRÔLE VISUEL HORS PARTIE"
	await _save("apercu_720p.png")
	overview.queue_free()
	_world.visible = true
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
	var specs: Array = [
		["centre", Vector2(2508, 2700)],
		["pont_nord", Vector2(2510, 1160)],
		["boucle_sud_est", Vector2(4200, 4320)],
	]
	for spec: Array in specs:
		_set_camera(spec[1])
		_caption.text = "PUITS DES REFLETS · " + String(spec[0]) + " · ZOOM DU JEU · CHASSEUR ET MOUSSEROC"
		await _save(String(spec[0]) + "_zoom_jeu.png")
	map_root.queue_free()
	await get_tree().process_frame
	_map("cascade_ruins")
	_set_camera(Vector2(2700, 500))
	_caption.text = "RÉFÉRENCE · RUINES DES CASCADES · MÊME ZOOM, CHASSEUR ET MOUSSEROC"
	await _save("reference_ruines_zoom_jeu.png")
	print("PUITS_APERCUS_OK : carte entière et quatre vues au zoom réel ; aucun essai de navigation.")
	get_tree().quit()


func _map(folder: String, make_overview: bool = false) -> Node2D:
	var root := Node2D.new()
	_world.add_child(root)
	if make_overview:
		_overview_image = Image.create(660, 660, false, Image.FORMAT_RGB8)
	for i: int in TILE_NAMES.size():
		var path: String = "res://assets/environments/" + folder + "/" + TILE_NAMES[i]
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
	assert(image.save_png(OUT + filename) == OK)
