extends Node2D
## Captures et mesure du masquage par le décor (docs/maps/MASQUAGE_PAR_LE_DECOR.md), sur le secteur de démonstration
## du Bois des Lucioles (ruines du sud-ouest), au zoom réel du jeu.
## Captures : xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900
##   res://tools/art/preview_occlusion.tscn -- --out=<dossier>
## Mesure : même commande avec --bench=400 (Corrompus animés à l'écran, avec puis sans masquage).

const ARENA := &"firefly_woods"
const BENCH_FRAMES := 240
## Plans de démonstration : centre (pixels de la carte) et personnages {sorte, pied en pixels de la carte, gauche}.
## Sortes : 0 Chasseur, 1 Écho, 2 Corrompu.
const SHOTS: Array[Dictionary] = [
	{"name": "01_place_derriere_piliers", "center": [900, 4560], "actors": [
		[0, [762, 4655], false], [1, [985, 4805], true], [2, [870, 4610], false], [2, [1100, 4640], true]]},
	{"name": "02_place_devant_piliers", "center": [900, 4560], "actors": [
		[0, [762, 4760], false], [1, [985, 4935], true], [2, [870, 4610], false], [2, [1100, 4640], true]]},
	{"name": "03_colonne_pin_cloture_derriere", "center": [1450, 4120], "actors": [
		[0, [1378, 4115], false], [1, [1590, 4140], true], [2, [1250, 3905], false], [2, [1700, 4170], true]]},
	{"name": "04_colonne_pin_cloture_devant", "center": [1450, 4120], "actors": [
		[0, [1378, 4440], false], [1, [1590, 4300], true], [2, [1250, 4260], false], [2, [1700, 4170], true]]},
	{"name": "05_rocher", "center": [2220, 4520], "actors": [
		[0, [2230, 4460], false], [2, [2120, 4560], true], [1, [2330, 4790], false]]},
]

var _out: String = ""
var _bench: int = 0
var _arena: ArenaData
var _ground: ArenaGround
var _occlusion: OcclusionMap
var _camera := Camera2D.new()
var _actors: Array[EntityVisual] = []
var _map_size := Vector2.ONE


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--bench="):
			_bench = int(arg.get_slice("=", 1))
	_arena = GameDB.arena(ARENA)
	_ground = ArenaGround.new()
	_ground.setup(_arena, 1)
	add_child(_ground)
	var env: EnvironmentSet = _ground.environment
	_map_size = Vector2(env.map_texture.get_width() * maxi(env.map_tiles.size(), 1), env.map_texture.get_height())
	_occlusion = _ground.occlusion_map()
	_camera.zoom = Vector2.ONE * GameDB.balance.camera_zoom
	add_child(_camera)
	_camera.make_current()
	if _occlusion == null:
		push_error("Aperçu du masquage : pas de données pour %s" % ARENA)
		get_tree().quit(1)
		return
	if _bench > 0:
		_run_bench.call_deferred()
	else:
		_run_shots.call_deferred()


func _world(px: Array) -> Vector2:
	var rect: Rect2 = _ground.arena_rect()
	return rect.position + Vector2(float(px[0]), float(px[1])) / _map_size * rect.size


func _visual(kind: int, occluded: bool) -> EntityVisual:
	var data: VisualData = GameDB.balance.player_visual
	if kind == 1:
		data = GameDB.monster(&"ashblade").visual
	elif kind == 2:
		data = GameDB.enemy(&"ash_hound").visual
	var visual := EntityVisual.new()
	visual.z_index = 3
	visual.occlusion = _occlusion if occluded else null
	add_child(visual)
	visual.setup(data)
	return visual


func _clear() -> void:
	for actor: EntityVisual in _actors:
		actor.queue_free()
	_actors.clear()


func _run_shots() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	for shot: Dictionary in SHOTS:
		for occluded: bool in [true, false]:
			if not occluded and not str(shot["name"]).contains("derriere"):
				continue
			_clear()
			_camera.position = _world(shot["center"])
			for item: Array in shot["actors"]:
				var actor: EntityVisual = _visual(int(item[0]), occluded)
				actor.position = _world(item[1])
				actor.set_facing_left(bool(item[2]), true)
				_actors.append(actor)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			var path: String = _out.path_join("%s%s.png" % [shot["name"], "" if occluded else "_sans_masquage"])
			image.save_png(path)
			print("Capture : ", path)
	get_tree().quit()


## Horde animée à l'écran (cas le plus coûteux : tous les sprites dessinés et testés), avec puis sans masquage.
func _run_bench() -> void:
	_camera.position = _world([1300, 4400])
	var view: Vector2 = get_viewport_rect().size / _camera.zoom
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var results: Array[String] = []
	for occluded: bool in [false, true, false, true, false, true]:
		_clear()
		for i: int in _bench:
			var actor: EntityVisual = _visual(2 if i % 4 != 0 else 1, occluded)
			actor.position = _camera.position + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * view
			_actors.append(actor)
		for i: int in 30:
			await get_tree().process_frame
		var start: int = Time.get_ticks_usec()
		var calls: float = 0.0
		var t: float = 0.0
		for frame: int in BENCH_FRAMES:
			t += 1.0 / 60.0
			for k: int in _actors.size():
				var actor: EntityVisual = _actors[k]
				actor.position += Vector2(cos(t + k), sin(t * 0.7 + k)) * 1.5
				actor.tick(1.0 / 60.0, true, 90.0)
			await get_tree().process_frame
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var ms: float = (Time.get_ticks_usec() - start) / 1000.0 / BENCH_FRAMES
		results.append("%s : %.2f ms par image, %.0f appels de dessin" % ["avec masquage" if occluded else "sans masquage",
			ms, calls / BENCH_FRAMES])
		print("Mesure %d entités, %s" % [_bench, results.back()])
	get_tree().quit()
