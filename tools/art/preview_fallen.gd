extends Node
## Banc de lisibilité sans profil, données de monstres ou combat.

const IDS := ["fallen_militia", "corrupted_hound", "lantern_wraith", "fallen_crossbowman",
	"fallen_captain", "rift_herald", "cobble_golem"]
const NAMES := ["Milicien", "Chien", "Lanterne", "Arbalétrier", "Capitaine", "Héraldiste", "Golem"]
const ZOOM := 1.3333

var _root: String
var _assets: String
var _out: String
var _manifest: Dictionary
var _world: Node2D
var _actors: Node2D
var _caption: Label
var _cache: Dictionary = {}


func _ready() -> void:
	_root = get_script().resource_path.get_base_dir().path_join("../..").simplify_path()
	_assets = _root
	_out = _root.path_join("docs/previews/dechus")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--assets-root="):
			_assets = arg.trim_prefix("--assets-root=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	call_deferred("_capture")


func _actor(id: String, at: Vector2, animation: String, frame: int, rank_scale := 1.0) -> void:
	var entry: Dictionary = _manifest[id]
	var base: String = _root if IDS.has(id.trim_prefix("enemy.")) else _assets
	var path: String = base.path_join(String(entry["sheet"]).trim_prefix("res://"))
	if not _cache.has(path):
		_cache[path] = Image.load_from_file(path)
	var sheet: Image = _cache[path]
	assert(sheet != null, id)
	var cell: Array = entry["cell"]
	var anim: Dictionary = entry["animations"][animation]
	var region := Rect2i(frame % int(anim["frames"]) * int(cell[0]), int(anim["row"]) * int(cell[1]),
		int(cell[0]), int(cell[1]))
	var shadow := Node2D.new()
	shadow.position = at + Vector2(0, 1)
	shadow.z_index = -1
	shadow.scale = Vector2(rank_scale, rank_scale * 0.38)
	shadow.draw.connect(func() -> void:
		shadow.draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0.03, 0.35)))
	_actors.add_child(shadow)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(sheet.get_region(region))
	sprite.centered = false
	sprite.offset = -Vector2(float(entry["anchor"][0]), float(entry["anchor"][1]))
	sprite.position = at
	sprite.scale = Vector2.ONE * float(entry["scale"]) * rank_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actors.add_child(sprite)


func _show(center: Vector2, mode: int, frame := 0) -> void:
	for actor: Node in _actors.get_children():
		actor.free()
	_world.scale = Vector2.ONE * ZOOM
	_world.position = Vector2(640, 360) - center * ZOOM
	var compact := center.distance_to(Vector2(1670, 1765)) < 1.0
	for i: int in IDS.size():
		var at := center + (Vector2(-225 + i * 150, -110) if i < 4 else Vector2(-160 + (i - 4) * 160, 30))
		if compact:
			at = center + (Vector2(-150 + i * 100, -110) if i < 4
				else Vector2(-120 + (i - 4) * 120, 30))
		var animation := "move" if mode == 0 else "attack"
		if mode == 2:
			animation = ["attack", "attack", "attack", "corrupted_bolt",
				"shield_wall", "soul_link", "slab_armor"][i]
		elif mode == 3:
			animation = ["attack", "attack", "attack", "corrupted_bolt",
				"rallying_cry", "corruption_seal", "tunnel"][i]
		_actor("enemy." + IDS[i], at, animation, frame, 1.5 if i >= 4 else 1.0)
		var label := Label.new()
		label.text = NAMES[i]
		label.position = at + Vector2(-35, 11)
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_outline_color", Color("181021"))
		label.add_theme_constant_override("outline_size", 4)
		_actors.add_child(label)
	_actor("player.hunter", center + Vector2(-85, 165), "move", 0)
	_actor("monster.glimmerwing", center + Vector2(85, 165), "move", 0)
	_caption.text = "LES DÉCHUS · CARTE 21 · ZOOM 1,3333 · ÉLITES ×1,5 · BANC STATIQUE"


func _save(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1280, 720))
	assert(image.save_png(_out.path_join(name + ".png")) == OK)
	print("CAPTURE_OK ", name)


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var catalog := FileAccess.get_file_as_string(_root.path_join("assets/asset_manifest.json"))
	_manifest = JSON.parse_string(catalog)["entries"]
	_world = Node2D.new()
	add_child(_world)
	for i: int in 3:
		var suffix := "" if i == 0 else "_%d" % i
		var path := _assets.path_join("assets/environments/shattered_outskirts/map%s.webp" % suffix)
		var image := Image.load_from_file(path)
		assert(image != null and image.get_size() == Vector2i(3762, 7524))
		var ground := Sprite2D.new()
		ground.texture = ImageTexture.create_from_image(image)
		ground.centered = false
		ground.position = Vector2(i * 1672, 0)
		ground.scale = Vector2.ONE / 2.25
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_world.add_child(ground)
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	_world.add_child(_actors)
	_caption = Label.new()
	_caption.position = Vector2(14, 12)
	_caption.add_theme_font_size_override("font_size", 14)
	_caption.add_theme_color_override("font_outline_color", Color("181021"))
	_caption.add_theme_constant_override("outline_size", 5)
	add_child(_caption)
	_show(Vector2(4088, 843), 0)
	await _save("dechus_dalles_zoom_jeu")
	_show(Vector2(1670, 1765), 0)
	await _save("dechus_corruption_zoom_jeu")
	_show(Vector2(4088, 843), 1, 3)
	await _save("dechus_attaques_zoom_jeu")
	_show(Vector2(4088, 843), 2, 3)
	await _save("dechus_techniques_1_zoom_jeu")
	_show(Vector2(4088, 843), 3, 3)
	await _save("dechus_techniques_2_zoom_jeu")
	for frame: int in 6:
		_show(Vector2(4088, 843), 0, frame)
		await _save("mouvement_%02d" % frame)
	print("FALLEN_PREVIEW_OK 11 captures ; aucun profil ni gameplay")
	get_tree().quit()
