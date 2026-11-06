extends Node
## Composition23 : sprites natifs et zoom du jeu ; aucune partie ni écriture de profil.

const COMPOSITION := "res://assets/concepts/incoming/map.suspended_quarters/composition.png"
const REVIEW := "res://assets/concepts/incoming/map.suspended_quarters/source/composition_review.json"
const WITNESSES: Array[StringName] = [
	&"wandering_shard", &"glass_sentinel", &"quartz_golem",
	&"hush_shard", &"ice_knight", &"silence_herald",
]

var _world: Node2D
var _actors: Node2D
var _hunter: EntityVisual
var _echo: EntityVisual
var _caption: Label
var _out := "/tmp/rift-suspended-quarters"


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
	var target := Vector2(clampf(center.x, 480, 4536), clampf(center.y, 270, 2238))
	_world.position = Vector2(640, 360) - target * zoom
	_hunter.position = center + Vector2(-90, 70)
	_echo.position = center + Vector2(90, 80)


func _save(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1280, 720))
	assert(image.save_png(_out.path_join(name + ".png")) == OK)


func _witnesses(center: Vector2, surface: String) -> void:
	_camera(center)
	_hunter.position = center + Vector2(-65, 20)
	_echo.position = center + Vector2(85, 20)
	if surface == "vide":
		_hunter.position = center + Vector2(-170, 20)
		_echo.position = center + Vector2(-30, 20)
	var actors: Array[EntityVisual] = []
	for i: int in WITNESSES.size():
		var enemy := GameDB.enemy(WITNESSES[i])
		assert(enemy != null)
		var actor := _actor(enemy.visual, i % 6)
		var column := (i % 3 - 1) * 105
		if surface == "vide":
			column -= 115
		actor.position = center + Vector2(column, -80 if i < 3 else 105)
		actors.append(actor)
	_caption.text = "COMPOSITION 23 · REFLETS CH3 / ÉCHOS CH4 · %s · FINESSE PROVISOIRE" % surface.to_upper()
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
	var image := Image.load_from_file(ProjectSettings.globalize_path(COMPOSITION))
	assert(image != null and image.get_size() == Vector2i(1536, 768))
	var ground := Sprite2D.new()
	ground.texture = ImageTexture.create_from_image(image)
	ground.centered = false
	ground.scale = Vector2.ONE * (5016.0 / 1536.0)
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_world.add_child(ground)
	_caption = Label.new()
	_caption.position = Vector2(15, 12)
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_color_override("font_outline_color", Color("21172b"))
	_caption.add_theme_constant_override("outline_size", 7)
	add_child(_caption)
	_world.scale = Vector2.ONE * (1180.0 / 5016.0)
	_world.position = Vector2(50, 65)
	_caption.text = "CARTE 23 · QUARTIERS SUSPENDUS · COMPOSITION ENTIÈRE À VALIDER"
	await _save("ensemble_720p")
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	_actors.z_index = 2
	_world.add_child(_actors)
	_hunter = _actor(GameDB.balance.player_visual)
	_echo = _actor(GameDB.enemy(&"snow_wraith").visual)
	var proposal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REVIEW))
	var scenes: Array = []
	for i: int in 3:
		scenes.append(["pont_" + str(i + 1), proposal.bridges[i].center_pct])
	for teleport: Dictionary in proposal.teleporters:
		if teleport.id == "a1" or teleport.id == "c2":
			scenes.append(["socle_" + String(teleport.id), teleport.center_pct])
	for spec: Array in scenes:
		var center := Vector2(spec[1][0] * 50.16, spec[1][1] * 25.08)
		_camera(center)
		if String(spec[0]).begins_with("pont"):
			_hunter.position = center + Vector2(-42, -25)
			_echo.position = center + Vector2(45, 25)
		elif spec[0] == "socle_c2":
			_hunter.position = center + Vector2(-110, -35)
			_echo.position = center + Vector2(110, -30)
		else:
			_hunter.position = center + Vector2(-115, 25)
			_echo.position = center + Vector2(115, 25)
		_caption.text = "COMPOSITION 23 · %s · CHASSEUR / ÉCHO · ZOOM RÉEL · DÉTAIL À VENIR" % String(spec[0]).to_upper()
		await _save(String(spec[0]) + "_zoom_jeu")
	await _witnesses(Vector2(1750, 1560), "dalles")
	await _witnesses(Vector2(1660, 1880), "corruption")
	await _witnesses(Vector2(3380, 1420), "vide")
	var receipt := {"viewport": [1280, 720], "camera_zoom": GameDB.balance.camera_zoom,
		"composition_sha256": FileAccess.get_sha256(COMPOSITION), "scope": "composition_a_valider",
		"review_sha256": FileAccess.get_sha256(REVIEW), "profile_read_only": Profile.read_only,
		"native_sprites_unchanged": true, "witness_ids": WITNESSES, "detail_generated": false,
		"runtime_integrated": false, "collision_mask_created": false}
	var file := FileAccess.open(_out.path_join("capture_receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	print("SUSPENDED_QUARTERS_COMPOSITION_OK")
	get_tree().quit(0)
