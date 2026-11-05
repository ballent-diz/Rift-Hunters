extends Node
## Revue graphique aux échelles et feuilles du jeu. Aucune partie lancée.

const COMPOSITION := "res://assets/concepts/incoming/map.lighthouse_floe/composition.png"
const REVIEW := "res://assets/concepts/incoming/map.lighthouse_floe/plan.json"

var _world: Node2D
var _ground: Node2D
var _actors: Node2D
var _hunter: EntityVisual
var _echo: EntityVisual
var _caption: Label
var _out := "/tmp/rift-lighthouse-floe"
var _phase := "COMPOSITION"


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
	_hunter.position = center + Vector2(-30, 70)
	_echo.position = center + Vector2(50, 85)


func _save(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1280, 720))
	assert(image.save_png(_out.path_join(name)) == OK)


func _silence(center: Vector2, name: String) -> void:
	_camera(center)
	_hunter.position = center + Vector2(0, 180)
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
		actor.position = center + Vector2((i * 140 - 210) if i < 4 else ((i - 4) * 140 - 140),
			-65 if i < 4 else 100)
		monsters.append(actor)
	_caption.text = "%s 19 · SEPT ÉCHOS DU SILENCE / %s · ZOOM RÉEL" % [_phase, name.to_upper()]
	await _save("silence_" + name + ".png")
	for actor: EntityVisual in monsters:
		actor.queue_free()
	_echo.visible = true
	await get_tree().process_frame


func _capture() -> void:
	var sample := ""
	var detail := false
	var broken := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--sample="):
			sample = arg.trim_prefix("--sample=")
		elif arg == "--detail":
			detail = true
		elif arg == "--broken":
			broken = true
			detail = true
	_phase = "DÉTAIL" if detail or not sample.is_empty() else "COMPOSITION"
	if broken:
		_phase = "DÉTAIL BRISÉ"
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	_world = Node2D.new()
	add_child(_world)
	_ground = Node2D.new()
	_world.add_child(_ground)
	if not sample.is_empty():
		var image := Image.load_from_file(sample)
		assert(image != null)
		_image(image, Vector2(1094, 1094), 1574.0 / image.get_width())
	elif detail:
		for i: int in 3:
			var suffix := "" if i == 0 else "_%d" % i
			var path := "res://assets/environments/lighthouse_floe/map%s.webp" % suffix
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			assert(image != null and image.get_size() == Vector2i(3762, 11286))
			_image(image, Vector2(i * 1672, 0), 1.0 / 2.25)
		if broken:
			var recipe_path := "res://assets/concepts/incoming/map.lighthouse_floe/source/paired_recipe.json"
			var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(recipe_path))
			for overlay: Dictionary in recipe["overlays"]:
				var image := Image.load_from_file(ProjectSettings.globalize_path("res://" + overlay["file"]))
				assert(image != null)
				var rect: Array = overlay["pixel_rect_on_full_image"]
				_image(image, Vector2(rect[0], rect[1]) / 2.25, 1.0 / 2.25)
	else:
		var image := Image.load_from_file(ProjectSettings.globalize_path(COMPOSITION))
		assert(image != null and image.get_size() == Vector2i(1254, 1254))
		_image(image, Vector2.ZERO, 4.0)
	_caption = Label.new()
	_caption.position = Vector2(15, 12)
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_color_override("font_outline_color", Color("15273c"))
	_caption.add_theme_constant_override("outline_size", 7)
	add_child(_caption)
	_world.scale = Vector2.ONE * (640.0 / 5016.0)
	_world.position = Vector2(320, 50)
	_caption.text = "CARTE 19 · LA BANQUISE DU PHARE · %s ENTIER" % _phase
	if sample.is_empty():
		await _save("ensemble_720p.png")
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	_actors.z_index = 2
	_world.add_child(_actors)
	_hunter = _actor(GameDB.balance.player_visual)
	_echo = _actor(GameDB.enemy(&"snow_wraith").visual)
	if broken:
		_camera(Vector2(4500, 2420))
		_hunter.position = Vector2(4300, 2400)
		_echo.position = Vector2(4200, 2380)
		_caption.text = "DÉTAIL BRISÉ 19 · SORTIE EST / P05 · CHASSEUR ET ÉCHO SUR LE PONT · ZOOM RÉEL"
		await _save("epave_brisee_zoom_jeu.png")
		print("LIGHTHOUSE_FLOE_BROKEN_PREVIEW_OK")
		get_tree().quit(0)
		return
	if not sample.is_empty():
		_camera(Vector2(2050, 2170))
		_caption.text = "CARTE 19 · RÉGION TÉMOIN · CHASSEUR / ÉCHO · ZOOM RÉEL · ABRI CIBLE 140 U"
		await _save("temoin_zoom_jeu.png")
		print("LIGHTHOUSE_FLOE_SAMPLE_OK")
		get_tree().quit(0)
		return
	for spec: Array in [["phare", Vector2(2508, 2440)], ["epave", Vector2(3550, 2390)],
			["pierre", Vector2(2495, 3440)], ["ouest", Vector2(1370, 2400)]]:
		_camera(spec[1])
		if spec[0] == "phare":
			_hunter.position = Vector2(2432, 2610)
			_echo.position = Vector2(2660, 2605)
		elif spec[0] == "ouest":
			_hunter.position = Vector2(1330, 2400)
			_echo.position = Vector2(1460, 2400)
		elif spec[0] == "epave":
			_hunter.position = Vector2(3500, 2390)
			_echo.position = Vector2(3610, 2390)
		_caption.text = "%s 19 · %s · CHASSEUR / ÉCHO · ZOOM RÉEL" % [_phase, String(spec[0]).to_upper()]
		await _save(String(spec[0]) + "_zoom_jeu.png")
	await _silence(Vector2(900, 4050), "neige")
	await _silence(Vector2(2440, 1040), "banquise")
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
	_caption.text = "RUINES DES CASCADES · MÊME CHASSEUR / ÉCHO ET ZOOM · RÉFÉRENCE D’ÉCHELLE"
	await _save("reference_ruines_zoom_jeu.png")
	var receipt := {"viewport": [1280, 720], "camera_zoom": GameDB.balance.camera_zoom,
		"composition_sha256": FileAccess.get_sha256(COMPOSITION), "scope": "detail_graphique" if detail else "composition",
		"review_sha256": FileAccess.get_sha256(REVIEW), "profile_read_only": Profile.read_only,
		"native_sprites_unchanged": true, "runtime_integrated": false, "collision_mask_created": false}
	var receipt_file := FileAccess.open(_out.path_join("capture_receipt.json"), FileAccess.WRITE)
	receipt_file.store_string(JSON.stringify(receipt, "\t") + "\n")
	print("LIGHTHOUSE_FLOE_PREVIEW_OK · aucune intégration ni collision")
	get_tree().quit(0)
