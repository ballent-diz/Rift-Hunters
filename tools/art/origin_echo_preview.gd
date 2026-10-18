extends Node
## Contrôle C5-ter dans la vraie partie : profil isolé, un vrai Écho et 90 ennemis gelés.
const OUT := "res://docs/previews/c5-echos-origine/"

var _viewport: SubViewport
var _run: RunController
var _layer: Node2D
var _center := Vector2.ZERO
var _metrics: Dictionary = {}


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	get_window().unfocusable = true
	Profile.read_only = true
	TranslationServer.set_locale("fr")
	DirAccess.make_dir_recursive_absolute(OUT)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var specs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/echoes/origin_catalog.json"))
	for spec: Dictionary in specs:
		print("C5-ter : ", spec.id)
		await _make_run(StringName(spec.id))
		if "--metrics-only" not in OS.get_cmdline_user_args():
			await _capture_echo(spec)
		await _benchmark(spec)
	var file := FileAccess.open(OUT + "performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_metrics, "\t") + "\n")
	print("C5-ter : sept captures, vingt et une séquences et sept mesures enregistrées.")
	_run.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("C5-ter : requête de fermeture reçue pendant le rendu, export en cours.")


func _make_run(identity: StringName) -> void:
	if _run:
		_run.queue_free()
		await get_tree().process_frame
	var setup := RunSetup.new()
	setup.arena_id = &"three_rifts"
	setup.starter_id = identity
	_run = load("res://scenes/run.tscn").instantiate()
	_run.skip_profile = true
	_run.start(setup)
	_viewport.add_child(_run)
	_run.set_physics_process(false)
	await get_tree().process_frame
	_center = _run.ctx.arena.finale_center
	_run.ctx.player.position = _center + Vector2(-155, 45)
	_run.ctx.allies.team[0].position = _center + Vector2(-85, 25)
	_run.camera.position_smoothing_enabled = false
	_run.camera.global_position = _center
	_run.camera.reset_smoothing()
	for i: int in 90:
		var pos: Vector2 = _center + Vector2.from_angle(i * 2.39996) * (175 + i % 6 * 30)
		if i < 8:
			pos = _center + Vector2(45, 25) + Vector2.from_angle(i * TAU / 8) * (65 + i % 2 * 15)
		var enemy: Enemy = _run.ctx.enemies.spawn(GameDB.enemy(&"skitterling"), pos)
		if enemy.visual._anim:
			enemy.visual._anim.pause()
	for child: Node in _run.ctx.world.get_children():
		if child is ZoneOverlay:
			(child as ZoneOverlay).hide()
	_layer = _run.ctx.allies.vfx.layer
	if _run.ctx.player.visual._anim:
		_run.ctx.player.visual._anim.pause()
	await get_tree().create_timer(1.8).timeout


func _capture_echo(spec: Dictionary) -> void:
	_clear()
	var caster: Vector2 = _run.ctx.allies.team[0].global_position
	var attack: Node2D = _effect(spec.id, "attack", caster)
	_configure_targets(attack, "attack", spec.id)
	attack.call("seek_visual", float(attack.call("duration")) * 0.4)
	if spec.status != null:
		var status: Node2D = _effect(spec.id, "status", _run.ctx.enemies.list[1].global_position)
		status.call("seek_visual", 0.35)
	var main_name: String = spec.spells[0][0]
	var main_origin: Vector2 = _run.ctx.player.global_position if main_name == "reflection" else _center + Vector2(45, 25)
	var main: Node2D = _effect(spec.id, main_name, main_origin)
	_configure_targets(main, main_name, spec.id)
	main.call("seek_visual", float(main.call("duration")) * 0.4)
	await _save(OUT + spec.id + ".png")
	var names: Array[String] = ["attack", spec.spells[0][0], spec.spells[1][0]]
	for name: String in names:
		_clear()
		var origin: Vector2 = caster if name == "attack" else _center + Vector2(45, 25)
		if name in ["ash_dance", "cinder_dash", "chain_arc", "mirror_shards", "feast"]:
			origin = caster
		if name == "reflection":
			origin = _run.ctx.player.global_position
		var effect: Node2D = _effect(spec.id, name, origin)
		_configure_targets(effect, name, spec.id)
		var indicator: Node2D = _effect(spec.id, "indicator", origin)
		indicator.set("target_shape", effect.get("target_shape"))
		indicator.set("radius", effect.get("radius"))
		indicator.set("travel_distance", effect.get("travel_distance"))
		indicator.call("seek_visual", 0.4)
		var frame_count: int = clampi(ceili(float(effect.call("duration")) * 16.0), 20, 64)
		print("Séquence : ", spec.id, "/", name, " · ", frame_count, " images")
		for i: int in frame_count:
			var divisor: float = frame_count if name == "reflection" else frame_count - 1.0
			effect.call("seek_visual", i / divisor * float(effect.call("duration")))
			indicator.visible = i < 3 and name != "attack"
			var ally: Ally = _run.ctx.allies.team[0]
			ally.visual.play_action(&"attack" if name == "attack" else &"technique")
			if ally.visual._anim:
				ally.visual._anim.pause()
				ally.visual._anim.frame = mini(ally.visual._anim.sprite_frames.get_frame_count(ally.visual._anim.animation) - 1,
					i / 3)
			var folder: String = OS.get_environment("ORIGIN_FRAME_DIR")
			if not folder.is_empty():
				DirAccess.make_dir_recursive_absolute(folder)
				await _save(folder.path_join("%s_%s_%02d.png" % [spec.id, name, i]))


func _configure_targets(effect: Node2D, name: String, id: String) -> void:
	if id == "thornweave" and name == "attack":
		effect.global_position = _center + Vector2(45, 25)
	var offsets := PackedVector2Array()
	var count: int = 0
	if name == "ash_dance":
		count = 6
	elif name in ["ion_storm", "prism_flare"]:
		count = 8 if name == "ion_storm" else 3
	elif name == "chain_arc" or (id == "voltwisp" and name == "attack"):
		count = 6 if name == "chain_arc" else 3
	elif id == "glimmerwing" and name == "attack":
		count = 1
	for i: int in count:
		offsets.append(effect.to_local(_run.ctx.enemies.list[i].global_position))
	if name == "bloom":
		offsets.append(effect.to_local(_run.ctx.player.global_position))
	if id == "mirrorling" and name == "attack":
		offsets.append(Vector2(120, 0))
		offsets.append(Vector2(30, -85))
	effect.call("set_secondary_offsets", offsets)


func _effect(id: String, name: String, origin: Vector2) -> Node2D:
	var scene: PackedScene = load("res://assets/vfx/echoes/%s/%s.tscn" % [id, name])
	var effect: Node2D = _layer.call("emit_effect", scene, origin, Vector2.RIGHT)
	effect.set("destroy_on_finish", false)
	effect.call("seek_visual", 0.0)
	return effect


func _clear() -> void:
	for node: Node in _layer.get_children():
		_layer.remove_child(node)
		node.queue_free()


func _save(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(path)


func _benchmark(spec: Dictionary) -> void:
	_clear()
	for i: int in 24:
		var name: String = spec.spells[i % 2][0]
		var effect: Node2D = _effect(spec.id, name,
			_center + Vector2.from_angle(i * 2.39996) * (i % 4) * 35)
		_configure_targets(effect, name, spec.id)
	var result: Dictionary = {"corrupted": 90, "emitters": 24, "particle_budget_per_emitter": 4,
		"note": "Rendu de la vraie partie gelée ; géométrie redessinée, IA et collisions non mesurées."}
	for enabled: bool in [false, true]:
		_layer.visible = enabled
		for i: int in 20:
			await get_tree().process_frame
		var samples: Array[float] = []
		var previous: int = Time.get_ticks_usec()
		for i: int in 60:
			if enabled:
				for effect: Node2D in _layer.get_children():
					effect.call("seek_visual", (0.15 + fmod(i * 0.017, 0.7)) * float(effect.call("duration")))
			await get_tree().process_frame
			var current: int = Time.get_ticks_usec()
			samples.append((current - previous) / 1000.0)
			previous = current
		samples.sort()
		result["effects_on" if enabled else "effects_off"] = {
			"median_frame_ms": samples[30], "p95_frame_ms": samples[57], "samples": 60}
	_layer.visible = true
	_metrics[spec.id] = result
