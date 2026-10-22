extends Node
## Aperçu graphique dans une partie gelée. Aucune donnée de combat ajoutée.

const OUT := "res://docs/previews/chapter2-monsters/"
const IDS: Array[StringName] = [
	&"enemy.cinder_crawler", &"enemy.ash_hound", &"enemy.char_golem", &"enemy.smoke_wisp",
	&"enemy.pyre_brute", &"enemy.ashen_widow", &"enemy.cinder_knight", &"enemy.heath_runner",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(0, true)
	Profile.read_only = true
	DirAccess.make_dir_recursive_absolute(OUT)
	var setup := RunSetup.new()
	setup.arena_id = &"three_rifts"
	setup.starter_id = &"mossback"
	setup.run_seed = 7
	var run: RunController = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	run.start(setup)
	add_child(run)
	get_tree().paused = true
	run.set_physics_process(false)
	run.hud.visible = false
	run.camera.position_smoothing_enabled = false
	var center: Vector2 = run.ctx.arena.finale_center
	run.ctx.player.global_position = center + Vector2(0, 175)
	run.ctx.allies.get_ally(&"mossback").global_position = center + Vector2(50, 175)
	run.camera.global_position = center
	var sprites: Array[AnimatedSprite2D] = []
	for index: int in IDS.size():
		var pos := center + Vector2(-255 + (index % 4) * 170, -115 + (index / 4) * 190)
		sprites.append(_sprite(run, IDS[index], pos))
	run.camera.reset_smoothing()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "calcines_in_game.png")
	for sprite: AnimatedSprite2D in sprites:
		sprite.queue_free()
	await get_tree().process_frame
	var boss := _sprite(run, &"boss.source_devourer", center + Vector2(160, -30))
	for animation: StringName in [&"idle", &"heavy_slam", &"transform", &"phase2_attack"]:
		if not boss.sprite_frames.has_animation(animation):
			continue
		boss.play(animation)
		boss.frame = 3
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + "devourer_" + String(animation) + ".png")
	get_tree().paused = false
	run.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func _sprite(parent: Node, id: StringName, pos: Vector2) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = Assets.get_sprite_frames(id)
	sprite.centered = false
	sprite.offset = -Assets.anchor(id)
	sprite.scale = Vector2.ONE * Assets.pixel_scale(id)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = pos
	sprite.play(&"idle")
	parent.add_child(sprite)
	return sprite
