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
	setup.arena_id = &"storm_highlands"
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
	var positions: Array[Vector2] = [Vector2(400, 680), Vector2(1850, 1750), Vector2(1700, 3050), Vector2(950, 2450), Vector2(3200, 2800)]
	var names: Array[String] = ["depart", "cite", "remparts", "cendres", "plateau"]
	for i: int in positions.size():
		run.ctx.player.global_position = positions[i] * (run.ctx.arena.size.x / 3762.0) - run.ctx.arena.size * 0.5
		run.ctx.allies.get_ally(&"mossback").global_position = run.ctx.player.global_position + Vector2(35, 20)
		run.camera.reset_smoothing()
		await get_tree().process_frame
		await get_tree().create_timer(0.1, true).timeout
		await RenderingServer.frame_post_draw
		_save(names[i])
	run.ctx.player.position = Vector2(.49, .47) * run.ctx.arena.size - run.ctx.arena.size * .5
	var ids: Array[StringName] = [&"heath_runner", &"slate_scarab", &"silver_harpy", &"ash_newt", &"menhir_warden", &"storm_knight", &"peak_chimera"]
	for j: int in ids.size():
		var pos: Vector2 = run.ctx.player.position + Vector2(-240 + (j % 4) * 150, -100 + (j / 4) * 150)
		run.ctx.enemies.spawn(GameDB.enemy(ids[j]), pos)
	run.spawner.spawn_boss()
	run.ctx.boss.position = run.ctx.player.position + Vector2(310, -100)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("bestiaire")
	run.camera.zoom = Vector2.ONE * minf(get_viewport().get_visible_rect().size.x / run.ctx.arena.size.x, get_viewport().get_visible_rect().size.y / run.ctx.arena.size.y) * 0.92
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
