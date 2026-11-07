extends Node
## Banc statique de la retouche : images et échelles natives, aucun profil ni navigation.

const ZOOM := 1.3333

var _root: String
var _assets: String
var _out: String
var _world: Node2D
var _actors: Node2D
var _caption: Label
var _entries: Dictionary


func _ready() -> void:
	_root = get_script().resource_path.get_base_dir().path_join("../..").simplify_path()
	_assets = _root
	_out = _root.path_join("docs/previews/silent-heart")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--assets-root="):
			_assets = arg.trim_prefix("--assets-root=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	call_deferred("_capture")


func _actor(id: String, at: Vector2) -> void:
	var entry: Dictionary = _entries[id]
	var path: String = _assets.path_join(String(entry["sheet"]).trim_prefix("res://"))
	var sheet := Image.load_from_file(path)
	assert(sheet != null)
	var cell: Array = entry["cell"]
	var sprite := Sprite2D.new()
	var frame := sheet.get_region(Rect2i(0, 0, int(cell[0]), int(cell[1])))
	sprite.texture = ImageTexture.create_from_image(frame)
	sprite.centered = false
	sprite.offset = -Vector2(entry["anchor"][0], entry["anchor"][1])
	sprite.scale = Vector2.ONE * float(entry["scale"])
	sprite.position = at
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actors.add_child(sprite)


func _save(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1280, 720))
	assert(image.save_png(_out.path_join(name + ".png")) == OK)
	print("CAPTURE_OK ", name)


func _view(center: Vector2, name: String) -> void:
	for actor: Node in _actors.get_children():
		actor.free()
	_world.scale = Vector2.ONE * ZOOM
	_world.position = Vector2(640, 360) - center * ZOOM
	_actor("player.hunter", center + Vector2(-100, 0))
	_actor("enemy.snow_wraith", center + Vector2(100, 0))
	_caption.text = "CARTE 20 · " + name.to_upper() + " · ZOOM 1,3333 · BANC STATIQUE"
	await _save(name)


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var catalog := FileAccess.get_file_as_string(_assets.path_join("assets/asset_manifest.json"))
	_entries = JSON.parse_string(catalog)["entries"]
	_world = Node2D.new()
	add_child(_world)
	for i: int in 3:
		var suffix := "" if i == 0 else "_%d" % i
		var path := _root.path_join("assets/environments/silent_heart/map%s.webp" % suffix)
		var image := Image.load_from_file(path)
		assert(image != null and image.get_size() == Vector2i(3762, 7524))
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.centered = false
		sprite.position = Vector2(i * 1672, 0)
		sprite.scale = Vector2.ONE / 2.25
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_world.add_child(sprite)
	_caption = Label.new()
	_caption.position = Vector2(15, 12)
	_caption.add_theme_font_size_override("font_size", 14)
	_caption.add_theme_color_override("font_outline_color", Color("15273c"))
	_caption.add_theme_constant_override("outline_size", 6)
	add_child(_caption)
	_world.scale = Vector2.ONE * (900.0 / 5016.0)
	_world.position = Vector2(190, 60)
	_caption.text = "CARTE 20 · CHEMIN ET DÉCORS CENTRAUX · DÉTAIL RETOUCHÉ"
	await _save("ensemble_720p")
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	_world.add_child(_actors)
	await _view(Vector2(2490, 1956), "chemin_entree_est")
	await _view(Vector2(2220, 1956), "chemin_centre")
	await _view(Vector2(1950, 1956), "chemin_sortie_ouest")
	await _view(Vector2(1153, 1705), "centre_ouest")
	await _view(Vector2(2859, 1905), "centre_milieu")
	await _view(Vector2(4314, 2010), "centre_est")
	await _view(Vector2(903, 2020), "abri_central")
	print("LOCAL_PREVIEW_OK 8 captures ; aucun masque, profil ni combat")
	get_tree().quit()
