extends SceneTree
## Banc visuel autonome : fond réel et repères à l'échelle, aucune simulation de combat.
const CATALOG := "res://assets/vfx/enemies/chapter3/catalog.json"
const ZOOM := 4.0 / 3.0
var effects: Array[Node2D] = []
var world: Node2D
var sprites: Dictionary


func _initialize() -> void:
	call_deferred("_run")


func _value(args: PackedStringArray, key: String, fallback: String) -> String:
	for arg: String in args:
		if arg.begins_with(key + "="):
			return arg.trim_prefix(key + "=")
	return fallback


func _label(text: String, at: Vector2, size: int = 16) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(label)


func _sprite(id: String, foot: Vector2, opacity: float = 1.0) -> void:
	var entry: Dictionary = sprites[id]
	var sprite := Sprite2D.new()
	sprite.texture = load(entry["sheet"])
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, float(entry["cell"][0]), float(entry["cell"][1]))
	var art_scale: float = float(entry["scale"])
	sprite.scale = Vector2.ONE * art_scale
	sprite.position = (
		foot - Vector2(float(entry["anchor"][0]), float(entry["anchor"][1])) * art_scale
	)
	sprite.modulate.a = opacity
	sprite.z_index = 3
	world.add_child(sprite)


func _make_effect(entry: Dictionary, at: Vector2) -> Node2D:
	var packed := load(entry["scene"]) as PackedScene
	var effect: Node2D = packed.instantiate()
	effect.destroy_on_finish = false
	effect.position = at
	world.add_child(effect)
	effect.set_visual_state(0.9, 0.85)
	effect.set_facet_strengths(PackedFloat32Array([1.0, 0.75, 0.0, 0.4]))
	if entry["effect_kind"] in ["beam", "leash"]:
		# Trajet LOCAL déjà tronqué/réfléchi, fourni tel quel à la scène.
		effect.set_path_local(
			PackedVector2Array([Vector2(-120, 35), Vector2(10, 35), Vector2(95, -85)])
		)
	if entry["effect_kind"] in ["clones", "shield", "blink", "heal"]:
		effect.set_secondary_offsets(PackedVector2Array([Vector2(-65, 5), Vector2(70, -15)]))
	return effect


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = _value(args, "--out", "res://captures")
	var group: int = int(_value(args, "--group", "0"))
	var frame_count: int = clampi(int(_value(args, "--frames", "16")), 1, 120)
	var single: int = int(_value(args, "--single", "-1"))
	var tag: String = _value(args, "--tag", "AVANT")
	var mode: String = _value(args, "--mode", "capture")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	sprites = JSON.parse_string(FileAccess.get_file_as_string("res://context_sprites.json"))
	world = Node2D.new()
	world.scale = Vector2.ONE * ZOOM
	root.add_child(world)
	var ground := Sprite2D.new()
	ground.texture = load("res://context_ground.webp")
	ground.centered = false
	ground.z_index = -100
	world.add_child(ground)
	_label(
		"RIFT HUNTERS — " + tag + " — APERÇU TECHNIQUE GODOT, PAS UNE PARTIE", Vector2(20, 14), 20
	)
	_label(
		"1280 × 720 · zoom 4/3 · phases normalisées · dimensions du catalogue · audio désactivé",
		Vector2(20, 46),
		15
	)
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if mode == "load":
		await _load_preview(entries, out)
		quit()
		return
	var selected: Array = entries.slice(group * 3, mini(group * 3 + 3, entries.size()))
	if single >= 0 and single < entries.size():
		selected = [entries[single]]
	if selected.is_empty():
		push_error("Aucun effet dans ce groupe")
		quit(1)
		return
	for i: int in selected.size():
		var x: float = (
			640.0 if selected.size() == 1 else lerpf(200.0, 1080.0, i / float(selected.size() - 1))
		)
		var at := Vector2(x, 405.0) / ZOOM
		var entry: Dictionary = selected[i]
		effects.append(_make_effect(entry, at))
		_sprite("player.hunter", at + Vector2(-45, 55))
		_sprite("monster.mossback", at + Vector2(55, 65))
		_label(str(entry["owner"]) + " / " + str(entry["animation"]), Vector2(x - 175, 625), 15)
	_label(
		"Les repères Chasseur et Mousseroc utilisent cellule, ancre et échelle du manifeste.",
		Vector2(20, 683),
		15
	)
	await process_frame
	for frame: int in frame_count:
		var phase: float = 0.42 if frame_count == 1 else 0.05 + frame / 18.0
		for effect: Node2D in effects:
			effect.seek_visual(phase * effect.duration())
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		if image.is_empty():
			push_error("Rendu indisponible : ne pas utiliser --headless pour les captures")
			quit(1)
			return
		image.save_png(out.path_join("g%02d_f%02d.png" % [group, frame]))
	var report := {
		"kind": "aperçu technique natif Godot, pas une partie",
		"resolution": [1280, 720],
		"zoom": ZOOM,
		"group": group,
		"single": single,
		"frames": frame_count,
		"phase_formula": "0.05 + frame / 18.0 ; capture unique à 0.42",
		"entries": selected
	}
	FileAccess.open(out.path_join("capture.json"), FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	print("CONTEXTE GODOT : %d effets, %d images" % [effects.size(), frame_count])
	quit()


func _load_preview(entries: Array, out: String) -> void:
	# Charge visuelle uniquement : 90 sprites témoins, aucun comportement d'ennemi simulé.
	for i: int in 90:
		_sprite("monster.mossback", Vector2(30 + (i % 15) * 63, 90 + (i / 15) * 73), 0.85)
	var normal_choices: Array[int] = []
	var boss_choices: Array[int] = []
	for i: int in entries.size():
		if entries[i]["effect_kind"] != "indicator":
			if str(entries[i]["scene"]).contains("/bosses/"):
				boss_choices.append(i)
			else:
				normal_choices.append(i)
	for i: int in 24:
		var index: int = (
			normal_choices[i % normal_choices.size()]
			if i < 16
			else boss_choices[(i - 16) % boss_choices.size()]
		)
		var effect := _make_effect(entries[index], Vector2(85 + (i % 6) * 155, 130 + (i / 6) * 105))
		effect.loop_visual = true
		effect.play()
		effects.append(effect)
	_label(
		"CHARGE : 24 effets + 90 sprites témoins Mousseroc ; aucun combat simulé",
		Vector2(20, 680),
		16
	)
	for _i: int in 30:
		await process_frame
		await RenderingServer.frame_post_draw
	var intervals: Array[float] = []
	var draw_calls: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for _i: int in 120:
		await process_frame
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		intervals.append((now - previous) / 1000.0)
		previous = now
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	intervals.sort()
	draw_calls.sort()
	var report := {
		"kind": "mesure de rendu isolée, pas un benchmark de combat",
		"effects": 24,
		"boss_effects": 8,
		"sprite_load": 90,
		"sprite_visual_id": "monster.mossback",
		"combat_simulated": false,
		"resolution": [1280, 720],
		"zoom": ZOOM,
		"warmup_frames": 30,
		"measured_frames": 120,
		"median_frame_interval_ms": intervals[60],
		"p95_frame_interval_ms": intervals[114],
		"median_draw_calls": draw_calls[60],
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"processor": OS.get_processor_name(),
		"vsync_requested": "disabled"
	}
	FileAccess.open(out.path_join("performance.json"), FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	root.get_texture().get_image().save_png(out.path_join("charge.png"))
	print(JSON.stringify(report))
