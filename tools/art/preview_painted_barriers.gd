extends Node
## Banc de validation artistique C1 : sol réel, sprites natifs, aucune simulation.

const ZOOM := 1.3333
const CENTER := Vector2(2700, 700)

var _root: String
var _assets: String
var _out: String
var _manifest: Dictionary
var _world: Node2D
var _actors: Node2D
var _caption: Label
var _cache: Dictionary = {}


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--art-root="):
			_root = arg.trim_prefix("--art-root=")
		elif arg.begins_with("--assets-root="):
			_assets = arg.trim_prefix("--assets-root=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	assert(_root != "" and _assets != "" and _out != "")
	call_deferred("_capture")


func _sprite(id: String, at: Vector2, animation: String, frame: int) -> void:
	var entry: Dictionary = _manifest[id]
	var base := _root if id.begins_with("object.barrier_1") else _assets
	var path := base.path_join(String(entry["sheet"]).trim_prefix("res://"))
	if not _cache.has(path):
		_cache[path] = Image.load_from_file(path)
	var image: Image = _cache[path]
	assert(image != null, path)
	var cell: Array = entry["cell"]
	var anim: Dictionary = entry["animations"][animation]
	var region := Rect2i(frame % int(anim["frames"]) * int(cell[0]),
		int(anim["row"]) * int(cell[1]), int(cell[0]), int(cell[1]))
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image.get_region(region))
	sprite.centered = false
	sprite.offset = -Vector2(float(entry["anchor"][0]), float(entry["anchor"][1]))
	sprite.position = at
	sprite.scale = Vector2.ONE * float(entry["scale"])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actors.add_child(sprite)


func _ground() -> void:
	var view := Rect2(CENTER - Vector2(480, 270), Vector2(960, 540))
	for i: int in 3:
		var tile := Rect2(Vector2(i * 1672, 0), Vector2(1672, 1672))
		if not tile.intersects(view):
			continue
		var suffix := "" if i == 0 else "_%d" % i
		var path := _assets.path_join("assets/environments/cascade_ruins/map%s.webp" % suffix)
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


func _seal(at: Vector2, variant: String, state: String, frame: int) -> void:
	_sprite("object.barrier_1.seal_" + variant, at, state, frame)


func _scene(kind: String, state: String, frame: int) -> void:
	for child: Node in _actors.get_children():
		child.free()
	var origin := CENTER + Vector2(-256, 25)
	var seal_state := "open" if state == "dissolve" else "idle"
	var seal_frame := mini(frame / 2, 5) if state == "dissolve" else (frame / 2) % 6
	if kind == "droite":
		for i: int in 4:
			_sprite("object.barrier_1", origin + Vector2(i * 128, 0), state, frame)
		_seal(origin, "a", seal_state, seal_frame)
		_seal(origin + Vector2(512, 0), "b", seal_state, seal_frame)
		_sprite("player.hunter", CENTER + Vector2(-100, 82), "move", 0)
		_sprite("monster.ashblade", CENTER + Vector2(105, 3), "move", 0)
	elif kind == "angle":
		origin = CENTER + Vector2(-160, -65)
		_sprite("object.barrier_1", origin, state, frame)
		_sprite("object.barrier_1.corner", origin + Vector2(128, 0), state, frame)
		_sprite("object.barrier_1.bias", origin + Vector2(192, 64), state, frame)
		_seal(origin, "a", seal_state, seal_frame)
		_seal(origin + Vector2(192, 0), "b", seal_state, seal_frame)
		_seal(origin + Vector2(192, 192), "a", seal_state, seal_frame)
		_sprite("player.hunter", CENTER + Vector2(-105, 80), "move", 0)
		_sprite("monster.ashblade", CENTER + Vector2(120, 85), "move", 0)
	else:
		origin = CENTER + Vector2(0, -140)
		for i: int in 3:
			_sprite("object.barrier_1.bias", origin + Vector2(0, i * 128), state, frame)
		_seal(origin, "a", seal_state, seal_frame)
		_seal(origin + Vector2(0, 384), "b", seal_state, seal_frame)
		_sprite("player.hunter", CENTER + Vector2(-95, 60), "move", 0)
		_sprite("monster.ashblade", CENTER + Vector2(105, 100), "move", 0)
	_caption.text = "PROPOSITION C1 · RUINES · " + kind.to_upper() + " · " + state.to_upper()
	_caption.text += " · ZOOM 1,3333 · BANC VISUEL, COLLISIONS INCHANGÉES"


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1280, 720))
	assert(image.save_png(_out.path_join(name + ".png")) == OK)


func _capture() -> void:
	_manifest = JSON.parse_string(FileAccess.get_file_as_string(_root.path_join("assets/asset_manifest.json")))["entries"]
	DirAccess.make_dir_recursive_absolute(_out)
	_world = Node2D.new()
	_world.scale = Vector2.ONE * ZOOM
	_world.position = Vector2(640, 360) - CENTER * ZOOM
	add_child(_world)
	_ground()
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	_world.add_child(_actors)
	_caption = Label.new()
	_caption.position = Vector2(12, 10)
	_caption.add_theme_font_size_override("font_size", 13)
	_caption.add_theme_color_override("font_outline_color", Color("121524"))
	_caption.add_theme_constant_override("outline_size", 4)
	add_child(_caption)
	for kind: String in ["droite", "angle", "verticale"]:
		_scene(kind, "loop", 3)
		await _save(kind + "_zoom_jeu")
	_scene("droite", "dissolve", 11)
	await _save("bornes_ouvertes_zoom_jeu")
	var index := 0
	for state: String in ["appear", "loop", "loop", "dissolve"]:
		var count := 10 if state == "appear" else (12 if state == "dissolve" else 16)
		for frame: int in count:
			_scene("droite", state, frame)
			await _save("animation_%03d" % index)
			index += 1
	print("BARRIER_PREVIEW_OK 4 captures + ", index, " poses au zoom natif")
	get_tree().quit()
