extends Node
## Captures du menu principal v2 et de l'écran de déblocage avec un double de `DraftUnlocks`
## (tools/draft3d_fake_unlocks.gd), tant que la classe de la session « Gameplay » n'est pas dans le dépôt.
## Usage : godot --path . --resolution 1280x720 res://tools/unlock_preview.tscn -- --out=<fichier.png>
##   [--screen=menu|unlocks|end] [--locale=fr|en]

var _options: Dictionary = {}


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=")
		_options[parts[0]] = parts[1] if parts.size() > 1 else "1"
	if _options.has("locale"):
		TranslationServer.set_locale(String(_options["locale"]))
	var fake: Object = (load("res://tools/draft3d_fake_unlocks.gd") as GDScript).new()
	var screen: String = String(_options.get("screen", "unlocks"))
	if screen == "end":
		var hud := DraftHud.new()
		add_child(hud)
		hud.show_end(true, tr("DRAFT_SUMMARY") % ["8:00", 23, 1412], int(fake.call(&"last_gain")))
	else:
		var menu: DraftMenu = (load(DraftMenu.SCENE) as PackedScene).instantiate()
		menu.unlocks = fake
		add_child(menu)
		if screen == "unlocks":
			menu.open_unlocks()
	for frame: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(String(_options.get("out", "user://unlocks.png")))
	get_tree().quit()
