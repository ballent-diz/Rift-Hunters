extends Node
## Banc visuel en lecture seule : aucune partie, collision ou modification de profil.

const WORLD := 4400.0
const ZOOM := 1.3333
const WITNESSES := ["enemy.wandering_shard", "enemy.glass_sentinel", "enemy.quartz_golem",
	"enemy.hush_shard", "enemy.ice_knight", "enemy.silence_herald"]

var _root: String
var _assets_root: String
var _out: String
var _world: Node2D
var _actors: Node2D
var _caption: Label
var _entries: Dictionary
var _detail := false
var _sheet_cache: Dictionary = {}


func _ready() -> void:
	_root = get_script().resource_path.get_base_dir().path_join("../..").simplify_path()
	_assets_root = _root
	_out = _root.path_join("docs/previews/shattered-pantheon")
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--detail":
			_detail = true
		elif arg.begins_with("--assets-root="):
			_assets_root = arg.trim_prefix("--assets-root=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	call_deferred("_capture")


func _raw(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _sprite(path: String, position_value: Vector2, density: float) -> void:
	var image := Image.load_from_file(_raw(path))
	assert(image != null)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.position = position_value
	sprite.scale = Vector2.ONE / density
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_world.add_child(sprite)


func _actor(id: String, at: Vector2) -> void:
	assert(_entries.has(id), "Témoin absent : " + id)
	var entry: Dictionary = _entries[id]
	var path: String = _assets_root.path_join(String(entry["sheet"]).trim_prefix("res://"))
	if not _sheet_cache.has(path):
		_sheet_cache[path] = Image.load_from_file(_raw(path))
	var sheet: Image = _sheet_cache[path]
	var cell: Array = entry["cell"]
	var frame := sheet.get_region(Rect2i(0, 0, int(cell[0]), int(cell[1])))
	var actor := Sprite2D.new()
	actor.texture = ImageTexture.create_from_image(frame)
	actor.centered = false
	actor.offset = -Vector2(entry["anchor"][0], entry["anchor"][1])
	actor.scale = Vector2.ONE * float(entry["scale"])
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.position = at
	_actors.add_child(actor)


func _view(center: Vector2, label: String, witnesses := false) -> void:
	for actor: Node in _actors.get_children():
		actor.free()
	_world.scale = Vector2.ONE * ZOOM
	_world.position = Vector2(640, 360) - center * ZOOM
	_actor("player.hunter", center + Vector2(-80, 100))
	_actor("monster.glimmerwing", center + Vector2(80, 100))
	if witnesses:
		for i: int in WITNESSES.size():
			_actor(WITNESSES[i], center + Vector2(-300 + (i % 3) * 200, -50 + (i / 3) * 210))
	_caption.text = ("DÉTAIL" if _detail else "COMPOSITION · PAS UNE CARTE FINALE") \
		+ " 24 · " + label + " · ZOOM 1,3333 · BANC STATIQUE"


func _save(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	assert(im.get_size() == Vector2i(1280, 720))
	assert(im.save_png(_out.path_join(name + ".png")) == OK)
	print("CAPTURE_OK ", name)


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(_raw(_out))
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	_entries = JSON.parse_string(FileAccess.get_file_as_string(
		_assets_root.path_join("assets/asset_manifest.json")))["entries"]
	_world = Node2D.new()
	add_child(_world)
	if _detail:
		for i: int in 3:
			var suffix := "" if i == 0 else "_%d" % i
			_sprite(_root.path_join("assets/environments/shattered_pantheon/map%s.webp" % suffix),
				Vector2(i * WORLD / 3.0, 0), 2.25)
	else:
		var path := _root.path_join("assets/concepts/incoming/map.shattered_pantheon/composition.png")
		var image := Image.load_from_file(_raw(path))
		_sprite(path, Vector2.ZERO, image.get_width() / WORLD)
	_actors = Node2D.new()
	_world.add_child(_actors)
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	_caption.add_theme_constant_override("shadow_offset_x", 2)
	_caption.add_theme_constant_override("shadow_offset_y", 2)
	_caption.position = Vector2(14, 12)
	layer.add_child(_caption)
	_world.scale = Vector2.ONE * (660.0 / WORLD)
	_world.position = Vector2(310, 38)
	_caption.text = "PANTHÉON BRISÉ · VUE ENTIÈRE · " + ("DÉTAIL" if _detail else "COMPOSITION")
	await _save("ensemble_720p")
	for spec: Array in [["depart", Vector2(2200, 3894)], ["socle", Vector2(1531, 1148)],
		["alcove_nord", Vector2(2200, 792)], ["alcove_ouest", Vector2(818, 2138)],
		["alcove_est", Vector2(3582, 2138)], ["pilier_central", Vector2(2191, 2292)],
		["passage_nw", Vector2(1540, 1606)], ["passage_ne", Vector2(2860, 1606)],
		["passage_sw", Vector2(1540, 2640)], ["passage_se", Vector2(2860, 2640)]]:
		_view(spec[1], String(spec[0]).to_upper())
		await _save(spec[0] + "_zoom_jeu")
	_view(Vector2(1200, 1200), "TÉMOINS DALLES", true)
	await _save("lisibilite_dalles")
	_view(Vector2(1050, 1410), "TÉMOINS CORRUPTION", true)
	await _save("lisibilite_corruption")
	print("PREVIEW_OK 13 captures ; sprites et échelles du manifeste ; aucun profil ni combat")
	get_tree().quit()
