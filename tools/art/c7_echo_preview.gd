extends Node
## Vraie scène de partie, profil isolé et simulation gelée. Aucun branchement C7 fictif.
const Layer = preload("res://assets/vfx/echoes/effect_layer.gd")
const OUT := "res://docs/previews/c7-echos/"
var _center := Vector2.ZERO

var _viewport: SubViewport
var _run: RunController
var _layer: Node2D
var _sprite: AnimatedSprite2D
var _catalog: Array
var _metrics: Dictionary = {}


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	Profile.read_only = true
	TranslationServer.set_locale("fr")
	DirAccess.make_dir_recursive_absolute(OUT)
	_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/echoes/catalog.json"))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var setup := RunSetup.new()
	setup.arena_id = &"three_rifts"
	setup.starter_id = &"mossback"
	_run = load("res://scenes/run.tscn").instantiate()
	_run.skip_profile = true
	_run.start(setup)
	_viewport.add_child(_run)
	_run.set_physics_process(false)
	await get_tree().process_frame
	_center = _run.ctx.arena.finale_center
	_run.ctx.player.position = _center + Vector2(-150, 45)
	for ally: Ally in _run.ctx.allies.team:
		ally.position = _center + Vector2(-180, 80)
	_run.camera.position_smoothing_enabled = false
	_run.camera.global_position = _center
	_run.camera.reset_smoothing()
	for i: int in 90:
		var a: float = i * 2.39996
		var pos: Vector2 = _center + Vector2.from_angle(a) * (155 + (i % 6) * 35)
		_run.ctx.enemies.spawn(GameDB.enemy(&"skitterling"), pos)
	for child: Node in _run.ctx.world.get_children():
		if child is ZoneOverlay:
			(child as ZoneOverlay).hide()
	await get_tree().create_timer(3.0).timeout
	_layer = Layer.new()
	_layer.z_index = 1
	_run.ctx.world.add_child(_layer)
	_sprite = AnimatedSprite2D.new()
	_sprite.z_index = 3
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	_sprite.position = _center + Vector2(-85, 25)
	_run.ctx.world.add_child(_sprite)
	for spec: Dictionary in _catalog:
		if "--metrics-only" in OS.get_cmdline_user_args():
			await _benchmark(spec)
		else:
			await _echo(spec)
	var file := FileAccess.open(OUT + "performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_metrics, "\t") + "\n")
	print("C5-bis : neuf captures, dix-huit séquences et mesures natives enregistrées.")
	_run.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _echo(spec: Dictionary) -> void:
	var id := StringName("monster." + spec.id)
	_sprite.sprite_frames = Assets.get_sprite_frames(id)
	_sprite.offset = -Assets.anchor(id)
	_sprite.scale = Vector2.ONE * Assets.pixel_scale(id)
	_sprite.animation = &"technique"
	_sprite.frame = 3
	_clear()
	var attack: Node2D = _effect(spec.id, "attack", _sprite.position, 0.25)
	attack.set("travel_distance", 140.0)
	_effect(spec.id, "status", _center + Vector2(75, -40), 0.7)
	_effect(spec.id, spec.base, _center + Vector2(55, 30), 0.65)
	await _save(OUT + spec.id + ".png")
	for spell: String in [spec.base, spec.alt]:
		_clear()
		var effect: Node2D = _effect(spec.id, spell, _center + Vector2(40, 30), 0.0)
		if spell == "wandering_flame":
			var offsets := PackedVector2Array()
			for i: int in 3:
				offsets.append(effect.to_local(_run.ctx.enemies.list[i].global_position))
			effect.call("set_secondary_offsets", offsets)
		if spell == "healing_grove":
			var offsets := PackedVector2Array([effect.to_local(_run.ctx.player.global_position)])
			for ally: Ally in _run.ctx.allies.team:
				offsets.append(effect.to_local(ally.global_position))
			effect.call("set_secondary_offsets", offsets)
		var shape: StringName = effect.get("target_shape")
		var indicator: Node2D = _effect(spec.id, "indicator", effect.position, 0.4)
		indicator.set("target_shape", shape)
		indicator.call("seek_visual", 0.4)
		for i: int in 20:
			effect.call("seek_visual", i / 19.0 * float(effect.call("duration")))
			indicator.visible = i < 3
			_sprite.animation = &"technique"
			_sprite.frame = mini(7, i / 3)
			var folder: String = OS.get_environment("C7_FRAME_DIR")
			if not folder.is_empty():
				DirAccess.make_dir_recursive_absolute(folder)
				await _save(folder.path_join("%s_%s_%02d.png" % [spec.id, spell, i]))
	await _benchmark(spec)


func _effect(id: String, kind: String, pos: Vector2, time: float) -> Node2D:
	var effect: Node2D = load("res://assets/vfx/echoes/%s/%s.tscn" % [id, kind]).instantiate()
	_layer.add_child(effect)
	effect.position = pos
	effect.set("destroy_on_finish", false)
	effect.call("play", Vector2.RIGHT)
	effect.call("seek_visual", time)
	return effect


func _clear() -> void:
	for node: Node in _layer.get_children():
		_layer.remove_child(node)
		node.queue_free()


func _save(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(path)


func _benchmark(spec: Dictionary) -> void:
	_clear()
	# Cas chargé : plafond commun de 24 émetteurs, 18 particules dessinées chacun au maximum.
	for i: int in 24:
		var kind: String = spec.base if i % 2 == 0 else spec.alt
		var scene: PackedScene = load("res://assets/vfx/echoes/%s/%s.tscn" % [spec.id, kind])
		var effect: Node2D = _layer.emit_effect(scene,
			_center + Vector2.from_angle(i * 2.39996) * (i % 4) * 40, Vector2.RIGHT)
		effect.set("destroy_on_finish", false)
		effect.call("seek_visual", 0.5)
	var result: Dictionary = {"corrupted": 90, "emitters": 24, "particle_budget_per_emitter": 4,
		"adaptive_detail": true,
		"note": "Comparaison locale du rendu ; vraie partie gelée, pas un benchmark de l'IA."}
	for enabled: bool in [false, true]:
		_layer.visible = enabled
		for i: int in 20:
			await get_tree().process_frame
		var samples: Array[float] = []
		var previous: int = Time.get_ticks_usec()
		for i: int in 60:
			if enabled:
				for effect: Node2D in _layer.get_children():
					effect.call("seek_visual", (0.2 + fmod(i * 0.017, 0.6)) * float(effect.call("duration")))
			await get_tree().process_frame
			var current: int = Time.get_ticks_usec()
			samples.append((current - previous) / 1000.0)
			previous = current
		samples.sort()
		result["effects_on" if enabled else "effects_off"] = {
			"median_frame_ms": samples[30], "p95_frame_ms": samples[57], "samples": 60}
	_layer.visible = true
	_metrics[spec.id] = result
