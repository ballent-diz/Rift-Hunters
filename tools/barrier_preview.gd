extends Node
## Captures des barrières peintes au zoom réel d'une partie (docs/art/BARRIERES_PEINTES.md).
## Usage : xvfb-run -a godot --path . --resolution 1280x720 res://tools/barrier_preview.tscn --
##         --arena=three_rifts --out=/chemin [--stress=60]
## Pose une barrière droite, un angle est→sud et une barrière verticale autour du Chasseur (rendu seulement),
## capture le voile en boucle, en dissolution puis les bornes ouvertes. --stress : N barrières en plus,
## mesure du temps de _process de l'overlay et des appels de dessin.

const WALLS: Array[Rect2] = [Rect2(-400, 40, 260, 40), Rect2(-60, -140, 260, 40), Rect2(180, -140, 40, 300),
	Rect2(320, -180, 40, 300)]


func _ready() -> void:
	var out := "user://barrier-preview"
	var arena := &"three_rifts"
	var stress: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--arena="):
			arena = StringName(arg.trim_prefix("--arena="))
		elif arg.begins_with("--stress="):
			stress = int(arg.trim_prefix("--stress="))
	DirAccess.make_dir_recursive_absolute(out)
	var setup := RunSetup.new()
	setup.arena_id = arena
	setup.starter_id = &"ashblade"
	setup.autopilot = true
	var run: RunController = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	run.start(setup)
	add_child(run)
	run.set_physics_process(false)
	run.camera.position_smoothing_enabled = false
	var ctx: RunContext = run.ctx
	var overlay: ZoneOverlay = null
	for child: Node in ctx.world.get_children():
		if child is ZoneOverlay:
			overlay = child
	if overlay == null:
		overlay = ZoneOverlay.new()
		overlay.setup(ctx)
		ctx.world.add_child(overlay)
	await get_tree().process_frame
	var center: Vector2 = run.camera.get_screen_center_position().round()
	var ids: Array[int] = []
	for rect: Rect2 in WALLS:
		ids.append(ctx.obstacles.add_wall(Rect2(rect.position + center, rect.size)))
	for i: int in stress:
		ctx.obstacles.add_wall(Rect2(center + Vector2(-3000 + (i % 10) * 600, -3000 + (i / 10) * 500), Vector2(260, 40)))
	ctx.obstacles.walls_version += 1
	await get_tree().create_timer(0.4).timeout
	await _shot(out, "apparition")
	await get_tree().create_timer(1.2).timeout
	await _shot(out, "boucle")
	if stress > 0:
		await _measure(overlay, out)
	for id: int in ids:
		ctx.obstacles.set_wall_enabled(id, false)
		overlay.dissolve(id)
	await get_tree().create_timer(0.45).timeout
	await _shot(out, "dissolution")
	await get_tree().create_timer(1.0).timeout
	await _shot(out, "bornes_ouvertes")
	get_tree().quit()


func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


func _measure(overlay: ZoneOverlay, out: String) -> void:
	var samples: Array[float] = []
	var calls: Array[int] = []
	for i: int in 60:
		var start: int = Time.get_ticks_usec()
		overlay._process(1.0 / 60.0)
		samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
		await RenderingServer.frame_post_draw
		calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	samples.sort()
	var report := "noeuds=%d process_ms_median=%.3f process_ms_max=%.3f draw_calls_max=%d\n" % [
		overlay.get_child_count(), samples[30], samples[-1], calls.max()]
	var file := FileAccess.open(out.path_join("mesure.txt"), FileAccess.WRITE)
	file.store_string(report)
