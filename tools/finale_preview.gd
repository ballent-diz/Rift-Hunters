extends Node
func _ready() -> void:
	var out := "user://finale-preview"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	Settings.set_locale("fr")
	var setup := RunSetup.new()
	setup.arena_id = &"three_rifts"
	setup.starter_id = &"mossback"
	setup.autopilot = true
	var run: RunController = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	run.start(setup)
	add_child(run)
	run.set_physics_process(false)
	run.camera.position_smoothing_enabled = false
	run.ctx.time = run.ctx.arena.boss_time
	run.ctx.finale.step(0.1)
	run.ctx.player.position = run.ctx.arena.finale_center - Vector2(210, 0)
	run.ctx.finale.step(0.1)
	run.ctx.finale.step(1.5)
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("faille.png"))
	run.ctx.finale.step(2)
	run.ctx.finale.enforce_boundary()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("nebulorax.png"))
	get_tree().quit()
