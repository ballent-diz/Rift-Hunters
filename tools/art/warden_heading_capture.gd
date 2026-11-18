extends DraftRun
## Captures du Veilleur des Seuils dans les quatre directions de marche (docs/art/VEILLEUR_DOS_FACE.md).
## Usage : xvfb-run -a godot --path . --fixed-fps 60 res://tools/art/warden_heading_capture.tscn -- --chapter=1 --out=<dossier>

const DIRECTIONS := {"haut": Vector2(0, 1), "bas": Vector2(0, -1), "gauche": Vector2(-1, 0), "droite": Vector2(1, 0)}


func _ready() -> void:
	await super._ready()
	var output := "user://warden-headings"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().create_timer(900.0).timeout.connect(func() -> void: get_tree().quit(1))
	while state != DraftRun.State.PLAYING:
		await get_tree().physics_frame
	boss_time = INF
	tuning = tuning.duplicate()
	tuning.waves.assign([{"at": 0.0, "rate": 0.0, "cap": 0, "mix": {"skitterling": 1.0}}])
	tuning.swarm_every = INF
	_swarm_at = INF
	hunter.attack_timer = 100000.0
	hunter.god_mode = true
	hunter.automating = true
	hud.hide()
	var right: Vector3 = camera.global_basis.x
	right.y = 0.0
	var away: Vector3 = -camera.global_basis.z
	away.y = 0.0
	var report := {}
	for label: String in DIRECTIONS:
		var screen: Vector2 = DIRECTIONS[label]
		hunter.auto_direction = (right.normalized() * screen.x + away.normalized() * screen.y).normalized()
		for frame: int in 30:
			await get_tree().physics_frame
		var moving := hunter.view.animation
		var flipped := hunter.view.sprite.flip_h
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("marche_%s.png" % label))
		hunter.auto_direction = Vector3.ZERO
		for frame: int in 30:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("repos_%s.png" % label))
		printerr("capture ", label, " ", hunter.view.animation)
		report[label] = {"move": str(moving), "idle": str(hunter.view.animation), "flip": flipped}
	print("WARDEN_HEADINGS ", JSON.stringify(report))
	get_tree().quit()
