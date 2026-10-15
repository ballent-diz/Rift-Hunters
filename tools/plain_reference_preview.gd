extends Node
## Captures du nouveau niveau, dans une session isolée, sans sauvegarde.
var _out := "user://level-preview"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	Settings.set_locale("fr")
	var setup := RunSetup.new()
	setup.arena_id = &"fractured_plain"
	setup.starter_id = &"mossback"
	setup.run_seed = 7
	setup.autopilot = true
	var run: RunController = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	run.start(setup)
	add_child(run)
	run.set_physics_process(false)
	get_tree().paused = true
	run.camera.position_smoothing_enabled = false
	var positions: Array[Vector2] = [Vector2(620, 175), Vector2(1130, 480), Vector2(1010, 880)]
	var names: Array[String] = ["nord", "ruines", "sud"]
	for i: int in positions.size():
		run.ctx.player.global_position = positions[i] - run.ctx.arena.size * 0.5
		run.ctx.allies.get_ally(&"mossback").global_position = run.ctx.player.global_position + Vector2(35, 20)
		run.camera.reset_smoothing()
		await get_tree().process_frame
		await get_tree().create_timer(0.1, true).timeout
		await RenderingServer.frame_post_draw
		_save(names[i])
	var view: Vector2 = get_viewport().get_visible_rect().size
	run.camera.zoom = Vector2.ONE * minf(view.x / run.ctx.arena.size.x, view.y / run.ctx.arena.size.y) * 0.92
	run.ctx.player.global_position = Vector2.ZERO
	run.camera.limit_left = -10000
	run.camera.limit_right = 10000
	run.camera.limit_top = -10000
	run.camera.limit_bottom = 10000
	run.hud.visible = false
	run.camera.reset_smoothing()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("panorama")
	get_tree().paused = false
	get_tree().quit()


func _save(label: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join(label + ".png")
	image.save_png(path)
	print("Capture : ", path)
