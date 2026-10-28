extends SceneTree
## Aperçu isolé : capture de six scènes, sans chargement de la campagne ou du combat.
const CATALOG := "res://assets/vfx/enemies/chapter3/catalog.json"
var effects: Array[Node2D] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = "res://captures"
	var group: int = 0
	for arg: String in args:
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		if arg.begins_with("--group="):
			group = int(arg.trim_prefix("--group="))
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var canvas := Node2D.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("17242b")
	background.size = Vector2(1280, 720)
	canvas.add_child(background)
	var title := Label.new()
	title.text = "RIFT HUNTERS — EFFETS NATIFS GODOT 4.3"
	title.position = Vector2(30, 14)
	title.add_theme_font_size_override("font_size", 24)
	canvas.add_child(title)
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var selected: Array = entries.slice(group * 6, mini(group * 6 + 6, entries.size()))
	for i: int in selected.size():
		var entry: Dictionary = selected[i]
		var effect: Node2D = (load(entry["scene"]) as PackedScene).instantiate()
		effect.destroy_on_finish = false
		canvas.add_child(effect)
		effect.position = Vector2(210 + (i % 3) * 420, 215 + (i / 3) * 300)
		var fit: float = minf(1.0, 135.0 / maxf(float(entry["radius"]), 1.0))
		if entry["effect_kind"] in ["beam", "leash", "roots", "shards"]:
			fit = minf(fit, 260.0 / maxf(float(entry["length"]), 1.0))
			if entry["effect_kind"] in ["beam", "leash"]:
				effect.set_path_local(PackedVector2Array([Vector2(-130, 30), Vector2(0, 30), Vector2(80, -70)]))
		effect.scale = Vector2.ONE * fit
		effect.set_visual_state(0.9, 0.85)
		if entry["effect_kind"] == "clones":
			effect.set_secondary_offsets(PackedVector2Array([Vector2(-70, 0), Vector2(70, 0)]))
		effects.append(effect)
		var label := Label.new()
		label.text = str(entry["owner"]) + " / " + str(entry["animation"])
		label.position = Vector2(25 + (i % 3) * 420, 328 + (i / 3) * 300)
		label.add_theme_font_size_override("font_size", 15)
		canvas.add_child(label)
	for frame: int in 16:
		for effect: Node2D in effects:
			effect.seek_visual((0.05 + frame / 18.0) * effect.duration())
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		if image.is_empty():
			push_error("Rendu indisponible : utiliser un affichage OpenGL/Xvfb")
			quit(1)
			return
		image.save_png(out.path_join("group_%02d_frame_%02d.png" % [group, frame]))
	print("CAPTURES GODOT : groupe %d, 16 images" % group)
	quit()
