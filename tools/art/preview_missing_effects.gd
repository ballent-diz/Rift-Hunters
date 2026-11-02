extends SceneTree
## Banc déterministe des ressources réellement livrées, sans combat simulé.
var effects: Array[Node2D] = []
var entries: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _arg(key: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(key + "="):
			return arg.trim_prefix(key + "=")
	return fallback


func _label(text: String, at: Vector2, size: int = 18) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e0edf3"))
	root.add_child(label)


func _run() -> void:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(_arg("--catalog", "")))
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/asset_manifest.json"))["entries"]
	var page := int(_arg("--page", "0"))
	var steps := int(_arg("--steps", "18"))
	var out := _arg("--out", "/tmp/rift-effects")
	DirAccess.make_dir_recursive_absolute(out)
	var background := ColorRect.new()
	background.color = Color("172331")
	background.size = Vector2(1280, 720)
	root.add_child(background)
	_label("Effets peints · ressources natives Godot · présentation sans dégâts ni collisions", Vector2(24, 16), 23)
	_label("Chasseur : repère d’échelle seulement · aucun combat simulé", Vector2(24, 686), 16)
	for index: int in range(page * 6, mini(page * 6 + 6, catalog.size())):
		var item: Dictionary = catalog[index]
		var local_index := index - page * 6
		var effect: Node2D = load(item["scene"]).instantiate()
		effect.destroy_on_finish = false
		effect.position = Vector2(190 + (local_index % 3) * 420, 235 + (local_index / 3) * 300)
		effect.scale = Vector2.ONE * 0.9
		root.add_child(effect)
		if item["effect_kind"] in ["ice_prison", "slag_shell", "bark_shield", "duel_circle",
			"hush_circle", "cold_aura", "frost_mist", "dive_ripple", "star_crown", "absorb",
			"pyre_slam", "blazing_rage", "soot_web", "slag_molt", "summon", "brood", "lay_eggs",
			"crater_sequence", "skyfall", "leap", "dive", "plunge"]:
			var entry: Dictionary = manifest["player.hunter"]
			var actor := Sprite2D.new()
			actor.texture = load(entry["sheet"])
			actor.centered = false
			actor.region_enabled = true
			actor.region_rect = Rect2(0, 0, entry["cell"][0], entry["cell"][1])
			actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			actor.scale = Vector2.ONE * float(entry["scale"]) * 0.9
			actor.position = effect.position - Vector2(entry["anchor"][0], entry["anchor"][1]) * actor.scale
			actor.z_index = 3
			root.add_child(actor)
		if item["effect_kind"] == "tide_water":
			var road := ColorRect.new()
			road.color = Color("70766b")
			road.position = effect.position + Vector2(-110, -60)
			road.size = Vector2(220, 95)
			root.add_child(road)
			for seam: int in 5:
				var line := ColorRect.new()
				line.color = Color("414e4c")
				line.position = Vector2(seam * 45, 0)
				line.size = Vector2(2, 95)
				road.add_child(line)
		if item["effect_kind"] in ["silk_thread", "ice_crack", "charge"]:
			effect.position.x -= 100
			effect.set_path_local(PackedVector2Array([Vector2.ZERO, Vector2(100, 10), Vector2(200, 0)]))
		effects.append(effect)
		entries.append(item)
		_label(item["name"], Vector2(26 + (local_index % 3) * 420, 78 + (local_index / 3) * 300), 17)
		_label("%s · %.2f s%s" % [item["animation"], item["duration"], " · boucle" if item["loop"] else ""],
			Vector2(26 + (local_index % 3) * 420, 104 + (local_index / 3) * 300), 14)
	for frame: int in steps:
		var phase: float = (frame + 0.5) / float(steps)
		for index: int in effects.size():
			var effect: Node2D = effects[index]
			effect.seek_visual(phase * effect.duration())
			var kind: String = entries[index]["effect_kind"]
			if kind in ["slag_shell", "ice_prison", "silk_thread"]:
				effect.set_visual_state(1.0 if phase < 0.6 else 0.15, 0.0 if phase < 0.6 else 1.0)
			elif kind in ["snowball", "tide_water"]:
				effect.set_visual_state(1.0, sin(phase * PI))
		await process_frame
		await RenderingServer.frame_post_draw
		var code := root.get_texture().get_image().save_png(out.path_join("%03d.png" % frame))
		if code != OK:
			quit(1)
			return
	for effect: Node2D in effects:
		effect.free()
	print("EFFETS : ", entries.size(), " scènes capturées, ", steps, " images 1280 × 720")
	quit(0)
