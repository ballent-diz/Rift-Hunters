extends Node
## Détail23 : tuiles finales et sprites natifs au zoom du jeu, profil en lecture seule.

const COMPOSITION := "res://assets/concepts/incoming/map.suspended_quarters/composition.png"
const REVIEW := "res://assets/concepts/incoming/map.suspended_quarters/plan.json"
const TILES: Array[String] = [
	"res://assets/environments/suspended_quarters/map.webp",
	"res://assets/environments/suspended_quarters/map_1.webp",
	"res://assets/environments/suspended_quarters/map_2.webp",
]
const WITNESSES: Array[StringName] = [
	&"wandering_shard", &"glass_sentinel", &"quartz_golem",
	&"hush_shard", &"ice_knight", &"silence_herald",
]

var _sample_background := ""
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


func _ground(image: Image, offset: Vector2, factor: float) -> void:
	var ground := Sprite2D.new()
	ground.texture = ImageTexture.create_from_image(image)
	ground.centered = false
	ground.position = offset
	ground.scale = Vector2.ONE * factor
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_world.add_child(ground)


func _tile_hashes() -> Array[String]:
	var hashes: Array[String] = []
	for path: String in TILES:
		hashes.append(FileAccess.get_sha256(path))
	return hashes


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
	_caption.text = "DÉTAIL 23 · REFLETS CH3 / ÉCHOS CH4 · %s · ZOOM RÉEL" % surface.to_upper()
	await _save("lisibilite_" + surface)
	for actor: EntityVisual in actors:
		actor.queue_free()
	await get_tree().process_frame


func _capture() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--sample-background="):
			_sample_background = arg.trim_prefix("--sample-background=")
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	_world = Node2D.new()
	add_child(_world)
	if not _sample_background.is_empty():
		var image := Image.load_from_file(_sample_background)
		assert(image != null)
		_ground(image, Vector2.ZERO, 5016.0 / image.get_width())
	else:
		for i: int in TILES.size():
			var image := Image.load_from_file(ProjectSettings.globalize_path(TILES[i]))
			assert(image != null and image.get_size() == Vector2i(3762, 5643))
			_ground(image, Vector2(i * 1672, 0), 1.0 / 2.25)
	_caption = Label.new()
	_caption.position = Vector2(15, 12)
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_color_override("font_outline_color", Color("21172b"))
	_caption.add_theme_constant_override("outline_size", 7)
	add_child(_caption)
	_world.scale = Vector2.ONE * (1180.0 / 5016.0)
	_world.position = Vector2(50, 65)
	_caption.text = "CARTE 23 · QUARTIERS SUSPENDUS · DÉTAIL ENTIER · PLAN VALIDÉ"
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
		if teleport.id in ["a1", "a2", "c2"]:
			scenes.append(["socle_" + String(teleport.id), teleport.center_pct])
	for passage: Dictionary in proposal.get("interior_passages", []):
		scenes.append(["faille_interieure", passage.center_pct])
	scenes.append(["cour_interieure", [31.8979, 55.0239]])
	scenes.append(["finale", proposal.finale.free_core_center_pct])
	scenes.append(["depart", proposal.start_pct])
	for spec: Array in scenes:
		if not _sample_background.is_empty() and spec[0] not in ["socle_a2", "faille_interieure"]:
			continue
		var center := Vector2(spec[1][0] * 50.16, spec[1][1] * 25.08)
		_camera(center)
		if String(spec[0]).begins_with("pont") or spec[0] == "faille_interieure":
			_hunter.position = center + Vector2(-42, -25)
			_echo.position = center + Vector2(45, 25)
		elif spec[0] == "socle_c2":
			_hunter.position = center + Vector2(-110, -35)
			_echo.position = center + Vector2(110, -30)
		else:
			_hunter.position = center + Vector2(-115, 25)
			_echo.position = center + Vector2(115, 25)
		_caption.text = "DÉTAIL 23 · %s · CHASSEUR / ÉCHO · ZOOM RÉEL" % String(spec[0]).to_upper()
		await _save(String(spec[0]) + "_zoom_jeu")
	if not _sample_background.is_empty():
		print("SUSPENDED_QUARTERS_SAMPLE_OK")
		get_tree().quit(0)
		return
	await _witnesses(Vector2(1698, 1789), "dalles")
	await _witnesses(Vector2(1585, 1515), "corruption")
	await _witnesses(Vector2(3380, 1420), "vide")
	var receipt := {"viewport": [1280, 720], "camera_zoom": GameDB.balance.camera_zoom,
		"composition_sha256": FileAccess.get_sha256(COMPOSITION), "scope": "detail_graphique_livre",
		"plan_sha256": FileAccess.get_sha256(REVIEW), "tiles_sha256": _tile_hashes(), "profile_read_only": Profile.read_only,
		"native_sprites_unchanged": true, "witness_ids": WITNESSES, "detail_generated": true,
		"runtime_integrated": false, "collision_mask_created": false}
	var file := FileAccess.open(_out.path_join("capture_receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	print("SUSPENDED_QUARTERS_DETAIL_OK")
	get_tree().quit(0)
