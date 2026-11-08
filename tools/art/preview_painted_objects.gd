extends Node
## Banc visuel statique : véritables tuiles et sprites, aucun profil ni combat.

const ZOOM := 1.3333
const OWN := ["object.mirror_portal", "object.mirror_portal.sage", "object.mirror_portal.pale_gold",
	"object.mirror_portal.lilac_grey", "object.crystal_mirror", "object.crystal_mirror.marsh_heart", "object.training_dummy"]
const PAIR_NAMES := ["SARCELLE", "SAUGE", "OR PÂLE", "GRIS LILAS"]

var _root: String
var _assets: String
var _out: String
var _manifest: Dictionary
var _world: Node2D
var _actors: Node2D
var _caption: Label
var _center := Vector2.ZERO
var _cache: Dictionary = {}
var _count := 0


func _ready() -> void:
	_root = get_script().resource_path.get_base_dir().path_join("../..").simplify_path()
	_assets = _root
	_out = _root.path_join("docs/previews/objets-peints")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--art-root="):
			_root = arg.trim_prefix("--art-root=")
		elif arg.begins_with("--assets-root="):
			_assets = arg.trim_prefix("--assets-root=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	call_deferred("_capture")


func _actor(id: String, at: Vector2, animation: String, frame: int) -> void:
	var entry: Dictionary = _manifest[id]
	var base := _root if OWN.has(id) else _assets
	var path: String = base.path_join(String(entry["sheet"]).trim_prefix("res://"))
	if not _cache.has(path):
		_cache[path] = Image.load_from_file(path)
	var sheet: Image = _cache[path]
	assert(sheet != null, path)
	var cell: Array = entry["cell"]
	var anim: Dictionary = entry["animations"][animation]
	var region := Rect2i(frame % int(anim["frames"]) * int(cell[0]),
		int(anim["row"]) * int(cell[1]), int(cell[0]), int(cell[1]))
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(sheet.get_region(region))
	sprite.centered = false
	sprite.offset = -Vector2(float(entry["anchor"][0]), float(entry["anchor"][1]))
	sprite.position = at
	sprite.scale = Vector2.ONE * float(entry["scale"])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actors.add_child(sprite)


func _background(folder: String, center: Vector2, caption: String) -> void:
	for child: Node in _world.get_children():
		child.free()
	_center = center
	_world.scale = Vector2.ONE * ZOOM
	_world.position = Vector2(640, 360) - center * ZOOM
	if folder != "training":
		var view := Rect2(center - Vector2(500, 290), Vector2(1000, 580))
		var count := 2 if folder == "marsh_heart" else 3
		var tile_height := 1672.0 if folder == "crystal_gardens" else 5016.0
		for i: int in count:
			var tile := Rect2(Vector2(i * 1672, 0), Vector2(1672, tile_height))
			if not tile.intersects(view):
				continue
			var suffix := "" if i == 0 else "_%d" % i
			var path := _assets.path_join("assets/environments/%s/map%s.webp" % [folder, suffix])
			var image := Image.load_from_file(path)
			assert(image != null, path)
			var crop := tile.intersection(view)
			var region := Rect2i(Vector2i((crop.position - tile.position) * 2.25), Vector2i(crop.size * 2.25))
			var ground := Sprite2D.new()
			ground.texture = ImageTexture.create_from_image(image.get_region(region))
			ground.centered = false
			ground.position = tile.position + Vector2(region.position) / 2.25
			ground.scale = Vector2.ONE / 2.25
			ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			_world.add_child(ground)
	else:
		# Copie à l'identique de ArenaGround._draw_placeholder(), avec ses couleurs et sa graine.
		var floor_script: Script = load("res://tools/art/preview_training_floor.gd")
		_world.add_child(floor_script.new())
	_actors = Node2D.new()
	_world.add_child(_actors)
	_caption.text = caption + " · ZOOM 1,3333 · BANC VISUEL"


func _label(text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color("141923"))
	label.add_theme_constant_override("outline_size", 4)
	_actors.add_child(label)


func _witnesses(at: Vector2, distance := 160.0) -> void:
	_actor("player.hunter", at + Vector2(-distance, 0), "move", 0)
	_actor("monster.glimmerwing", at + Vector2(distance, 0), "move", 0)


func _original(kind: String, at: Vector2, state: String) -> void:
	var scene: PackedScene = load("res://assets/vfx/objects/%s/%s.tscn" % [kind, kind])
	var visual: Node2D = scene.instantiate()
	visual.position = at
	if kind == "mirror_portal":
		visual.set("radius", 34.0)
		visual.set("tint", Color(.36, .6, .64))
		visual.modulate = Color(.82, .86, .84)
	_actors.add_child(visual)
	visual.call("play", state)
	visual.call("seek_visual", .25)


func _save(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1280, 720))
	assert(image.save_png(_out.path_join(name + ".png")) == OK)
	_count += 1
	print("CAPTURE_OK ", name)


func _portal_states(frame: int) -> void:
	_background("reflection_wells", Vector2(2508, 2750), "CARTE 14 · ÉTATS DES PORTAILS PEINTS")
	var states := ["active", "cooldown", "enter", "exit"]
	for i: int in 4:
		var at := _center + Vector2(-270 + i * 180, 30)
		_actor(OWN[i], at, states[i], frame)
		_label(PAIR_NAMES[i] + " · " + states[i], at + Vector2(-58, 20))
	_witnesses(_center + Vector2(0, 150), 100)


func _crystal_states(id: String, folder: String, at: Vector2, frame: int) -> void:
	_background(folder, at + Vector2(0, -25), "CRISTAL PEINT · " + folder.to_upper())
	var states := ["idle", "charged", "burst", "debris", "hidden"]
	for i: int in 5:
		var point := at + Vector2(-280 + i * 140, 0)
		_actor(id, point, states[i], frame)
		_label(states[i], point + Vector2(-20, 20))
	_witnesses(at + Vector2(0, 150), 100)


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	_manifest = JSON.parse_string(FileAccess.get_file_as_string(
		_assets.path_join("assets/asset_manifest.json")))["entries"]
	var own: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		_root.path_join("assets/asset_manifest.json")))["entries"]
	for id: String in OWN:
		_manifest[id] = own[id]
	_world = Node2D.new()
	add_child(_world)
	_caption = Label.new()
	_caption.position = Vector2(14, 12)
	_caption.add_theme_font_size_override("font_size", 14)
	_caption.add_theme_color_override("font_outline_color", Color("141923"))
	_caption.add_theme_constant_override("outline_size", 5)
	add_child(_caption)
	var portal_at := Vector2(702, 602) # premier portail réel : (-1806,-1906) + demi-carte
	for version: String in ["original", "peint"]:
		_background("reflection_wells", portal_at + Vector2(0, -25), "CARTE 14 · PORTAIL " + version.to_upper())
		if version == "original":
			_original("mirror_portal", portal_at, "active")
		else:
			_actor(OWN[0], portal_at, "active", 0)
		_witnesses(portal_at)
		await _save("portail_" + version + "_zoom_jeu")
	_background("reflection_wells", Vector2(2508, 2750), "CARTE 14 · QUATRE PAIRES · MÊMES CADRES, LUEURS DISCRÈTES")
	for row: int in 2:
		for i: int in 4:
			var at := _center + Vector2(-300 + i * 200, -30 + row * 190)
			_actor(OWN[i], at, "active", 0)
			_label(PAIR_NAMES[i], at + Vector2(-34, 15))
	_witnesses(_center + Vector2(0, 75), 415)
	await _save("portails_quatre_paires_zoom_jeu")
	for frame: int in 6:
		_portal_states(frame)
		await _save("portails_mouvement_%02d" % frame)
	var crystal_ids := ["object.crystal_mirror", "object.crystal_mirror.marsh_heart"]
	var folders := ["crystal_gardens", "marsh_heart"]
	var centers := [Vector2(708, 586), Vector2(1150, 1362)]
	for i: int in 2:
		for version: String in ["original", "peint"]:
			_background(folders[i], centers[i] + Vector2(0, -25), "CRISTAL · " + folders[i] + " · " + version)
			if version == "original":
				_original("mirror_crystal", centers[i], "idle")
			else:
				_actor(crystal_ids[i], centers[i], "idle", 0)
			_witnesses(centers[i])
			await _save("cristal_%d_%s_zoom_jeu" % [13 if i == 0 else 15, version])
		for frame: int in 6:
			_crystal_states(crystal_ids[i], folders[i], centers[i], frame)
			await _save("cristal_%d_mouvement_%02d" % [13 if i == 0 else 15, frame])
	for frame: int in 6:
		_background("training", Vector2(0, -25), "MANNEQUIN · SOL ACTUEL DE LA SALLE D'ENTRAÎNEMENT")
		_actor("object.training_dummy", Vector2(-90, 0), "idle", frame)
		_actor("object.training_dummy", Vector2(90, 0), "hit", frame)
		_label("idle", Vector2(-110, 20))
		_label("hit", Vector2(75, 20))
		_witnesses(Vector2(0, 0), 240)
		await _save("mannequin_mouvement_%02d" % frame)
	print("PAINTED_OBJECTS_PREVIEW_OK ", _count)
	get_tree().quit()
