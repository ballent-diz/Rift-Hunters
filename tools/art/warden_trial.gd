extends DraftRun
## Partie jouable avec la variante visuelle ; aucune donnée du joueur ou de son équilibrage ne change.
## --warden=0 garde le Chasseur ; --warden-capture fige les deux références aux mêmes poses.

const VISUAL := &"player.threshold_warden"

func _ready() -> void:
	await super._ready()
	var args := OS.get_cmdline_user_args()
	var variant := not args.has("--warden=0")
	if variant:
		var entry := Assets.entry(VISUAL)
		var report := AssetValidator.validate_entry(str(VISUAL), entry)
		assert(report.status == "OK", JSON.stringify(report))
		var old_view := hunter.view
		hunter.view = DraftSpriteView.new()
		hunter.add_child(hunter.view)
		hunter.view.setup(VISUAL)
		hunter.view.walk_speed = old_view.walk_speed
		hunter.view.snap_to(hunter.global_position)
		hunter.view.face_left(old_view.sprite.flip_h)
		old_view.hide()
		old_view.queue_free()
	if not args.has("--warden-capture"):
		return
	get_tree().create_timer(45.0).timeout.connect(func() -> void: get_tree().quit(1))
	set_process(false)
	set_physics_process(false)
	hunter.set_physics_process(false)
	enemies.set_physics_process(false)
	hud.hide()
	var focus := Vector3(0, 0.8, -9)
	var start_pose := Vector3(-0.8, 1.05, -9)
	var poses := [Vector3(-4.5, 0.05, -7), Vector3(3.6, 0.05, -5.8), Vector3(6, 0.05, -8)]
	if chapter == 4:
		focus = Vector3(0, 3, -24)
		start_pose = Vector3(0, 2.05, -25)
		poses = [Vector3(3, 2.05, -24), Vector3(6, 2.05, -24), Vector3(1, 0, -18)]
	hunter.global_position = level.closest(start_pose)
	hunter.reset_motion()
	hunter.view.set_process(false)
	var enemies_report := []
	for index: int in mini(3, roster.enemies.size()):
		var data := roster.enemies[index]
		var foe := enemies.spawn(data, level.closest(poses[index]))
		foe.view.set_process(false)
		enemies_report.append({"id": str(data.id), "at": str(foe.pos)})
	pixel.place(focus, 20.0, CAMERA_OFFSET)
	var output := "user://warden-reference"
	for arg: String in args:
		if arg.begins_with("--reference-out="):
			output = arg.trim_prefix("--reference-out=")
	DirAccess.make_dir_recursive_absolute(output)
	for frame: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var filename := "chapter_%d_%s" % [chapter, "warden" if variant else "hunter"]
	assert(get_viewport().get_texture().get_image().save_png(output.path_join(filename + ".png")) == OK)
	var result := {"chapter": chapter, "visual": str(VISUAL) if variant else "player.hunter", "view_size": 20.0,
		"hunter": str(hunter.global_position), "enemies": enemies_report, "focus": str(focus),
		"cell": hunter.view.entry.cell, "anchor": hunter.view.entry.anchor, "pixel_m": hunter.view.sprite.pixel_size,
		"visual_validation": "OK"}
	FileAccess.open(output.path_join(filename + ".json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("WARDEN_REFERENCE ", JSON.stringify(result))
	get_tree().quit()
