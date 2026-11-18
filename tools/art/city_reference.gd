extends DraftRun
## Comparaison de matière dans la vraie partie, sept régions, mêmes lumières/caméra/sprites figés.

const REGIONS := {
 "forum": [Vector3(0, 1, -5), Vector3(0, 0, -5), Vector3(-3.5, 0, -7), Vector3(3.5, 0, -7), Vector3(5, 0, -4)],
 "gate": [Vector3(0, 1, 23), Vector3(0, 0, 24), Vector3(-2, 0, 23), Vector3(2, 0, 23), Vector3(0, 0, 20)],
 "houses": [Vector3(-32, 1, 10), Vector3(-32, 0, 11), Vector3(-33, 0, 8), Vector3(-30, 0, 9), Vector3(-31, 0, 14)],
 "warehouses": [Vector3(32, 1, 13), Vector3(33, 0, 15), Vector3(30, 0, 17), Vector3(34, 0, 10), Vector3(34, 0, 19)],
 "temple": [Vector3(35, 1, -14), Vector3(34, 0, -12), Vector3(31, 0, -14), Vector3(38, 0, -13), Vector3(36, 0, -17)],
 "acropolis": [Vector3(0, 3, -24), Vector3(0, 2.05, -25), Vector3(-4, 2.05, -24), Vector3(4, 2.05, -24), Vector3(0, 0, -17)],
 "overview": [Vector3(0, 0, 0), Vector3(0, 0, 24), Vector3(-2, 0, 23), Vector3(2, 0, 23), Vector3(0, 0, 20)]}

var _reference_foes: Array[DraftEnemies.Foe] = []

func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func() -> void: get_tree().quit(1))
	await super._ready()
	print("CITY_CAPTURE_READY ", OS.get_cmdline_user_args())
	assert(chapter == 5, "Référence prévue pour --chapter=5")
	set_process(false)
	set_physics_process(false)
	hunter.set_physics_process(false)
	enemies.set_physics_process(false)
	hud.hide()
	var region := "forum"
	var output := "user://city-reference"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--reference-region="):
			region = arg.trim_prefix("--reference-region=")
		if arg.begins_with("--reference-out="):
			output = arg.trim_prefix("--reference-out=")
	assert(REGIONS.has(region) or region == "all")
	print("CITY_CAPTURE_PLAN ", region, " ", REGIONS.keys())
	for index: int in mini(3, roster.enemies.size()):
		var foe := enemies.spawn(roster.enemies[index], level.closest(Vector3.ZERO))
		foe.view.set_process(false)
		_reference_foes.append(foe)
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.render_loop_enabled = true
	for name_region: String in REGIONS:
		if region == "all" or region == name_region:
			print("CITY_CAPTURE_BEGIN ", name_region)
			await capture_region(name_region, output)
	get_tree().quit()

func capture_region(region: String, output: String) -> void:
	var poses: Array = REGIONS[region]
	hunter.global_position = level.closest(poses[1])
	hunter.reset_motion()
	hunter.view.set_process(false)
	var enemies_report := []
	for index: int in _reference_foes.size():
		var foe := _reference_foes[index]
		foe.pos = level.closest(poses[index + 2])
		foe.view.snap_to(foe.pos)
		enemies_report.append({"id": str(roster.enemies[index].id), "at": str(foe.pos)})
	pixel.place(poses[0], 76.0 if region == "overview" else 20.0, CAMERA_OFFSET)
	for frame: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(output.path_join(region + ".png")) == OK)
	var report := {"scene": "DraftRun", "region": region, "camera_view": 76.0 if region == "overview" else 20.0,
		"focus": str(poses[0]), "hunter": str(hunter.global_position), "enemies": enemies_report,
		"pixel_enabled": pixel.enabled, "palette_colors": pixel.palette.colors.size(), "texel_m": pixel.texel_size}
	FileAccess.open(output.path_join(region + ".json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CITY_REFERENCE ", JSON.stringify(report))
