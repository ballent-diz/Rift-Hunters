extends Node
## Banc graphique de composition et détail ; feuilles existantes, aucune partie ni donnée de niveau écrite.

const COMPOSITION := "res://assets/concepts/incoming/map.silent_heart/composition.png"
const REVIEW := "res://assets/concepts/incoming/map.silent_heart/plan.json"

var _world: Node2D
var _ground: Node2D
var _actors: Node2D
var _hunter: EntityVisual
var _echo: EntityVisual
var _caption: Label
var _phase := "COMPOSITION"
var _out := "/tmp/rift-silent-heart"


func _ready() -> void:
	Profile.read_only = true
	call_deferred("_capture")


func _actor(visual: VisualData, animation: StringName = &"idle", frame: int = 0) -> EntityVisual:
	var actor := EntityVisual.new()
	_actors.add_child(actor)
	actor.setup(visual)
	assert(actor.has_sheet(), "Feuille absente : " + String(visual.visual_id))
	for child: Node in actor.get_children():
		if child is AnimatedSprite2D:
			if not child.sprite_frames.has_animation(animation):
				animation = &"move"
			child.play(animation)
			child.pause()
			child.frame = frame % child.sprite_frames.get_frame_count(animation)
	return actor


func _image(image: Image, at: Vector2, scale_value: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.position = at
	sprite.scale = Vector2.ONE * scale_value
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ground.add_child(sprite)


func _camera(center: Vector2) -> void:
	var zoom: float = GameDB.balance.camera_zoom
	_world.scale = Vector2.ONE * zoom
	_world.position = Vector2(640, 360) - center * zoom
	_hunter.position = center + Vector2(-120, 120)
	_echo.position = center + Vector2(120, 130)


func _save(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1280, 720))
	assert(image.save_png(_out.path_join(name + ".png")) == OK)


func _silence(center: Vector2, surface: String) -> void:
	_camera(center)
	_hunter.position = center + Vector2(-240, 150)
	_echo.visible = false
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/chapitre4_catalogue.json"))
	var monsters: Array[EntityVisual] = []
	for i: int in 7:
		var visual: VisualData
		for enemy: EnemyData in GameDB.enemies.values():
			if String(enemy.visual.visual_id) == catalog[i + 7]["visual_id"]:
				visual = enemy.visual
				break
		assert(visual != null)
		var actor := _actor(visual, &"move", i % 6)
		actor.position = center + Vector2((i % 3 - 1) * 120, (i / 3 - 1) * 110)
		monsters.append(actor)
	_caption.text = "%s 20 · SEPT ÉCHOS DU SILENCE / %s · ZOOM RÉEL" % [_phase, surface.to_upper()]
	await _save("silence_" + surface)
	for actor: EntityVisual in monsters:
		actor.queue_free()
	_echo.visible = true
	await get_tree().process_frame


func _capture() -> void:
	var sample := ""
	var detail := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--detail":
			detail = true
		elif arg.begins_with("--sample="):
			sample = arg.trim_prefix("--sample=")
	_phase = "DÉTAIL" if detail or not sample.is_empty() else "COMPOSITION"
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	_world = Node2D.new()
	add_child(_world)
	_ground = Node2D.new()
	_world.add_child(_ground)
	var composition := Image.load_from_file(ProjectSettings.globalize_path(COMPOSITION))
	assert(composition != null and composition.get_size() == Vector2i(1536, 1024))
	if detail:
		for i: int in 3:
			var suffix := "" if i == 0 else "_%d" % i
			var path := "res://assets/environments/silent_heart/map%s.webp" % suffix
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			assert(image != null and image.get_size() == Vector2i(3762, 7524))
			_image(image, Vector2(i * 1672, 0), 1.0 / 2.25)
	elif sample.is_empty():
		_image(composition, Vector2.ZERO, 5016.0 / 1536.0)
	else:
		var region := Image.load_from_file(sample)
		assert(region != null)
		_image(region, Vector2(1094, 954.7), 1574.0 / region.get_width())
	_caption = Label.new()
	_caption.position = Vector2(15, 12)
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_color_override("font_outline_color", Color("15273c"))
	_caption.add_theme_constant_override("outline_size", 7)
	add_child(_caption)
	_world.scale = Vector2.ONE * (900.0 / 5016.0)
	_world.position = Vector2(190, 70)
	_caption.text = "CARTE 20 · LE CŒUR DU SILENCE · %s ENTIER" % _phase
	if sample.is_empty():
		await _save("ensemble_720p")
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	_actors.z_index = 2
	_world.add_child(_actors)
	_hunter = _actor(GameDB.balance.player_visual)
	_echo = _actor(GameDB.enemy(&"snow_wraith").visual)
	if not sample.is_empty():
		_camera(Vector2(2190, 1945))
		_hunter.position = Vector2(2100, 1940)
		_echo.position = Vector2(2280, 1940)
		_caption.text = "DÉTAIL 20 · RÉGION TÉMOIN · ESCALIER / CHASSEUR / ÉCHO · ZOOM RÉEL"
		await _save("temoin_zoom_jeu")
		print("SILENT_HEART_SAMPLE_OK")
		get_tree().quit(0)
		return
	for spec: Array in [["escalier", Vector2(2190, 1945)], ["tunnel", Vector2(3610, 1910)],
			["cristal", Vector2(376, 1940)], ["abri", Vector2(3970, 1580)], ["depart", Vector2(4615, 803)]]:
		_camera(spec[1])
		if spec[0] == "escalier":
			_hunter.position = Vector2(2100, 1940)
			_echo.position = Vector2(2280, 1940)
		_caption.text = "%s 20 · %s · CHASSEUR / ÉCHO · ZOOM RÉEL" % [_phase, String(spec[0]).to_upper()]
		await _save(String(spec[0]) + "_zoom_jeu")
	await _silence(Vector2(1180, 2050), "neige")
	await _silence(Vector2(1660, 820), "glace")
	var boss := _actor(GameDB.boss(&"nivorath").visual)
	for spec: Array in [["neige", Vector2(1180, 2050)], ["glace", Vector2(1660, 820)]]:
		_camera(spec[1])
		boss.position = spec[1]
		_hunter.position = spec[1] + Vector2(-210, 90)
		_echo.position = spec[1] + Vector2(210, 90)
		_caption.text = "%s 20 · NIVORATH / %s · FEUILLE EXISTANTE · ZOOM RÉEL" % [_phase, String(spec[0]).to_upper()]
		await _save("nivorath_" + String(spec[0]))
	boss.queue_free()
	_ground.queue_free()
	await get_tree().process_frame
	_ground = Node2D.new()
	_world.add_child(_ground)
	for i: int in 3:
		var suffix := "" if i == 0 else "_%d" % i
		var path := "res://assets/environments/cascade_ruins/map%s.webp" % suffix
		var reference := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert(reference != null)
		_image(reference, Vector2(i * 1672, 0), 1.0 / 2.25)
	_camera(Vector2(2700, 500))
	_caption.text = "RUINES · MÊMES CHASSEUR / ÉCHO ET ZOOM · RÉFÉRENCE D’ÉCHELLE"
	await _save("reference_ruines_zoom_jeu")
	var receipt := {"viewport": [1280, 720], "camera_zoom": GameDB.balance.camera_zoom,
		"composition_sha256": FileAccess.get_sha256(COMPOSITION), "scope": "detail_graphique" if detail else "composition_seule",
		"review_sha256": FileAccess.get_sha256(REVIEW), "profile_read_only": Profile.read_only,
		"native_sprites_unchanged": true, "runtime_integrated": false, "collision_mask_created": false}
	var file := FileAccess.open(_out.path_join("capture_receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	print("SILENT_HEART_PREVIEW_OK")
	get_tree().quit(0)
