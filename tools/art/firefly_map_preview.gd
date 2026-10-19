extends Node
## Comparaison visuelle uniquement : parties gelées, profil non lu, aucune collision produite.
const OUT := "res://docs/previews/bois-des-lucioles/"
const WORKING := "res://assets/environments/firefly_woods/map.webp"


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	get_window().unfocusable = true
	DirAccess.make_dir_recursive_absolute(OUT)
	Profile.read_only = true
	TranslationServer.set_locale("fr")
	var records: Array = []
	var specs: Array = [
		["fractured_plain", "plaine", Vector2(0.50, 0.22)],
		["three_rifts", "cascades", Vector2(0.14, 0.45)],
		["storm_highlands", "hautes-terres", Vector2(0.44, 0.43)],
		["fractured_plain", "bois", Vector2(0.45, 0.30)],
		["fractured_plain", "bois-sanctuaire", Vector2(0.45, 0.11)],
		["fractured_plain", "bois-depart", Vector2(0.10, 0.81)],
	]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			var selected: String = arg.trim_prefix("--only=")
			specs = specs.filter(func(spec: Array) -> bool: return spec[1] == selected)
	for spec: Array in specs:
		var setup := RunSetup.new()
		setup.arena_id = StringName(spec[0])
		setup.starter_id = &"mossback"
		setup.run_seed = 7
		setup.autopilot = true
		var run: RunController = load("res://scenes/run.tscn").instantiate()
		run.skip_profile = true
		run.start(setup)
		add_child(run)
		run.process_mode = Node.PROCESS_MODE_DISABLED
		var ground: ArenaGround
		for child: Node in run.ctx.world.get_children():
			if child is ArenaGround:
				ground = child as ArenaGround
		assert(ground != null)
		var size: Vector2 = run.ctx.arena.size
		if String(spec[1]).begins_with("bois"):
			size = Vector2(5016, 3344)
			var image := Image.load_from_file(ProjectSettings.globalize_path(WORKING))
			assert(image.get_size() == Vector2i(6270, 4180))
			var env := EnvironmentSet.new()
			env.map_texture = ImageTexture.create_from_image(image)
			env.smooth = true
			ground.environment = env
			ground.arena = run.ctx.arena.duplicate()
			ground.arena.size = size
			ground.material = null
			ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			ground.queue_redraw()
		run.hud.visible = false
		run.camera.position_smoothing_enabled = false
		run.camera.limit_left = -10000
		run.camera.limit_right = 10000
		run.camera.limit_top = -10000
		run.camera.limit_bottom = 10000
		run.camera.zoom = Vector2.ONE * run.ctx.balance.camera_zoom
		var position_pct: Vector2 = spec[2]
		run.ctx.player.global_position = position_pct * size - size * 0.5
		run.ctx.allies.get_ally(&"mossback").global_position = run.ctx.player.global_position + Vector2(55, 20)
		run.camera.global_position = run.ctx.player.global_position
		run.camera.reset_smoothing()
		for frame: int in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var shot: Image = get_viewport().get_texture().get_image()
		assert(shot.get_size() == Vector2i(1280, 720))
		shot.save_png(OUT + String(spec[1]) + "-zoom-jeu.png")
		records.append({"map": spec[1], "viewport": [1280, 720],
			"world_size": [size.x, size.y], "zoom": run.camera.zoom.x,
			"hunter_sprite_world_cell": 32, "echo": "mossback",
			"center_percent": [position_pct.x * 100, position_pct.y * 100]})
		print("Comparaison : ", spec[1])
		run.ctx.status_system = null
		run.ctx.spawner = null
		run.ctx.zones = null
		run.ctx.spells = null
		run.spawner = null
		run.event_director = null
		run.boss_controller = null
		run.queue_free()
		await get_tree().process_frame
	var file := FileAccess.open(OUT + "godot-comparaison.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t") + "\n")
	file.close()
	get_tree().quit()
