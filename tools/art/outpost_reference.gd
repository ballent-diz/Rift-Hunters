extends DraftRun
## Comparaison de matière dans la vraie partie, cinq régions, mêmes lumières/caméra/sprites figés.

const REGIONS := {
 "base": [Vector3(0, 1, 4), Vector3(0, 0, 9), Vector3(-3, 0, 8), Vector3(3, 0, 9), Vector3(1, 0, 12)],
 "landing": [Vector3(-3, 1, 24), Vector3(0, 0, 26), Vector3(-5, 0, 25), Vector3(4, 0, 23), Vector3(6, 0, 26)],
 "depot": [Vector3(-28, 1, -1), Vector3(-26.2, 0, 1), Vector3(-33.8, 0, 1), Vector3(-18.5, 0, 1), Vector3(-26.2, 0, 6)],
 "racks": [Vector3(29, 1, 0), Vector3(27, 0, -2.5), Vector3(30, 0, -2.5), Vector3(23, 0, -2.5), Vector3(33, 0, -2.5)],
 "plateau": [Vector3(0, 3, -24), Vector3(0, 2.05, -25), Vector3(3, 2.05, -24), Vector3(6, 2.05, -24), Vector3(1, 0, -18)],
 "overview": [Vector3(0, 0, 0), Vector3(0, 0, 26), Vector3(-3, 0, 24), Vector3(3, 0, 24), Vector3(0, 0, 22)]}

func _ready() -> void:
	get_tree().create_timer(45.0).timeout.connect(func() -> void: get_tree().quit(1))
	await super._ready()
	assert(chapter == 4, "Référence prévue pour --chapter=4")
	set_process(false)
	set_physics_process(false)
	hunter.set_physics_process(false)
	enemies.set_physics_process(false)
	hud.hide()
	var region := "base"
	var output := "user://outpost-reference"
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
	var enemies_report := []
	for index: int in mini(3, roster.enemies.size()):
		var data := roster.enemies[index]
		var foe := enemies.spawn(data, level.closest(poses[index + 2]))
		foe.view.set_process(false)
		enemies_report.append({"id": str(data.id), "at": str(foe.pos)})
	pixel.place(poses[0], 76.0 if region == "overview" else 20.0, CAMERA_OFFSET)
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.render_loop_enabled = true
	for frame: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(output.path_join(region + ".png")) == OK)
	var report := {"scene": "DraftRun", "region": region, "camera_view": 76.0 if region == "overview" else 20.0,
		"focus": str(poses[0]), "hunter": str(hunter.global_position), "enemies": enemies_report,
		"pixel_enabled": pixel.enabled, "palette_colors": pixel.palette.colors.size(), "texel_m": pixel.texel_size}
	FileAccess.open(output.path_join(region + ".json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("OUTPOST_REFERENCE ", JSON.stringify(report))
	get_tree().quit()
