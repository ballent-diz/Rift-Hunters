extends Node
## Outil de capture uniquement ; ne construit aucun écran fonctionnel du refuge.

func _ready() -> void:
	var output := "res://docs/previews/c5"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920,1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var canvas = load("res://tools/art/c5_preview_canvas.gd").new()
	viewport.add_child(canvas)
	var display := TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(display)
	for mode: String in ["overview", "focus", "states", "effects"]:
		canvas.mode = mode
		canvas.effect_time = .35
		canvas.gallery_static = true
		canvas.queue_redraw()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(output+"/"+mode+".png")
		print("C5 capture : ",mode)
	for frame: int in 48:
		canvas.gallery_static = false
		canvas.effect_time = float(frame)/24.0
		canvas.queue_redraw()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(output+"/effects_%02d.png" % frame)
	get_tree().quit()
