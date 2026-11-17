extends Control
## Contrôle visuel de la feuille publiée ; ne branche aucune orientation en jeu.

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("101522"))
	var heading := Label.new()
	heading.text = "Chasseur original — feuille finale / profil conservé, dos et face ajoutés"
	heading.position = Vector2(30, 12)
	add_child(heading)
	var sheet := TextureRect.new()
	var image := Image.load_from_file("res://assets/sprites/players/hunter/hunter_sheet.png")
	sheet.texture = ImageTexture.create_from_image(image)
	sheet.position = Vector2(180, 60)
	sheet.size = Vector2(672, 720)
	add_child(sheet)
	var names := ["idle", "move", "attack", "hurt", "death", "idle_back", "move_back",
		"idle_front", "move_front"]
	for row in names.size():
		var label := Label.new()
		label.text = names[row]
		label.position = Vector2(30, 90 + row * 80)
		add_child(label)
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			var result := get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--out="))
			if result != OK:
				get_tree().quit(1)
				return
	get_tree().quit()
