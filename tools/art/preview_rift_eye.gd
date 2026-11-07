extends Node
## Banc statique en lecture seule : aucun profil, objectif, collision ou combat.

const WORLD := 5016.0
const ZOOM := 1.3333
const WITNESSES := ["enemy.husk", "enemy.cinder_knight", "enemy.glass_sentinel",
	"enemy.ice_knight", "enemy.rift_breach"]

var _root: String
var _assets: String
var _out: String
var _world: Node2D
var _actors: Node2D
var _caption: Label
var _entries: Dictionary
var _plan: Dictionary
var _cache: Dictionary = {}


func _ready() -> void:
	_root = get_script().resource_path.get_base_dir().path_join("../..").simplify_path()
	_assets = _root
	_out = _root.path_join("docs/previews/rift-eye")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--assets-root="):
			_assets = arg.trim_prefix("--assets-root=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	call_deferred("_capture")


func _point(record: Dictionary) -> Vector2:
	var p: Array = record["pixel_reference"]
	return Vector2(float(p[0]), float(p[1])) * 4.0


func _actor(id: String, at: Vector2) -> void:
	assert(_entries.has(id), "Témoin absent : " + id)
	var entry: Dictionary = _entries[id]
	var path: String = _assets.path_join(String(entry["sheet"]).trim_prefix("res://"))
	if not _cache.has(path):
		_cache[path] = Image.load_from_file(path)
	var sheet: Image = _cache[path]
	assert(sheet != null)
	var cell: Array = entry["cell"]
	var frame := sheet.get_region(Rect2i(0, 0, int(cell[0]), int(cell[1])))
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(frame)
	sprite.centered = false
	sprite.offset = -Vector2(entry["anchor"][0], entry["anchor"][1])
	sprite.scale = Vector2.ONE * float(entry["scale"])
	sprite.position = at
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actors.add_child(sprite)


func _view(center: Vector2, label: String, witnesses := false, on_surface := false) -> void:
	for actor: Node in _actors.get_children():
		actor.free()
	_world.scale = Vector2.ONE * ZOOM
	_world.position = Vector2(640, 360) - center * ZOOM
	_actor("player.hunter", center + (Vector2(-30, 15) if on_surface else Vector2(-80, 120)))
	_actor("monster.glimmerwing", center + (Vector2(30, 15) if on_surface else Vector2(80, 120)))
	if witnesses:
		for i: int in WITNESSES.size():
			var offset := Vector2(-240 + i * 120, -40 + (i % 2) * 50)
			if on_surface:
				offset = Vector2(-150 + i * 150, -70) if i < 3 else Vector2(-75 + (i - 3) * 150, 80)
				if i == 4:
					offset = Vector2(230, 130)
			_actor(WITNESSES[i], center + offset)
	_caption.text = "CARTE 25 · " + label + " · ZOOM 1,3333 · BANC STATIQUE"
	if witnesses:
		_caption.text += " · C5 : TÉMOIN PROVISOIRE"


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
	var catalog := FileAccess.get_file_as_string(_assets.path_join("assets/asset_manifest.json"))
	_entries = JSON.parse_string(catalog)["entries"]
	var plan_path := _root.path_join("assets/concepts/incoming/map.rift_eye/plan.json")
	_plan = JSON.parse_string(FileAccess.get_file_as_string(plan_path))
	_world = Node2D.new()
	add_child(_world)
	for i: int in 3:
		var suffix := "" if i == 0 else "_%d" % i
		var path := _root.path_join("assets/environments/rift_eye/map%s.webp" % suffix)
		var image := Image.load_from_file(path)
		assert(image != null and image.get_size() == Vector2i(3762, 11286))
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.centered = false
		sprite.position = Vector2(i * WORLD / 3.0, 0)
		sprite.scale = Vector2.ONE / 2.25
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_world.add_child(sprite)
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	_world.add_child(_actors)
	_caption = Label.new()
	_caption.position = Vector2(14, 12)
	_caption.add_theme_font_size_override("font_size", 14)
	_caption.add_theme_color_override("font_outline_color", Color("171025"))
	_caption.add_theme_constant_override("outline_size", 6)
	add_child(_caption)
	_world.scale = Vector2.ONE * (660.0 / WORLD)
	_world.position = Vector2(310, 30)
	_caption.text = "L’ŒIL DE LA FAILLE · DÉTAIL ENTIER · PAS DE PARTIE LANCÉE"
	await _save("ensemble_720p")
	_view(_point(_plan["start"]), "DÉPART SUD")
	await _save("depart_zoom_jeu")
	for zone: Dictionary in _plan["zones"]:
		_view(_point(zone["clear_court"]), String(zone["name"]), true)
		await _save(String(zone["id"]) + "_matiere")
		for surface: Dictionary in _plan["terrain_surfaces"]:
			if surface["zone"] == zone["id"]:
				_view(_point(surface), String(zone["name"]) + " / BRIQUE", true, true)
				await _save(String(zone["id"]) + "_brique")
				break
	for passage: Dictionary in _plan["passages"]:
		_view(_point(passage), String(passage["id"]) + " / PASSAGE")
		await _save(String(passage["id"]) + "_passage")
	var center := _point(_plan["platform"])
	_view(center, "ARÈNE / CENTRE", true)
	await _save("arene_centre")
	for cover: Dictionary in _plan["covers"]:
		if cover["zone"] == "eye":
			_view(_point(cover), "ABRI INTÉRIEUR " + String(cover["id"]))
			await _save(String(cover["id"]) + "_abri_interieur")
	_view(center + Vector2(0, -170), "DÉVOREUR EXISTANT / GABARIT, PAS DE COMBAT")
	for actor: Node in _actors.get_children():
		actor.free()
	_actor("boss.source_devourer", center)
	_actor("player.hunter", center + Vector2(-220, 70))
	_actor("monster.glimmerwing", center + Vector2(220, 70))
	await _save("devoreur_gabarit")
	print("PREVIEW_OK 23 captures ; sprites natifs, aucun profil ni navigation")
	get_tree().quit()
