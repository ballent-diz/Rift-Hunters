extends Node
## Captures fixes d'échelle, sans autoload, profil ou simulation de combat.

const ZOOM := 1.3333
const POINTS := [Vector2(1660, 2015), Vector2(1660, 3210), Vector2(1670, 4680),
	Vector2(645, 1815), Vector2(2710, 1815), Vector2(600, 620), Vector2(1590, 2290)]
const NAMES := ["central", "sud", "entree", "berge_ouest", "berge_est", "terrasse", "temple"]

var _root: String
var _assets: String
var _old: String
var _new: String
var _out: String
var _manifest: Dictionary
var _world: Node2D
var _actors: Node2D
var _caption: Label
var _sheets: Dictionary = {}


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--art-root="):
			_root = arg.trim_prefix("--art-root=")
		elif arg.begins_with("--assets-root="):
			_assets = arg.trim_prefix("--assets-root=")
		elif arg.begins_with("--old="):
			_old = arg.trim_prefix("--old=")
		elif arg.begins_with("--new="):
			_new = arg.trim_prefix("--new=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	assert(_assets != "" and _old != "" and _new != "" and _out != "")
	call_deferred("_capture")


func _actor(id: String, at: Vector2) -> void:
	var e: Dictionary = _manifest[id]
	var path: String = _assets.path_join(String(e["sheet"]).trim_prefix("res://"))
	if not _sheets.has(path):
		_sheets[path] = Image.load_from_file(path)
	var sheet: Image = _sheets[path]
	var cell: Array = e["cell"]
	var a: Dictionary = e["animations"]["move"]
	var pose := sheet.get_region(Rect2i(0, int(a["row"]) * int(cell[1]), int(cell[0]), int(cell[1])))
	var shadow := Node2D.new()
	shadow.position = at
	shadow.scale = Vector2(1, .3)
	shadow.draw.connect(func() -> void: shadow.draw_circle(Vector2.ZERO, 12, Color(0, 0, .02, .3)))
	_actors.add_child(shadow)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(pose)
	sprite.centered = false
	sprite.offset = -Vector2(float(e["anchor"][0]), float(e["anchor"][1]))
	sprite.position = at
	sprite.scale = Vector2.ONE * float(e["scale"])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actors.add_child(sprite)


func _ground(folder: String, center: Vector2) -> void:
	for node: Node in _world.get_children():
		node.free()
	_world.scale = Vector2.ONE * ZOOM
	_world.position = Vector2(640, 360) - (center + Vector2(0, -35)) * ZOOM
	var view := Rect2(center - Vector2(500, 330), Vector2(1000, 600))
	for i: int in 2:
		var tile := Rect2(Vector2(i * 1672, 0), Vector2(1672, 5016))
		if not tile.intersects(view):
			continue
		var suffix := "" if i == 0 else "_1"
		var image := Image.load_from_file(folder.path_join("map%s.webp" % suffix))
		assert(image != null and image.get_size() == Vector2i(3762, 11286))
		var crop := tile.intersection(view)
		var region := Rect2i(Vector2i((crop.position - tile.position) * 2.25), Vector2i(crop.size * 2.25))
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(image.get_region(region))
		sprite.centered = false
		sprite.position = tile.position + Vector2(region.position) / 2.25
		sprite.scale = Vector2.ONE / 2.25
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_world.add_child(sprite)
	_actors = Node2D.new()
	_world.add_child(_actors)


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
	_manifest = JSON.parse_string(FileAccess.get_file_as_string(
		_assets.path_join("assets/asset_manifest.json")))["entries"]
	_world = Node2D.new()
	add_child(_world)
	_caption = Label.new()
	_caption.position = Vector2(12, 12)
	_caption.add_theme_font_size_override("font_size", 14)
	_caption.add_theme_color_override("font_outline_color", Color("101820"))
	_caption.add_theme_constant_override("outline_size", 5)
	add_child(_caption)
	for i: int in POINTS.size():
		for version: String in ["avant", "apres"]:
			var center: Vector2 = POINTS[i]
			_ground(_old if version == "avant" else _new, center)
			var hunter := center + Vector2(-55, 5)
			var ashblade := center + Vector2(55, 5)
			if i == 0:
				hunter = Vector2(1580, 2010)
				ashblade = Vector2(1640, 2010)
			elif i == 3:
				hunter = center + Vector2(-35, -14)
				ashblade = center + Vector2(35, 14)
			elif i == 4:
				hunter = center + Vector2(-35, 14)
				ashblade = center + Vector2(35, -14)
			elif i == 5:
				hunter = Vector2(450, 650)
				ashblade = Vector2(520, 650)
			_actor("player.hunter", hunter)
			_actor("monster.ashblade", ashblade)
			_caption.text = "CŒUR DES MARAIS · " + NAMES[i].to_upper() + " · " + version.to_upper()
			_caption.text += " · ZOOM 1,3333 · SPRITES INCHANGÉS · BANC STATIQUE"
			await _save(NAMES[i] + "_" + version + "_zoom_jeu")
	print("MARSH_SCALE_PREVIEW_OK 14")
	get_tree().quit()
