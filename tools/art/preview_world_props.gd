extends Node
## Banc graphique hors partie : ancrage et proportions des objets, sans collisions ni placement en niveau.

var _out := ""
var _kind := "cover"


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--kind="):
			_kind = arg.trim_prefix("--kind=")
	Profile.read_only = true
	call_deferred("_run")


func _label(text: String, at: Vector2, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	add_child(label)


func _background(color: Color, box: Rect2) -> void:
	var panel := ColorRect.new()
	panel.position = box.position
	panel.size = box.size
	panel.color = color
	add_child(panel)


func _prop(id: StringName, animation: StringName, foot: Vector2, frame: int = 0) -> Sprite2D:
	var entry: Dictionary = Assets.entry(id)
	assert(entry["status"] == "final")
	var anim: Dictionary = entry["animations"][animation]
	assert(frame < int(anim["frames"]))
	var sprite := Sprite2D.new()
	sprite.texture = load(entry["sheet"])
	assert(sprite.texture != null)
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(frame * entry["cell"][0], anim["row"] * entry["cell"][1],
		entry["cell"][0], entry["cell"][1])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * float(entry["scale"]) * GameDB.balance.camera_zoom
	sprite.position = foot - Vector2(entry["anchor"][0], entry["anchor"][1]) * sprite.scale
	add_child(sprite)
	return sprite


func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(_out)
	_background(Color("395558"), Rect2(0, 0, 1280, 380))
	_background(Color("b4cad6"), Rect2(0, 380, 1280, 340))
	_label("OBJETS · CONTRÔLE GRAPHIQUE · ZOOM DU JEU · AUCUNE COLLISION", Vector2(20, 10))
	var hunter := EntityVisual.new()
	hunter.setup(GameDB.balance.player_visual)
	hunter.scale = Vector2.ONE * GameDB.balance.camera_zoom
	hunter.position = Vector2(60, 667)
	add_child(hunter)
	if hunter._anim:
		hunter._anim.pause()
		hunter._anim.frame = 0
	_label("Chasseur témoin", Vector2(95, 660), Color("14222c"))
	if _kind == "cover":
		for row: int in 2:
			var id: StringName = &"object.cover_rock" if row == 0 else &"object.cover_rock_ice"
			for index: int in 3:
				var foot := Vector2(240 + index * 400, 305 + row * 295)
				_prop(id, StringName("variant_" + str(index + 1)), foot)
				var color := Color.WHITE if row == 0 else Color("14222c")
				_label(str(id) + " · " + str(index + 1), foot + Vector2(-135, 32), color)
		await _save("planche_720p.png")
	else:
		var actor := _prop(&"object.training_dummy", &"idle", Vector2(640, 305))
		var twin := _prop(&"object.training_dummy", &"idle", Vector2(640, 600))
		var phase := Label.new()
		phase.position = Vector2(780, 245)
		phase.add_theme_font_size_override("font_size", 22)
		add_child(phase)
		var entry: Dictionary = Assets.entry(&"object.training_dummy")
		for step: int in 18:
			var name: StringName = &"hit" if step >= 6 and step < 12 else &"idle"
			var anim: Dictionary = entry["animations"][name]
			actor.region_rect = Rect2((step % 6) * 256, anim["row"] * 256, 256, 256)
			twin.region_rect = actor.region_rect
			phase.text = "%s · pose %d/6" % [name, step % 6 + 1]
			await _save("frame_%02d.png" % step)
	print("WORLD_PROPS_PREVIEW_OK · ", _kind, " · zoom ", GameDB.balance.camera_zoom)
	get_tree().quit(0)


func _save(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1280, 720))
	assert(image.save_png(_out.path_join(name)) == OK)
