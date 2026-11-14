extends Node3D
## Banc d'art : même lumière, même zoom, mêmes positions et mêmes poses avant/après.

var actors: Array[DraftSpriteView] = []

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	var folder := "user://cour-previews"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(folder)
	var level := DraftLevelRuins.new()
	add_child(level)
	level.build()
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = level.sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = level.ambient
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54, -35, 0)
	sun.light_color = level.sun
	sun.light_energy = level.sun_energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 145, 0)
	fill.light_color = Color("7b7cb5")
	fill.light_energy = 0.18
	add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0
	camera.far = 160
	add_child(camera)
	camera.current = true
	for id: StringName in [&"player.hunter", &"enemy.skitterling", &"enemy.husk"]:
		var view := DraftSpriteView.new()
		add_child(view)
		view.setup(id)
		view.set_process(false)
		actors.append(view)
	var shots := [
		{"name": "terrasse", "at": Vector3(0, 2, -16),
			"poses": [Vector3(0, 2.06, -15), Vector3(-3.2, 2.06, -15.5), Vector3(3, 2.06, -16)]},
		{"name": "escaliers", "at": Vector3(0, 0.8, -9),
			"poses": [Vector3(-0.8, 1.05, -9), Vector3(2, 0.06, -5), Vector3(5.5, 0.06, -7)]},
		{"name": "abris", "at": Vector3(0, 0.5, 4),
			"poses": [Vector3(-5.8, 0.06, 0.4), Vector3(1.5, 0.06, 4), Vector3(-2.5, 0.06, 2)]},
		{"name": "entrepots", "at": Vector3(-36, 0.5, 4),
			"poses": [Vector3(-35, 0.06, 4), Vector3(-38, 0.06, 3), Vector3(-32, 0.06, 2)]}
	]
	for shot: Dictionary in shots:
		var at: Vector3 = shot.at
		camera.position = at + Vector3(0, 18, 17)
		camera.look_at(at)
		for i: int in actors.size():
			actors[i].snap_to(shot.poses[i])
		for i: int in 5:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := folder.path_join(shot.name + ".png")
		assert(get_viewport().get_texture().get_image().save_png(path) == OK)
		print("COUR_CAPTURE ", path)
	# Mesure indicative de complexité visuelle, distincte d'un benchmark de gameplay.
	print("COUR_DRAW_CALLS ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	get_tree().quit()
