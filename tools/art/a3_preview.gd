extends Node
## Captures 720p dans les vraies scènes, simulation gelée aux états à examiner ; profil isolé.

const OUT := "res://docs/previews/a3-failles/"

var _viewport: SubViewport
var _run: RunController
var _metrics: Dictionary = {}


func _ready() -> void:
	Profile.read_only = true
	TranslationServer.set_locale("fr")
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	await _make_run(&"three_rifts")
	var ctx: RunContext = _run.ctx
	_focus(Vector2(-960, -650), Vector2(-800, -550))
	await _save("01-barriere-fermee", 0.2)
	await _sequence("barrier", 16)
	var wall: int = ctx.zones._walls[0][0]
	ctx.obstacles.set_wall_enabled(wall, false)
	ctx.zones.overlay.dissolve(wall)
	await _save("02-dissolution", 0.6)
	ctx.zones.phase = ZoneDirector.Phase.ENTER
	ctx.zones.zone_index = 1
	await _save("03-fleche", 0.7)
	for i: int in ctx.obstacles.walls.size():
		ctx.obstacles.set_wall_enabled(i, false)
	ctx.finale.start_travel()
	_focus(ctx.arena.finale_center - Vector2(200, 0), Vector2(1460, -150))
	ctx.finale.step(0.01)
	await _save("04-arene-materialisation", 0.22)
	await _save("05-arene-mur-continu", 0.5)
	_focus(ctx.arena.finale_center - Vector2(180, 0), ctx.arena.finale_center - Vector2(0, 60))
	ctx.finale.step(ctx.arena.finale_opening_duration * 0.8)
	await _save("06-faille-boss", 0.1)
	ctx.finale.step(ctx.arena.finale_opening_duration)
	await _save("07-sortie-nebulorax", 0.12)
	_focus(ctx.arena.finale_center - Vector2(200, 0), Vector2(1460, -150))
	for i: int in 90:
		ctx.enemies.spawn(GameDB.enemy(&"skitterling"), Vector2(1460, -150) + Vector2.from_angle(i * TAU / 90.0) * 180.0)
	await _benchmark("cascade_walls")
	await _make_run(&"storm_highlands")
	ctx = _run.ctx
	var rift: Enemy = ctx.rifts.rifts[0]
	_focus(rift.position + Vector2(-130, 40), rift.position - Vector2(0, 35))
	ctx.rifts.step(0.0)
	await _save("08-faille-ouverte", 0.2)
	ctx.combat.deal_damage(rift, DamageInfo.make(10.0, DamageInfo.SourceKind.PLAYER, &"player"))
	await _save("09-faille-impact", 0.12)
	ctx.combat.deal_damage(rift, DamageInfo.make(100000.0, DamageInfo.SourceKind.PLAYER, &"player"))
	ctx.enemies.step(0.0)
	ctx.rifts.step(0.0)
	await _sequence("closure", 8)
	await _make_run(&"storm_highlands")
	ctx = _run.ctx
	rift = ctx.rifts.rifts[0]
	_focus(rift.position + Vector2(-130, 40), rift.position - Vector2(0, 35))
	for i: int in 90:
		var angle: float = TAU * i / 90.0
		var pos: Vector2 = rift.position + Vector2.from_angle(angle) * (100.0 + (i % 5) * 35.0)
		var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(&"skitterling"), pos)
		if i < 3:
			ctx.rifts._art.emerge(enemy)
	await _save("11-sorties-corrompus-90", 0.15)
	await _benchmark("storm_rifts")
	var file := FileAccess.open(OUT + "performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_metrics, "\t") + "\n")
	print("A3 : ", _metrics)
	_run.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _benchmark(key: String) -> void:
	var ctx: RunContext = _run.ctx
	var results: Dictionary = {}
	for enabled: bool in [false, true]:
		if ctx.rifts:
			ctx.rifts.visible = enabled
			ctx.rifts._art.visible = enabled
		for node: Node in ctx.world.get_children():
			if node is ZoneOverlay:
				(node as ZoneOverlay).visible = enabled
		var samples: Array[float] = []
		for i: int in 30:
			await get_tree().process_frame
		var previous: int = Time.get_ticks_usec()
		for i: int in 60:
			await get_tree().process_frame
			var current: int = Time.get_ticks_usec()
			samples.append((current - previous) / 1000.0)
			previous = current
		for i: int in ctx.enemies.list.size():
			ctx.enemies.list[i].visual.tick(0.016, false)
		samples.sort()
		results["effects_on" if enabled else "effects_off"] = {
			"median_frame_ms": samples[30], "p95_frame_ms": samples[57], "samples": samples.size()}
	results["corrupted"] = 90
	results["note"] = "Coût local du rendu ; simulation gelée pour garder 90 Corrompus identiques."
	_metrics[key] = results


func _make_run(arena: StringName) -> void:
	if _run:
		_run.queue_free()
		await get_tree().process_frame
	var setup := RunSetup.new()
	setup.arena_id = arena
	setup.starter_id = &"mossback"
	_run = load("res://scenes/run.tscn").instantiate()
	_run.skip_profile = true
	_run.start(setup)
	_viewport.add_child(_run)
	_run.set_physics_process(false)
	await get_tree().process_frame


func _focus(player: Vector2, center: Vector2) -> void:
	_run.ctx.player.position = player
	for ally: Ally in _run.ctx.allies.team:
		ally.position = player + Vector2(-40, 30)
	_run.camera.position_smoothing_enabled = false
	_run.camera.global_position = center
	_run.camera.reset_smoothing()


func _sequence(prefix: String, count: int) -> void:
	var folder: String = OS.get_environment("A3_FRAME_DIR")
	if folder.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(folder)
	for i: int in count:
		await get_tree().create_timer(1.0 / 12.0).timeout
		await RenderingServer.frame_post_draw
		var image: Image = _viewport.get_texture().get_image()
		image.save_png(folder.path_join("%s_%02d.png" % [prefix, i]))
		if prefix == "closure" and i == 3:
			image.save_png(OUT + "10-faille-fermeture.png")


func _save(name: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(OUT + name + ".png")
	print("Capture A3 : ", name)
