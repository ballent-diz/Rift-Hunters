extends TestCase
## Brique B2 « nuit et lucioles » et gardien de fin de carte (docs/design/CARTES.md).

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start(arena_id: StringName, night: bool, boss_id: StringName = &"") -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = arena_id
	setup.starter_id = &"mossback"
	setup.autopilot = true
	var features: Array[String] = []
	if night:
		features.append("night")
	setup.arena_override = TestArena.build(arena_id, boss_id, features)
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func _spawn(ctx: RunContext, pos: Vector2) -> Enemy:
	var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(&"husk"), pos)
	ctx.enemies.rebuild_grid()
	return enemy


func test_day_maps_see_everything() -> void:
	var ctx: RunContext = _start(&"three_rifts", false)
	check(ctx.night == null and not ctx.enemies.visibility.is_valid(), "de jour, pas de voile ni de filtre")
	var far: Enemy = _spawn(ctx, ctx.player.global_position + Vector2(500, 0))
	check_eq(ctx.enemies.find_nearest(ctx.player.global_position, 800.0), far, "cible lointaine visible de jour")


func test_night_only_targets_lit_or_revealed_enemies() -> void:
	var ctx: RunContext = _start(&"three_rifts", true)
	check(ctx.night != null, "nuit active sur l'arène d'essai")
	var origin: Vector2 = ctx.player.global_position
	var dark: Enemy = _spawn(ctx, origin + Vector2(ctx.arena.light_radius + 120.0, 0))
	check(not ctx.night.is_lit(dark.position), "hors de la lumière du Chasseur")
	check(ctx.enemies.find_nearest(origin, 900.0) == null, "un ennemi dans le noir n'est pas ciblé")
	ctx.status_system.apply(dark, &"reveal", 1, &"glowmoth")
	check_eq(ctx.enemies.find_nearest(origin, 900.0), dark, "Révélé : il redevient une cible")
	var near: Enemy = _spawn(ctx, origin + Vector2(120, 0))
	check_eq(ctx.enemies.find_nearest(origin, 900.0), near, "dans la lumière du Chasseur : ciblé")
	check(ctx.enemies.query_radius(dark.position, 40.0).has(dark), "les zones touchent aussi les ennemis dans le noir")


func test_glades_light_and_reveal() -> void:
	var ctx: RunContext = _start(&"three_rifts", true)
	var glade: Vector2 = ctx.arena.firefly_glades[1]
	var enemy: Enemy = _spawn(ctx, glade + Vector2(40, 0))
	check(ctx.night.is_lit(enemy.position), "une clairière de lucioles éclaire")
	ctx.night.step(1.0)
	check(enemy.statuses.has(&"reveal"), "la clairière révèle les ennemis qui y passent")
	var lights: PackedVector4Array = ctx.night.lights()
	check(lights.size() <= NightDirector.MAX_LIGHTS, "nombre de lumières borné")
	check_near(lights[0].z, ctx.arena.light_radius, 0.01, "première lumière : le Chasseur")


func test_dangers_are_drawn_above_the_night() -> void:
	var ctx: RunContext = _start(&"three_rifts", true)
	check(ctx.hazards._hostile_layer.z_index + ctx.hazards.z_index > ctx.night.z_index, "télégraphes au-dessus du voile")
	check(ctx.night.get_index() > ctx.enemies.get_index(), "voile ajouté après les Corrompus (il les couvre)")
	check(ctx.night.get_index() < ctx.allies.get_index(), "Échos et Chasseur au-dessus du voile")


func test_guardian_spawns_as_a_map_boss() -> void:
	var ctx: RunContext = _start(&"fractured_plain", false, &"root_sentinel")
	var data: BossData = GameDB.boss(&"root_sentinel")
	check(data.guardian and data.phases.size() == 1, "gardien en une phase")
	ctx.time = ctx.arena.boss_time
	run.spawner.step(0.1)
	check(ctx.boss != null and ctx.boss.boss_data == data, "la Sentinelle des Racines apparaît")
	check_near(ctx.boss.visual.scale.x, data.visual_scale, 0.01, "sprite d'élite agrandi")
	check(ctx.boss.visual.has_sheet(), "sprite final réutilisé")
	for i: int in 300:
		ctx.time += 0.05
		run.boss_controller.step(0.05)
		ctx.hazards.step(0.05)
	check(ctx.boss.alive, "le gardien attaque sans erreur pendant 15 s")
	var info: DamageInfo = RunFixture.info(1e9)
	ctx.combat.deal_damage(ctx.boss, info)
	check(not ctx.boss.alive, "le gardien peut être vaincu")


func test_mist_chimera_steps_through_the_mist() -> void:
	var ctx: RunContext = _start(&"fractured_plain", false, &"mist_chimera")
	ctx.time = ctx.arena.boss_time
	run.spawner.step(0.1)
	check(ctx.boss != null and ctx.boss.boss_data.id == &"mist_chimera", "la Chimère des Brumes apparaît")
	ctx.boss.position = ctx.player.global_position + Vector2(1500, 0)
	var blink: BossPatternData = null
	for pattern: BossPatternData in ctx.boss.boss_data.phases[0].patterns:
		if pattern.kind == &"blink":
			blink = pattern
	run.boss_controller._pattern_blink(blink)
	check(not ctx.boss.visual.visible and ctx.boss.invulnerable_time > 0.0, "dissoute dans la brume, intouchable")
	for i: int in 30:
		ctx.time += 0.05
		run.boss_controller.step(0.05)
	check(ctx.boss.visual.visible, "elle réapparaît")
	check(ctx.boss.position.distance_to(ctx.player.global_position) < 400.0, "près du Chasseur, depuis l'autre bout")
	for i: int in 300:
		ctx.time += 0.05
		run.boss_controller.step(0.05)
		ctx.hazards.step(0.05)
	check(ctx.boss.alive, "le gardien attaque sans erreur pendant 15 s")
