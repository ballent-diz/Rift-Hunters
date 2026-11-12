extends Node
## Banc visuel reproductible : vrais lancers dans une partie figée, sans écrire dans le profil.
## godot --path . tools/art/spell_vfx_preview.tscn -- --out=/tmp/spell-vfx
## Les PNG intermédiaires restent hors dépôt ; assembler seulement les aperçus retenus.

const FPS := 12.0
const FRAMES := 36
const CASES := [
	["ash_dance", "ashblade", "echo", "", "Danse des cendres — cibles réelles"],
	["gravity_well", "mossback", "echo", "", "Puits de gravité — animation raccordée"],
	["ion_storm", "voltwisp", "echo", "", "Tempête ionique — impacts sur les cibles"],
	["reflection", "mirrorling", "echo", "", "Reflet — bouclier du Chasseur"],
	["soot_web", "ashen_widow", "enemy", "web", "Veuve de cendre — Toile de suie / PixelFX"],
	["frost_arrow", "rime_archer", "enemy", "web", "Archère du givre — Flèche glaçante / PixelFX"],
	["floe_quake", "floe_colossus", "boss", "floe_quake", "Colosse de banquise — fracture / PixelFX"],
	["rune_barrage", "sanctum_golem", "boss", "rune_barrage", "Golem du sanctuaire — runes / PixelFX"],
	["void_breath", "abyssarch", "boss", "breath", "Abyssarque — souffle de Faille / PixelFX"],
]

var out := "/tmp/spell-vfx"
var only := ""
var run: RunController
var brain: BossController
var records: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_capture")


func _capture() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	Profile.read_only = true
	AudioServer.set_bus_mute(0, true)
	TranslationServer.set_locale("fr")
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().paused = true
	for spec: Array in CASES:
		if only == "" or spec[0] in only.split(","):
			await _case(spec)
	var filename: String = "verification.json" if only == "" else "verification_" + only + ".json"
	var receipt := FileAccess.open(out.path_join(filename), FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"godot": Engine.get_version_info(), "fps": FPS,
		"scene": "res://scenes/run.tscn", "arena": "survival_ruins", "cases": records}, "\t") + "\n")
	get_tree().paused = false
	get_tree().quit(0)


func _case(spec: Array) -> void:
	var folder: String = out.path_join(spec[0])
	DirAccess.make_dir_recursive_absolute(folder)
	var setup := RunSetup.new()
	setup.arena_id = &"survival_ruins"
	setup.starter_id = StringName(spec[1]) if spec[2] == "echo" else &"mossback"
	setup.run_seed = 20261112
	run = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	run.process_mode = Node.PROCESS_MODE_PAUSABLE
	run.start(setup)
	add_child(run)
	run.set_physics_process(false)
	run.hud.visible = false
	var ctx: RunContext = run.ctx
	# Le terrain est celui du jeu ; seuls les obstacles sont retirés pour stabiliser les cibles du banc.
	ctx.obstacles = ObstacleField.new()
	ctx.flow = null
	var center := Vector2(2600, 840) - ctx.arena.size * 0.5
	ctx.player.position = center + Vector2(-180, 130)
	ctx.player.god_mode = true
	run.camera.position_smoothing_enabled = false
	run.camera.global_position = center
	run.camera.reset_smoothing()
	var ally: Ally = ctx.allies.team[0]
	ally.position = center + Vector2(-200, -20)
	ctx.pixel_fx._active.clear()
	brain = null
	if spec[2] == "echo":
		for offset: Vector2 in [Vector2(80, 0), Vector2(170, 30), Vector2(130, -70)]:
			var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(&"husk"), center + offset)
			enemy.hp = 10000.0
			enemy.max_hp = enemy.hp
		ctx.enemies.rebuild_grid()
		assert(Techniques.cast(ally, ctx, center + Vector2(100, 0)))
	elif spec[2] == "enemy":
		var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(StringName(spec[1])), center + Vector2(140, -60))
		for tech: EnemyTechniqueData in enemy.data.techniques:
			if tech.kind == StringName(spec[3]):
				assert(ctx.enemies._run_technique(enemy, tech, ctx.player.position))
				enemy.visual.play_action(&"attack")
	else:
		var boss: Enemy = ctx.enemies.spawn_boss(GameDB.boss(StringName(spec[1])), center + Vector2(140, -80))
		brain = BossController.new(ctx, boss)
		var pattern: BossPatternData
		for phase: BossPhaseData in boss.boss_data.phases:
			for candidate: BossPatternData in phase.patterns:
				if candidate.kind == StringName(spec[3]):
					pattern = candidate
		assert(pattern != null)
		brain.call("_pattern_" + spec[3], pattern)
		ctx.pixel_fx.technique(boss, pattern.kind, pattern.params)
		boss.visual.play_action(StringName(BossController.PATTERN_ANIMATIONS.get(pattern.kind, &"attack")))
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var title := Label.new()
	title.text = spec[4]
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_outline_size", 5)
	canvas.add_child(title)
	var peak: int = 0
	for frame: int in FRAMES:
		var delta: float = 1.0 / FPS
		ctx.time += delta
		if brain:
			brain._run_scheduled()
		ctx.enemies._step_pending_actions()
		ctx.hazards.step(delta)
		ctx.projectiles.step(delta)
		ctx.combat.flush_queue()
		ctx.pixel_fx.step(delta)
		ctx.fx.step(delta)
		for effect: Node in ctx.allies.vfx.layer.get_children():
			if not effect.is_queued_for_deletion():
				effect.call("_process", delta)
		ctx.allies.vfx.layer.call("_process", delta)
		peak = maxi(peak, ctx.pixel_fx.active_count())
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(folder.path_join("%03d.png" % frame)) == OK)
	records.append({"id": spec[0], "source": spec[1], "kind": spec[3], "frames": FRAMES,
		"peak_pixel_fx": peak, "player_present": true, "enemies": ctx.enemies.count()})
	print("VFX_CAPTURE_OK ", spec[0], " peak=", peak)
	canvas.queue_free()
	brain = null
	run.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	run = null
