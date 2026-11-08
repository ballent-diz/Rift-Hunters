extends Node
## Banc statique de proportions, sans profil, combat ou données de boss.

const ZOOM := 1.3333
const CENTER := Vector2(2492, 2272)
const PHASES := ["boss.abyssarch", "boss.abyssarch.roots", "boss.abyssarch.magma",
	"boss.abyssarch.crystal", "boss.abyssarch.ice", "boss.abyssarch.rift", "boss.abyssarch.death"]

var _root: String
var _assets: String
var _map_root: String
var _out: String
var _manifest: Dictionary
var _world: Node2D
var _actors: Node2D
var _caption: Label
var _cache: Dictionary = {}
var _active_phase := ""


func _ready() -> void:
	_root = get_script().resource_path.get_base_dir().path_join("../..").simplify_path()
	_assets = _root
	_map_root = _root
	_out = _root.path_join("docs/previews/abyssarque")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--assets-root="):
			_assets = arg.trim_prefix("--assets-root=")
		elif arg.begins_with("--map-root="):
			_map_root = arg.trim_prefix("--map-root=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	call_deferred("_capture")


func _actor(id: String, at: Vector2, animation: String, frame: int) -> void:
	var entry: Dictionary = _manifest[id]
	var own := PHASES.has(id)
	if own and _active_phase != id:
		for key: String in _cache.keys():
			if key.begins_with(_root):
				_cache.erase(key)
		_active_phase = id
	var base: String = _root if own else _assets
	var path: String = base.path_join(String(entry["sheet"]).trim_prefix("res://"))
	if not _cache.has(path):
		_cache[path] = Image.load_from_file(path)
	var sheet: Image = _cache[path]
	assert(sheet != null, id)
	var cell: Array = entry["cell"]
	var anim: Dictionary = entry["animations"][animation]
	var region := Rect2i(frame % int(anim["frames"]) * int(cell[0]),
		int(anim["row"]) * int(cell[1]), int(cell[0]), int(cell[1]))
	var pose := sheet.get_region(region)
	var shadow := Node2D.new()
	shadow.position = at + Vector2(0, 225 if own else 1)
	shadow.scale = Vector2(1, .28 if own else .38)
	var radius := 8.0
	if own:
		radius = clampf(pose.get_used_rect().size.x * float(entry["scale"]) * .28, 8, 140)
	shadow.draw.connect(func() -> void:
		shadow.draw_circle(Vector2.ZERO, radius, Color(0, 0, .03, .35)))
	_actors.add_child(shadow)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(pose)
	sprite.centered = false
	sprite.offset = -Vector2(float(entry["anchor"][0]), float(entry["anchor"][1]))
	sprite.position = at
	sprite.scale = Vector2.ONE * float(entry["scale"])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actors.add_child(sprite)


func _show(id: String, animation: String, frame: int, caption: String, zoom := ZOOM) -> void:
	for actor: Node in _actors.get_children():
		actor.free()
	_world.scale = Vector2.ONE * zoom
	_world.position = Vector2(640, 360) - (CENTER + Vector2(0, -35)) * zoom
	_actor(id, CENTER, animation, frame)
	_actor("player.hunter", CENTER + Vector2(-400, 0), "move", 0)
	_actor("monster.glimmerwing", CENTER + Vector2(400, 0), "move", 0)
	_caption.text = "ABYSSARQUE · " + caption + " · ZOOM %.4f · BANC STATIQUE" % zoom


func _save(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1280, 720))
	assert(image.save_png(_out.path_join(name + ".png")) == OK)
	print("CAPTURE_OK ", name)


func _label(text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color("181021"))
	label.add_theme_constant_override("outline_size", 4)
	_actors.add_child(label)


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	_manifest = JSON.parse_string(FileAccess.get_file_as_string(
		_assets.path_join("assets/asset_manifest.json")))["entries"]
	var own: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		_root.path_join("assets/asset_manifest.json")))["entries"]
	for id: String in PHASES:
		_manifest[id] = own[id]
	_world = Node2D.new()
	add_child(_world)
	for i: int in 3:
		var suffix := "" if i == 0 else "_%d" % i
		var path := _map_root.path_join("assets/environments/rift_eye/map%s.webp" % suffix)
		var image := Image.load_from_file(path)
		assert(image != null and image.get_size() == Vector2i(3762, 11286))
		# Même image finale, région utile seulement pour réduire la mémoire du banc.
		var ground := Sprite2D.new()
		ground.texture = ImageTexture.create_from_image(image.get_region(Rect2i(0, 3000, 3762, 4800)))
		ground.centered = false
		ground.position = Vector2(i * 1672, 3000.0 / 2.25)
		ground.scale = Vector2.ONE / 2.25
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_world.add_child(ground)
	_actors = Node2D.new()
	_world.add_child(_actors)
	_caption = Label.new()
	_caption.position = Vector2(14, 12)
	_caption.add_theme_font_size_override("font_size", 14)
	_caption.add_theme_color_override("font_outline_color", Color("181021"))
	_caption.add_theme_constant_override("outline_size", 5)
	add_child(_caption)
	var animations := ["idle", "roots_attack", "magma_attack", "crystal_attack", "ice_attack"]
	var titles := ["CORPS 450u", "RACINES ET CASCADES", "MAGMA",
		"CRISTAL ET MIROIRS", "GLACE ET SILENCE"]
	var files := ["base", "racines", "magma", "cristal", "glace"]
	for i: int in 5:
		_show(PHASES[i], animations[i], 0 if i == 0 else 3, titles[i])
		await _save("abyssarch_" + files[i] + "_zoom_jeu")
	_show(PHASES[5], "ray_sweep", 3, "CŒUR-ŒIL OUVERT · POSTURE DU RAYON")
	await _save("abyssarch_faille_zoom_jeu")
	_show(PHASES[5], "summon", 3, "INVOCATION · GESTE SEUL")
	await _save("abyssarch_invocation_zoom_jeu")
	_show(PHASES[6], "collapse", 3, "MORT · EFFONDREMENT")
	await _save("abyssarch_effondrement_zoom_jeu")
	_show(PHASES[6], "eye_close", 5, "MORT · ŒIL REFERMÉ")
	await _save("abyssarch_oeil_ferme_zoom_jeu")
	_show(PHASES[0], "idle", 0, "QUATRE ABRIS INTÉRIEURS · VUE DE CONTEXTE", .6667)
	await _save("abyssarch_contexte_abris")
	for actor: Node in _actors.get_children():
		actor.free()
	_world.scale = Vector2.ONE * ZOOM
	_world.position = Vector2(640, 360) - (CENTER + Vector2(0, -35)) * ZOOM
	_actor(PHASES[0], CENTER + Vector2(-160, 0), "idle", 0)
	_actor("boss.nivorath", CENTER + Vector2(280, -50), "idle", 0)
	_actor("boss.source_devourer", CENTER + Vector2(280, 185), "idle", 0)
	_actor("player.hunter", CENTER + Vector2(-430, 0), "move", 0)
	_actor("monster.glimmerwing", CENTER + Vector2(430, 0), "move", 0)
	_label("Nivorath : 150u", CENTER + Vector2(215, -35))
	_label("Dévoreur des Sources : 188u", CENTER + Vector2(185, 200))
	_caption.text = "ABYSSARQUE : 450u · ANCIENS DÉVOREURS INCHANGÉS · ZOOM 1,3333 · BANC STATIQUE"
	await _save("abyssarch_comparaison_devoreurs_zoom_jeu")
	for frame: int in 6:
		_show(PHASES[0], "move", frame, "DÉPLACEMENT")
		await _save("mouvement_%02d" % frame)
	print("ABYSSARCH_PREVIEW_OK 17 captures ; aucun profil ni gameplay")
	get_tree().quit()
