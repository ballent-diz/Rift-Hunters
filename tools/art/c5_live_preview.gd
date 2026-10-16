extends Node
## Vraie partie C1 avec adaptateur VFX de test. Aucun fichier src/ ni règle de combat modifié.
## Reprend le bot, skip_profile et god_mode déjà utilisés par tools/screenshot.gd.
var run: RunController
var viewport: SubViewport
var recording := false
var impact_frame: int = -1
var impact_count := 0
var confirmed_hits := 0
var cleanup_only := false
var output := "res://docs/previews/c5/live"

func _ready() -> void:
	cleanup_only = "--cleanup-only" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920,1080)
	viewport.size_2d_override = Vector2i(1280,720)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var display := TextureRect.new()
	add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var setup: RunSetup = Profile.make_run_setup(&"mossback")
	setup.arena_id = &"fractured_plain"
	setup.autopilot = true
	setup.run_seed = 31
	run = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	run.start(setup)
	viewport.add_child(run)
	run.ctx.player.god_mode = true
	run.ctx.events.enemy_damaged.connect(_on_hit)
	run.ctx.events.spell_cast.connect(_on_cast)
	print("C5 en partie : scène run existante, bot et combat C1, HUD réel, seed 31")

func _on_hit(enemy: Enemy, info: DamageInfo, _amount: float) -> void:
	if info.source_kind != DamageInfo.SourceKind.PLAYER or not info.has_tag(DamageInfo.TAG_SPELL):
		return
	# C1 identifie ces dégâts par TAG_SPELL + Fracture ; adaptateur limité à ce pilote.
	var slash_hit := false
	for application: StatusApplication in info.statuses:
		if application.status_id == &"fracture":
			slash_hit = true
	if not slash_hit:
		return
	confirmed_hits += 1
	if impact_frame != Engine.get_physics_frames():
		impact_frame = Engine.get_physics_frames()
		impact_count = 0
	if impact_count >= 2:
		return
	impact_count += 1
	var effect: Node2D = load("res://assets/vfx/hunter/cleaving_slash/blade_impact.tscn").instantiate()
	effect.z_index = 5
	effect.set("visual_size",72.0)
	effect.modulate.a = .78
	run.ctx.world.add_child(effect)
	effect.global_position = enemy.global_position+Vector2(0,-12)
	effect.call("play",info.direction)

func _on_cast(id: StringName) -> void:
	if id != &"cleaving_slash":
		return
	# Remplace seulement le secteur de travail C1, sans retirer chiffres, particules ou autres effets.
	var shapes: Array[Dictionary] = run.ctx.fx.get("_shapes")
	for i: int in range(shapes.size()-1,-1,-1):
		if int(shapes[i].get("type",-1)) == 5:
			shapes.remove_at(i)
			break
	var effect: Node2D = load("res://assets/vfx/hunter/cleaving_slash/cleaving_slash.tscn").instantiate()
	effect.z_index = 5
	run.ctx.world.add_child(effect)
	effect.global_position = run.ctx.player.global_position+Vector2(0,-12)
	effect.modulate.a = .85
	effect.call("play_from",run.ctx.player.facing,&"base",.10)
	# Présentation du coup instantané : pose déjà au début du geste de frappe.
	var actor: AnimatedSprite2D = run.ctx.player.visual.get("_anim")
	if actor != null:
		actor.frame = 3
	if cleanup_only and not recording:
		recording = true
		_cleanup.call_deferred()
		return
	if run.ctx.time >= 25.0 and confirmed_hits > 0 and not recording:
		recording = true
		_capture.call_deferred()

func _capture() -> void:
	print("C5 capture en partie à ",run.ctx.time," s, ennemis : ",run.ctx.enemies.count())
	for frame: int in 75:
		await RenderingServer.frame_post_draw
		var shot: Image = viewport.get_texture().get_image()
		shot.save_png(output+"/frame_%03d.png" % frame)
		if frame == 0:
			shot.save_png(output+"/impact.png")
		elif frame == 8:
			shot.save_png(output+"/lisibilite.png")
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	print("C5 en partie : 75 images, aucune retouche, contacts confirmés : ",confirmed_hits)
	await _cleanup()

func _cleanup() -> void:
	run.set_physics_process(false)
	# Les services RefCounted de la partie conservent le contexte ; rompre ces cycles au démontage du banc.
	run.ctx.spawner = null
	run.ctx.status_system = null
	run.ctx.zones = null
	run.spawner = null
	run.event_director = null
	run.boss_controller = null
	run.queue_free()
	run = null
	await get_tree().process_frame
	await get_tree().process_frame
	print("C5 : partie de test libérée")
	get_tree().quit()

func _physics_process(_delta: float) -> void:
	if run != null and run.ctx.time > 100.0 and not recording:
		push_error("Aucun contact de Taille fendante capturable en 100 secondes.")
		get_tree().quit(1)
