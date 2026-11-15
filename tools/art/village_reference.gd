extends DraftRun
## Six cadrages de la vraie partie : acteurs et combat figés pour comparer la matière uniquement.

const REGIONS := {
	"square": [Vector3(0, 1, 17), Vector3(-2, 0, 20),
		Vector3(4, 0, 21), Vector3(-6, 0, 15), Vector3(3, 0, 13)],
	"bridge": [Vector3(0, 0.4, 0), Vector3(0, 0, 2.5),
		Vector3(-1.5, 0, -1), Vector3(1.5, 0, 1.5), Vector3(0, 0, -4.5)],
	"fields": [Vector3(-29, 1, -18), Vector3(-20, 0, -12),
		Vector3(-30, 0, -19), Vector3(-23, 0, -20), Vector3(-35, 0, -17)],
	"church": [Vector3(0, 2, -25), Vector3(3, 2.05, -23),
		Vector3(-1.5, 2.05, -21), Vector3(6, 2.05, -26), Vector3(4, 0, -16)],
	"grove": [Vector3(29, 0.8, -14), Vector3(27, 0, -8),
		Vector3(24, 0, -9), Vector3(31, 0, -6.5), Vector3(34, 0, -7)],
	"overview": [Vector3(0, 0.5, 0), Vector3(0, 0, 23),
		Vector3(-4, 0, 22), Vector3(5, 0, 20), Vector3(0, 0, 19)]}

func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func() -> void: get_tree().quit(1))
	await super._ready()
	assert(chapter == 3, "Référence prévue pour --chapter=3")
	set_process(false)
	set_physics_process(false)
	hunter.set_physics_process(false)
	enemies.set_physics_process(false)
	hud.hide()
	var region := "square"
	var output := "user://village-reference"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--reference-region="):
			region = arg.trim_prefix("--reference-region=")
		if arg.begins_with("--reference-out="):
			output = arg.trim_prefix("--reference-out=")
	assert(REGIONS.has(region))
	var poses: Array = REGIONS[region]
	hunter.global_position = level.closest(poses[1])
	hunter.reset_motion()
	hunter.view.set_process(false)
	var actors := []
	for index: int in mini(3, roster.enemies.size()):
		var data := roster.enemies[index]
		var foe := enemies.spawn(data, level.closest(poses[index + 2]))
		foe.view.set_process(false)
		actors.append({"id": str(data.id), "at": str(foe.pos)})
	var view := 70.0 if region == "overview" else 20.0
	pixel.place(poses[0], view, CAMERA_OFFSET)
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.render_loop_enabled = true
	for frame: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(output.path_join(region + ".png")) == OK)
	var report := {"scene": "DraftRun", "region": region, "camera_view": view,
		"focus": str(poses[0]), "hunter": str(hunter.global_position), "enemies": actors,
		"pixel_enabled": pixel.enabled, "palette_colors": pixel.palette.colors.size(), "texel_m": pixel.texel_size}
	FileAccess.open(output.path_join(region + ".json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("VILLAGE_REFERENCE ", JSON.stringify(report))
	get_tree().quit()
