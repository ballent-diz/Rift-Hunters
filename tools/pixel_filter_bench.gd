extends Node
## Banc du filtre pixel : coût de rendu avec une horde et scintillement de la grille quand la caméra glisse.
## Usage : xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 \
##         res://tools/pixel_filter_bench.tscn -- --arena=three_rifts [--horde=350] [--frames=90] [--out=/dossier]
## Rendu logiciel dans le cloud : seul l'écart relatif entre « off » et un préréglage est significatif.

var _run: RunController
var _ground: ArenaGround
var _horde: int = 350
var _frames: int = 90
var _out: String = ""


func _ready() -> void:
	var setup: RunSetup = Profile.make_run_setup(&"mossback")
	setup.autopilot = true
	setup.run_seed = 1
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=")
		match parts[0]:
			"arena":
				setup.arena_id = StringName(parts[1])
			"horde":
				_horde = int(parts[1])
			"frames":
				_frames = int(parts[1])
			"out":
				_out = parts[1]
	_run = load("res://scenes/run.tscn").instantiate()
	_run.skip_profile = true
	_run.start(setup)
	add_child(_run)
	_run.ctx.player.god_mode = true
	_ground = _run.ctx.world.find_children("*", "ArenaGround", false, false)[0] as ArenaGround
	_bench.call_deferred()


func _bench() -> void:
	await _wait(30)
	var data: EnemyData = GameDB.enemy(&"husk")
	if data == null:
		data = GameDB.enemy(GameDB.sorted_ids(GameDB.enemies)[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i: int in _horde:
		var offset := Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(120.0, 700.0)
		var enemy: Enemy = _run.ctx.enemies.spawn(data, _run.ctx.player.global_position + offset)
		enemy.invulnerable_time = 1.0e6
	await _wait(20)
	var results: Dictionary = {}
	var order: Array[String] = [PixelFilter.OFF, PixelFilter.GRAPHIC, PixelFilter.FINE]
	for preset: String in order + order:
		_ground.set_pixel_filter(preset)
		await _wait(10)
		var start: int = Time.get_ticks_usec()
		await _wait(_frames)
		var ms: float = (Time.get_ticks_usec() - start) / 1000.0 / _frames
		results[preset] = minf(float(results.get(preset, INF)), ms)
	print("BENCH horde=%d ennemis=%d off=%.2fms fine=%.2fms graphic=%.2fms" % [_horde, _run.ctx.enemies.count(),
			results[PixelFilter.OFF], results[PixelFilter.FINE], results[PixelFilter.GRAPHIC]])
	_run.ctx.enemies.process_mode = Node.PROCESS_MODE_DISABLED
	for preset: String in [PixelFilter.OFF, PixelFilter.GRAPHIC]:
		print("SHIMMER %s %.4f" % [preset, await _shimmer(preset)])
	get_tree().quit()


## Écart moyen entre images successives quand la caméra glisse doucement, après recalage du défilement : une
## grille mal ancrée scintillerait (écart nettement supérieur à celui du décor sans filtre).
func _shimmer(preset: String) -> float:
	_ground.set_pixel_filter(preset)
	var camera: Camera2D = get_viewport().get_camera_2d()
	camera.position_smoothing_enabled = false
	_run.ctx.player.set_physics_process(false)
	var base: Vector2 = camera.global_position
	var previous: Image = null
	var total: float = 0.0
	var steps: int = 8
	for i: int in steps + 1:
		camera.offset = Vector2(0.37 * i, 0.21 * i)
		await _wait(2)
		var image: Image = get_viewport().get_texture().get_image()
		if _out != "" and i == 0:
			image.save_png(_out.path_join("shimmer_%s.png" % preset))
		if previous != null:
			total += _aligned_diff(previous, image)
		previous = image
	camera.offset = Vector2.ZERO
	camera.global_position = base
	return total / steps


func _aligned_diff(a: Image, b: Image) -> float:
	var best: float = INF
	var size: Vector2i = a.get_size()
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			var sum: float = 0.0
			var n: int = 0
			for y: int in range(size.y / 2 - 150, size.y / 2 + 150, 3):
				for x: int in range(size.x / 2 - 300, size.x / 2 + 300, 3):
					var ca: Color = a.get_pixel(x, y)
					var cb: Color = b.get_pixel(x - dx, y - dy)
					sum += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
					n += 1
			best = minf(best, sum / n)
	return best


func _wait(frames: int) -> void:
	for i: int in frames:
		await get_tree().process_frame
