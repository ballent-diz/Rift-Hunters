extends Node2D
## Banc statique : composition à l'échelle du monde, visuels et caméra réels, sans simulation.

const WORLD := Vector2(5016, 3344)
const MAP_ROOT := "res://assets/concepts/incoming/map.glacier_entry/"
var actors: Node2D
var camera: Camera2D


func _ready() -> void:
	Profile.read_only = true
	call_deferred("_capture")


func _arg(key: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(key + "="):
			return arg.trim_prefix(key + "=")
	return fallback


func _actor(visual: VisualData, at: Vector2, frame: int) -> void:
	var entity := EntityVisual.new()
	entity.position = at
	actors.add_child(entity)
	entity.setup(visual)
	assert(entity.has_sheet(), "Sprite final absent : " + String(visual.visual_id))
	for child: Node in entity.get_children():
		if child is AnimatedSprite2D:
			var animation: StringName = &"move" if child.sprite_frames.has_animation(&"move") else &"idle"
			child.play(animation)
			child.pause()
			child.frame = frame % child.sprite_frames.get_frame_count(animation)


func _capture() -> void:
	var out := _arg("--out", "/tmp/rift-glacier-readability")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	var detailed := _arg("--detailed", "false") == "true"
	if detailed:
		for i: int in 3:
			var suffix := "" if i == 0 else "_%d" % i
			var image := Image.load_from_file(ProjectSettings.globalize_path(
				"res://assets/environments/glacier_entry/map%s.webp" % suffix))
			assert(image != null and image.get_size() == Vector2i(3762, 7524))
			_background(image, Vector2.ONE / 2.25, Vector2(i * 1672, 0))
	else:
		var path := _arg("--composition", ProjectSettings.globalize_path(MAP_ROOT + "composition.png"))
		var image := Image.load_from_file(path)
		assert(image != null and image.get_size() == Vector2i(1536, 1024))
		_background(image, WORLD / Vector2(image.get_size()), Vector2.ZERO)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * GameDB.balance.camera_zoom
	add_child(camera)
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := ColorRect.new()
	panel.color = Color("14263bef")
	panel.size = Vector2(1280, 58)
	ui.add_child(panel)
	var label := Label.new()
	label.position = Vector2(16, 8)
	label.add_theme_font_size_override("font_size", 17)
	ui.add_child(label)
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/chapitre4_catalogue.json"))
	var scope := "Tuiles détaillées à 2,25 px/unité" if detailed else "Composition provisoire agrandie"
	var record := {"zoom": GameDB.balance.camera_zoom, "viewport": [1280, 720], "world": [5016, 3344],
		"background": scope,
		"actors": [], "views": []}
	for i: int in 14:
		var id: String = catalog[i]["visual_id"]
		var visual: VisualData
		for enemy: EnemyData in GameDB.enemies.values():
			if String(enemy.visual.visual_id) == id:
				visual = enemy.visual
				break
		assert(visual != null, "Donnée ennemi absente : " + id)
		var at := Vector2((i % 7 - 3) * 98, -95 if i < 7 else 95)
		_actor(visual, at, i % 6)
		record["actors"].append({"id": id, "offset_world": [at.x, at.y], "frame": i % 6,
			"scale": Assets.pixel_scale(visual.visual_id)})
	_actor(GameDB.balance.player_visual, Vector2(0, 215), 0)
	for view: Dictionary in [{"name": "neige", "center_pct": Vector2(51, 31)},
			{"name": "glace", "center_pct": Vector2(50, 48)}]:
		var center: Vector2 = view["center_pct"] * WORLD / 100.0
		camera.position = center
		actors.position = center
		camera.reset_smoothing()
		camera.force_update_scroll()
		label.text = "CARTE 16 · %s · caméra réelle ×%.4f · 14 sprites PR #92 à leur taille du manifeste\n" % [
			String(view["name"]).to_upper(), GameDB.balance.camera_zoom]
		label.text += "Banc statique + Chasseur · " + scope + " · aucune simulation de navigation"
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var file := String(view["name"]) + ".png"
		assert(get_viewport().get_texture().get_image().save_png(out.path_join(file)) == OK)
		record["views"].append({"file": file, "center_pct": [view["center_pct"].x, view["center_pct"].y]})
	var report := FileAccess.open(out.path_join("capture.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(record, "\t") + "\n")
	print("GLACIER_READABILITY_OK · 14 sprites + Chasseur · neige et glace · zoom ", GameDB.balance.camera_zoom)
	get_tree().quit(0)


func _background(image: Image, size_scale: Vector2, at: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.scale = size_scale
	sprite.position = at
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
