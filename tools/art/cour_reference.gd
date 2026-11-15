extends DraftRun
## Référence artistique issue de la véritable partie : mêmes shaders, lumière, caméra et sprites.
## Seuls le combat et les poses sont figés ; aucun changement de règle ou sauvegarde.

const FOCUS := Vector3(0, 0.8, -9)

func _ready() -> void:
	await super._ready()
	set_process(false)
	set_physics_process(false)
	hunter.set_physics_process(false)
	enemies.set_physics_process(false)
	hud.hide()
	hunter.global_position = level.closest(Vector3(-0.8, 1.05, -9))
	hunter.reset_motion()
	hunter.view.set_process(false)
	var poses := [Vector3(-4.5, 0.05, -7), Vector3(3.6, 0.05, -5.8), Vector3(6, 0.05, -8)]
	var ids := []
	for i: int in mini(3, roster.enemies.size()):
		var data := roster.enemies[i]
		var foe := enemies.spawn(data, poses[i])
		foe.view.set_process(false)
		ids.append(str(data.id))
	var output := "user://cour-reference"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--reference-out="):
			output = arg.trim_prefix("--reference-out=")
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.render_loop_enabled = true
	pixel.place(FOCUS, 20.0, CAMERA_OFFSET)
	for i: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(output.path_join("reference.png")) == OK)
	var report := {"scene": "DraftRun", "pixel_enabled": pixel.enabled, "view_size": 20.0,
		"texel_m": pixel.texel_size, "focus": str(FOCUS), "hunter": str(hunter.global_position),
		"enemies": ids, "palette_colors": pixel.palette.colors.size(), "combat": "figé pour comparaison"}
	FileAccess.open(output.path_join("reference.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("COUR_REFERENCE ", JSON.stringify(report))
	get_tree().quit()
