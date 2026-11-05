extends Node
## Composition de la carte21 : feuilles existantes et caméra réelle, sans partie ni profil écrit.

const COMPOSITION := "res://assets/concepts/incoming/map.shattered_outskirts/composition.png"
const REVIEW := "res://assets/concepts/incoming/map.shattered_outskirts/source/composition_review.json"
const WITNESSES: Array[StringName] = [
	&"wandering_shard", &"glass_sentinel", &"quartz_golem",
	&"hush_shard", &"ice_knight", &"silence_herald",
]

var _world: Node2D
var _actors: Node2D
var _hunter: EntityVisual
var _echo: EntityVisual
var _caption: Label
var _out := "/tmp/rift-shattered-outskirts"


func _ready() -> void:
	Profile.read_only = true
	call_deferred("_capture")


func _actor(visual: VisualData, frame: int = 0) -> EntityVisual:
	var actor := EntityVisual.new()
	_actors.add_child(actor)
	actor.setup(visual)
	assert(actor.has_sheet(), "Feuille absente : " + String(visual.visual_id))
	for child: Node in actor.get_children():
		if child is AnimatedSprite2D:
			var animation := &"idle" if child.sprite_frames.has_animation(&"idle") else &"move"
			child.play(animation)
			child.pause()
			child.frame = frame % child.sprite_frames.get_frame_count(animation)
	return actor


func _camera(center: Vector2) -> void:
	var zoom: float = GameDB.balance.camera_zoom
	_world.scale = Vector2.ONE * zoom
	var camera_center := Vector2(clampf(center.x, 480, 4536), clampf(center.y, 270, 3074))
	_world.position = Vector2(640, 360) - camera_center * zoom
	_hunter.position = center + Vector2(-100, 100)
	_echo.position = center + Vector2(120, 110)


func _save(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1280, 720))
	assert(image.save_png(_out.path_join(name + ".png")) == OK)


func _witnesses(center: Vector2, surface: String) -> void:
	_camera(center)
	_hunter.position = center + Vector2(-225, 120)
	_echo.position = center + Vector2(225, 120)
	var actors: Array[EntityVisual] = []
	for i: int in WITNESSES.size():
		var enemy := GameDB.enemy(WITNESSES[i])
		assert(enemy != null)
		var actor := _actor(enemy.visual, i % 6)
		actor.position = center + Vector2((i % 3 - 1) * 105, -50 if i < 3 else 85)
		actors.append(actor)
	_caption.text = "COMPOSITION 21 · REFLETS CH3 / ÉCHOS DU SILENCE CH4 · %s · ZOOM RÉEL" % surface.to_upper()
	await _save("lisibilite_" + surface)
	for actor: EntityVisual in actors:
		actor.queue_free()
	await get_tree().process_frame


func _capture() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	_world = Node2D.new()
	add_child(_world)
	var composition := Image.load_from_file(ProjectSettings.globalize_path(COMPOSITION))
	assert(composition != null and composition.get_size() == Vector2i(1536, 1024))
	var ground := Sprite2D.new()
	ground.texture = ImageTexture.create_from_image(composition)
	ground.centered = false
	ground.scale = Vector2.ONE * (5016.0 / 1536.0)
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_world.add_child(ground)
	_caption = Label.new()
	_caption.position = Vector2(15, 12)
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_color_override("font_outline_color", Color("252333"))
	_caption.add_theme_constant_override("outline_size", 7)
	add_child(_caption)
	_world.scale = Vector2.ONE * (900.0 / 5016.0)
	_world.position = Vector2(190, 70)
	_caption.text = "CARTE 21 · LES FAUBOURGS BRISÉS · COMPOSITION ENTIÈRE À VALIDER"
	await _save("ensemble_720p")
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	_actors.z_index = 2
	_world.add_child(_actors)
	_hunter = _actor(GameDB.balance.player_visual)
	_echo = _actor(GameDB.enemy(&"snow_wraith").visual)
	for spec: Array in [["facade", Vector2(1100, 2180)], ["escalier", Vector2(3520, 1300)],
			["arche", Vector2(2350, 1770)], ["beffroi", Vector2(4770, 750)],
			["depart", Vector2(853, 2910)]]:
		_camera(spec[1])
		if spec[0] == "facade":
			_hunter.position = Vector2(1070, 2325)
			_echo.position = Vector2(1210, 2325)
		elif spec[0] == "escalier":
			_hunter.position = Vector2(3450, 1320)
			_echo.position = Vector2(3540, 1240)
		_caption.text = "COMPOSITION 21 · %s · CHASSEUR / ÉCHO · ZOOM RÉEL" % String(spec[0]).to_upper()
		await _save(String(spec[0]) + "_zoom_jeu")
	await _witnesses(Vector2(1710, 2390), "dalles")
	await _witnesses(Vector2(1670, 1765), "corruption")
	var receipt := {"viewport": [1280, 720], "camera_zoom": GameDB.balance.camera_zoom,
		"composition_sha256": FileAccess.get_sha256(COMPOSITION), "scope": "composition_seule",
		"review_sha256": FileAccess.get_sha256(REVIEW), "profile_read_only": Profile.read_only,
		"native_sprites_unchanged": true, "witness_ids": WITNESSES,
		"chapter5_sprites_created": false, "runtime_integrated": false, "collision_mask_created": false}
	var file := FileAccess.open(_out.path_join("capture_receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	print("SHATTERED_OUTSKIRTS_COMPOSITION_OK")
	get_tree().quit(0)
