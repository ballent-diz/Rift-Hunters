extends Node
## Banc de lisibilité sans profil, données de monstres ou combat.

const IDS := ["rift_larva", "drifting_eye", "void_crawler", "torn_shade",
	"portal_strider", "echo_mirror", "statue_keeper", "awakened_statue"]
const NAMES := ["Larve", "Œil errant", "Rampe-vide", "Ombre",
	"Arpenteur", "Miroir", "Gardienne", "Statue"]
const ZOOM := 1.3333

var _root: String
var _assets: String
var _out: String
var _map24: String
var _manifest: Dictionary
var _world: Node2D
var _actors: Node2D
var _caption: Label
var _cache: Dictionary = {}


func _ready() -> void:
	_root = get_script().resource_path.get_base_dir().path_join("../..").simplify_path()
	_assets = _root
	_out = _root.path_join("docs/previews/enfants-faille")
	_map24 = _root.path_join("assets/concepts/incoming/" +
		"map.shattered_pantheon/source/map_detailed.webp")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--assets-root="):
			_assets = arg.trim_prefix("--assets-root=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--map24-source="):
			_map24 = arg.trim_prefix("--map24-source=")
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
	for i: int in IDS.size():
		var at := center + Vector2(-300 + (i % 4) * 200, -90 if i < 4 else 110)
		var animation := "move" if mode == 0 else "attack"
		if mode == 2:
			animation = ["attack", "attack", "attack", "rift_step",
				"opening", "copy", "awaken_statues", "awaken"][i]
		elif mode == 3:
			animation = ["attack", "attack", "attack", "rift_step",
				"portal_jump", "reflection", "stone_wave", "attack"][i]
		_actor("enemy." + IDS[i], at, animation, frame, 1.5 if i >= 4 and i <= 6 else 1.0)
		var label := Label.new()
		label.text = NAMES[i]
		label.position = at + Vector2(-35, 11)
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_outline_color", Color("181021"))
		label.add_theme_constant_override("outline_size", 4)
		_actors.add_child(label)
	_actor("player.hunter", center + Vector2(-80, 220), "move", 0)
	_actor("monster.glimmerwing", center + Vector2(80, 220), "move", 0)
	_caption.text = "ENFANTS DE LA FAILLE · CARTE 22 · ZOOM 1,3333 · ÉLITES ×1,5 · BANC STATIQUE"


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
	for i: int in 2:
		var suffix := "" if i == 0 else "_%d" % i
		var path := _assets.path_join("assets/environments/rune_sanctum/map%s.webp" % suffix)
		var image := Image.load_from_file(path)
		assert(image != null and image.get_size() == Vector2i(3762, 11286))
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
	_show(Vector2(1672, 1180), 0)
	await _save("enfants_dalles_zoom_jeu")
	_show(Vector2(2307, 803), 0)
	await _save("enfants_corruption_zoom_jeu")
	_show(Vector2(1672, 1180), 1, 3)
	await _save("enfants_attaques_zoom_jeu")
	_show(Vector2(1672, 1180), 2, 3)
	await _save("enfants_techniques_1_zoom_jeu")
	_show(Vector2(1672, 1180), 3, 3)
	await _save("enfants_techniques_2_zoom_jeu")
	for frame: int in 6:
		_show(Vector2(1672, 1180), 0, frame)
		await _save("mouvement_%02d" % frame)
	for child: Node in _world.get_children():
		if child != _actors:
			child.free()
	var image := Image.load_from_file(_map24)
	assert(image != null and image.get_size() == Vector2i(3300, 3300))
	var ground := Sprite2D.new()
	ground.texture = ImageTexture.create_from_image(image)
	ground.centered = false
	ground.scale = Vector2.ONE / .75
	_world.add_child(ground)
	_world.move_child(ground, 0)
	for actor: Node in _actors.get_children():
		actor.free()
	var center := Vector2(1342, 378.4)
	_world.position = Vector2(640, 360) - center * ZOOM
	_actor("enemy.awakened_statue", center + Vector2(0, 20), "dormant", 0)
	_actor("player.hunter", center + Vector2(-105, 70), "move", 0)
	_actor("monster.glimmerwing", center + Vector2(100, 70), "move", 0)
	_caption.text = "STATUE · SOCLE S01 CARTE 24 · 110u · ZOOM 1,3333 · BANC STATIQUE"
	await _save("statue_socle_carte24_zoom_jeu")
	print("RIFTBORN_PREVIEW_OK 12 captures ; aucun profil ni gameplay")
	get_tree().quit()
