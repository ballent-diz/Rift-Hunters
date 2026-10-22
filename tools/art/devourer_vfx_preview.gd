extends Node
## Captures des ressources autonomes dans une vraie partie gelÃ©e, sans branchement de combat.
const OUT := "res://docs/previews/devourer-vfx/"
var _run: RunController
var _frames: String
var _viewport: SubViewport


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	get_window().mode = Window.MODE_MINIMIZED
	AudioServer.set_bus_mute(0, true)
	Profile.read_only = true
	DirAccess.make_dir_recursive_absolute(OUT)
	_frames = ProjectSettings.globalize_path("res://").path_join("../chapter2-generation/vfx-frames/").simplify_path()
	DirAccess.make_dir_recursive_absolute(_frames)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var setup := RunSetup.new()
	setup.arena_id = &"three_rifts"
	setup.starter_id = &"mossback"
	setup.run_seed = 7
	_run = load("res://scenes/run.tscn").instantiate()
	_run.skip_profile = true
	_run.start(setup)
	_viewport.add_child(_run)
	get_tree().paused = true
	_run.set_physics_process(false)
	_run.hud.visible = false
	var center: Vector2 = _run.ctx.arena.finale_center
	_run.ctx.player.global_position = center + Vector2(170, 105)
	_run.ctx.allies.get_ally(&"mossback").global_position = center + Vector2(210, 120)
	_run.camera.position_smoothing_enabled = false
	_run.camera.global_position = center
	_run.camera.reset_smoothing()
	var boss := AnimatedSprite2D.new()
	boss.sprite_frames = Assets.get_sprite_frames(&"boss.source_devourer")
	boss.centered = false
	boss.offset = -Assets.anchor(&"boss.source_devourer")
	boss.position = center + Vector2(-150, 15)
	boss.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boss.z_index = 3
	_run.add_child(boss)
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/vfx/bosses/source_devourer/catalog.json"))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			var selected: PackedStringArray = argument.trim_prefix("--only=").split(",")
			catalog = catalog.filter(func(spec: Dictionary) -> bool: return String(spec.id) in selected)
	for spec: Dictionary in catalog:
		await _capture(spec, boss, center)
	await _benchmark(center)
	get_tree().paused = false
	_run.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _capture(spec: Dictionary, boss: AnimatedSprite2D, center: Vector2) -> void:
	var effect: Node2D = load(spec.scene).instantiate()
	effect.set("destroy_on_finish", false)
	_run.add_child(effect)
	effect.position = center + Vector2(10, 0)
	if spec.id in ["rift_breath", "phase2_breath", "roar", "rift_fragment"]:
		effect.position = boss.position + Vector2(90, -105)
	if spec.id in ["transform", "death", "hurt"]:
		effect.position = boss.position
	if spec.id == "summon":
		effect.call("set_secondary_offsets", PackedVector2Array([Vector2(40, -90), Vector2(130, 50)]))
	var animation := StringName(spec.get("sprite_animation", "idle") if spec.get("sprite_animation") else "idle")
	if not boss.sprite_frames.has_animation(animation):
		animation = &"idle"
	boss.animation = animation
	var folder: String = _frames.path_join(String(spec.id)) + "/"
	DirAccess.make_dir_recursive_absolute(folder)
	var warning: Node2D = null
	if spec.id in ["claw", "heavy_slam", "rift_breath", "root_sweep", "phase2_claw", "phase2_breath", "phase2_slam"]:
		warning = load("res://assets/vfx/bosses/source_devourer/indicator.tscn").instantiate()
		warning.set("destroy_on_finish", false)
		warning.set("radius", float(spec.radius))
		warning.set("width", float(spec.width))
		warning.set("travel_distance", float(spec.travel_distance))
		warning.set("target_shape", StringName(spec.shape))
		_run.add_child(warning)
		warning.position = effect.position
		effect.visible = false
		for frame: int in 6:
			warning.call("seek_visual", float(frame) / 7.0 * 0.8)
			await _save(folder + "%02d.png" % frame)
		warning.queue_free()
		effect.visible = true
	for frame: int in 24:
		var progress: float = float(frame) / 24.0
		effect.call("seek_visual", progress * float(spec.duration))
		boss.frame = mini(int(progress * 6.0), boss.sprite_frames.get_frame_count(animation) - 1)
		await _save(folder + "%02d.png" % (frame + 6))
		if frame == 10:
			await _save(OUT + String(spec.id) + ".png")
	effect.queue_free()
	await get_tree().process_frame
	print("VFX : ", spec.id)


func _save(path: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	_viewport.get_texture().get_image().save_png(path)


func _benchmark(center: Vector2) -> void:
	for index: int in 90:
		var point := center + Vector2(-320 + (index % 15) * 44, -180 + (index / 15) * 62)
		_run.ctx.enemies.spawn(GameDB.enemy(&"skitterling"), point)
	for warmup: int in 20:
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	var effects: Array[Node2D] = []
	for index: int in 8:
		var effect: Node2D = load("res://assets/vfx/bosses/source_devourer/phase2_slam.tscn").instantiate()
		effect.set("destroy_on_finish", false)
		effect.set("particle_budget", 8)
		_run.add_child(effect)
		effect.position = center + Vector2(-200 + (index % 4) * 140, -80 + (index / 4) * 170)
		effects.append(effect)
	var times: Array[float] = []
	for sample: int in 80:
		var begin: int = Time.get_ticks_usec()
		for effect: Node2D in effects:
			effect.call("seek_visual", 0.25 + float(sample % 20) * 0.03)
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		if sample >= 20:
			times.append(float(Time.get_ticks_usec() - begin) / 1000.0)
	times.sort()
	var file := FileAccess.open(OUT + "performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"enemies": 90, "effects": 8, "samples": 60, "warmup_frames": 40,
		"median_frame_ms": times[30], "p95_frame_ms": times[57],
		"renderer": RenderingServer.get_video_adapter_name(),
		"measurement": "Partie gelÃ©e ; prÃ©sentation et dessin, pas le coÃ»t de lâ€™IA ni des collisions."}, "\t"))
