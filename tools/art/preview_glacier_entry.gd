extends Node
## Vue documentaire de la composition seule, sans chargement d’un niveau.


func _ready() -> void:
	Profile.read_only = true
	call_deferred("_capture")


func _capture() -> void:
	var out := "/tmp/rift-glacier-entry"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	var path := ProjectSettings.globalize_path("res://assets/concepts/incoming/map.glacier_entry/composition.png")
	var image := Image.load_from_file(path)
	assert(image != null and image.get_size() == Vector2i(1536, 1024))
	image.resize(960, 640, Image.INTERPOLATE_LANCZOS)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.position = Vector2(160, 55)
	add_child(sprite)
	var label := Label.new()
	label.text = "CARTE 16 · ENTRÉE DU GLACIER · COMPOSITION À VALIDER · AUCUN DÉTAIL NI GAMEPLAY"
	label.position = Vector2(20, 15)
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var capture := get_viewport().get_texture().get_image()
	assert(capture.get_size() == Vector2i(1280, 720))
	assert(capture.save_png(out.path_join("apercu_720p.png")) == OK)
	print("GLACIER_ENTRY_COMPOSITION_OK · image entière 1536 × 1024")
	get_tree().quit(0)
