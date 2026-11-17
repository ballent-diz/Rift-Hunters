extends Control
## Contrôle visuel de la feuille publiée ; ne branche aucune orientation en jeu.

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("101522"))
	var heading := Label.new()
	heading.text = "Veilleur des Seuils — feuille finale / profil conservé, dos et face ajoutés"
	heading.position = Vector2(30, 12)
	add_child(heading)
	var sheet := TextureRect.new()
	sheet.texture = load("res://assets/sprites/players/threshold_warden/threshold_warden_sheet.png")
	sheet.position = Vector2(180, 60)
	sheet.size = Vector2(784, 720)
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
