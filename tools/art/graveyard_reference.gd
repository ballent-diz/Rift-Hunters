extends DraftRun
## Comparaison de matière dans la vraie partie, cinq régions, mêmes lumières/caméra/sprites figés.

const REGIONS := {
	"crypt": [Vector3(0, 2, -14), Vector3(-0.8, 0, -9),
		Vector3(-4.5, 0, -7), Vector3(3.6, 0, -5.8), Vector3(6, 0, -8)],
	"graves": [Vector3(-25, 0.8, 18), Vector3(-23, 0, 17),
		Vector3(-29, 0, 16), Vector3(-19, 0, 21), Vector3(-30, 0, 22)],
	"mound": [Vector3(-31, 1.4, -22), Vector3(-32, 2.05, -22),
		Vector3(-27, 2.05, -25), Vector3(-35, 2.05, -22), Vector3(-24, 0, -18)],
	"wood": [Vector3(25, 0.8, 18), Vector3(22, 0, 17),
		Vector3(24, 0, 22), Vector3(27, 0, 16), Vector3(21, 0, 20)],
	"gate": [Vector3(0, 0.8, 26), Vector3(0, 0, 27),
		Vector3(-3, 0, 26), Vector3(3, 0, 25), Vector3(1, 0, 23)]}

func _ready() -> void:
	get_tree().create_timer(45.0).timeout.connect(func() -> void: get_tree().quit(1))
	await super._ready()
	assert(chapter == 2, "Référence prévue pour --chapter=2")
	set_process(false)
	set_physics_process(false)
	hunter.set_physics_process(false)
	enemies.set_physics_process(false)
	hud.hide()
	var region := "crypt"
	var output := "user://graveyard-reference"
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
	pixel.place(poses[0], 20.0, CAMERA_OFFSET)
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.render_loop_enabled = true
	for frame: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(output.path_join(region + ".png")) == OK)
	var report := {"scene": "DraftRun", "region": region, "camera_view": 20.0,
		"focus": str(poses[0]), "hunter": str(hunter.global_position), "enemies": enemies_report,
		"pixel_enabled": pixel.enabled, "palette_colors": pixel.palette.colors.size(), "texel_m": pixel.texel_size}
	FileAccess.open(output.path_join(region + ".json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("GRAVEYARD_REFERENCE ", JSON.stringify(report))
	get_tree().quit()
