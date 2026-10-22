extends Node
## Contrôle graphique de Pyrevorn dans une partie gelée. Aucun combat ajouté.
const OUT := "res://docs/previews/pyrevorn/"
const IDS: Array[StringName] = [&"boss.pyrevorn"]
const TECHNIQUES: Array[StringName] = [
 &"idle", &"claws", &"magma_breath", &"crater_rain", &"brood_call", &"transform", &"death",
 &"phase2_idle", &"skyfall", &"rift_eye",
]
var _viewport: SubViewport
var _run: RunController


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	get_window().mode = Window.MODE_MINIMIZED
	AudioServer.set_bus_mute(0, true)
	Profile.read_only = true
	for id: StringName in IDS:
		if Assets.get_sprite_frames(id) == null:
			push_error("Texture non importée : " + String(id))
			get_tree().quit(1)
			return
	DirAccess.make_dir_recursive_absolute(OUT)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var setup := RunSetup.new()
	setup.arena_id = &"three_rifts"
	setup.starter_id = &"mossback"
	setup.run_seed = 7
	_run = load("res://scenes/run.tscn").instantiate()
	_run.skip_profile = true
	_run.start(setup)
	_viewport.add_child(_run)
	get_tree().paused = true
	_run.set_physics_process(false)
	_run.hud.visible = false
	var center: Vector2 = _run.ctx.arena.finale_center
	_run.ctx.player.global_position = center + Vector2(0, 200)
	_run.ctx.allies.get_ally(&"mossback").global_position = center + Vector2(50, 200)
	_run.camera.position_smoothing_enabled = false
	_run.camera.global_position = center
	_run.camera.reset_smoothing()
	var sprites: Array[AnimatedSprite2D] = []
	for index: int in IDS.size():
		var offset := Vector2(0, 70)
		sprites.append(_sprite(IDS[index], center + offset))
	_sprite(&"boss.nebulorax", center + Vector2(-290, 70))
	await _save("pyrevorn_in_game.png")
	for name: StringName in TECHNIQUES:
		for sprite: AnimatedSprite2D in sprites:
			if sprite.sprite_frames.has_animation(name):
				sprite.animation = name
				sprite.frame = mini(3, sprite.sprite_frames.get_frame_count(name) - 1)
		await _save("technique_" + String(name) + ".png")
	get_tree().paused = false
	_run.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _sprite(id: StringName, point: Vector2) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = Assets.get_sprite_frames(id)
	sprite.centered = false
	sprite.offset = -Assets.anchor(id)
	sprite.scale = Vector2.ONE * Assets.pixel_scale(id)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = point
	sprite.animation = &"move"
	_run.add_child(sprite)
	return sprite


func _save(filename: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	_viewport.get_texture().get_image().save_png(OUT + filename)
	print("Capture : ", filename)
