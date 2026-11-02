extends TestCase
## Chapitre 4, le Glacier silencieux (docs/design/MONSTRES.md) : prison de glace, silence, écho des sorts, avalanche,
## piétinement du Mammouth, froid et braseros (brique B7), Nivorath et son écho des sorts.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start(configure: Callable = Callable()) -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"fractured_plain"
	setup.starter_id = &"ashblade"
	setup.run_seed = 4
	setup.autopilot = true
	var arena: ArenaData = GameDB.arena(&"fractured_plain").duplicate()
	if configure.is_valid():
		configure.call(arena)
	setup.arena_override = arena
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func _technique(enemy_id: StringName, kind: StringName) -> EnemyTechniqueData:
	for technique: EnemyTechniqueData in GameDB.enemy(enemy_id).techniques:
		if technique.kind == kind:
			return technique
	return null


func _tick(ctx: RunContext, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		ctx.time += 0.05
		ctx.enemies._step_pending_actions()
		ctx.frost.step(0.05)
		if ctx.cold:
			ctx.cold.step(0.05)
		t += 0.05


func test_fourteen_monsters_and_their_techniques() -> void:
	for id: StringName in [&"frost_crawler", &"blizzard_wolf", &"snow_wraith", &"ice_golem", &"frost_shaman", &"peak_yeti",
			&"rime_archer", &"hush_shard", &"ice_knight", &"frozen_sentry", &"icebreaker", &"silence_herald",
			&"frost_mammoth", &"snow_witch"]:
		var data: EnemyData = GameDB.enemy(id)
		check(data != null, "%s : fiche" % id)
		for technique: EnemyTechniqueData in data.techniques:
			var kind: String = String(technique.kind)
			var known: bool = run_has_technique(kind)
			check(known, "%s : technique %s codée" % [id, kind])
	check(GameDB.enemy(&"snow_wraith").flying and GameDB.enemy(&"hush_shard").flying, "deux volants")
	check(GameDB.enemy(&"rime_archer").stealth_range > 0.0, "l'Archère est furtive")


func run_has_technique(kind: String) -> bool:
	var manager := EnemyManager.new()
	var frost := FrostTechniques.new()
	var marsh := MarshTechniques.new(null, manager)
	var found: bool = manager.has_method("_technique_" + kind) or frost.has_method("technique_" + kind) \
		or marsh.has_method("technique_" + kind)
	manager.free()
	frost.free()
	return found


func test_ice_prison_holds_until_a_dash() -> void:
	var ctx: RunContext = _start()
	var shaman: Enemy = ctx.enemies.spawn(GameDB.enemy(&"frost_shaman"), ctx.player.global_position + Vector2(300, 0))
	var technique: EnemyTechniqueData = _technique(&"frost_shaman", &"ice_prison")
	ctx.frost.technique_ice_prison(shaman, technique, ctx.player.global_position)
	_tick(ctx, technique.telegraph + 0.1)
	check(ctx.frost.imprisoned() and ctx.player.is_hindered(), "le Chasseur resté dans le cercle est figé")
	ctx.player._dash_time = 0.2
	_tick(ctx, 0.05)
	check(not ctx.frost.imprisoned() and not ctx.player.is_hindered(), "la Ruée brise la glace")


func test_hush_blocks_spells_inside_the_circle() -> void:
	var ctx: RunContext = _start()
	var herald: Enemy = ctx.enemies.spawn(GameDB.enemy(&"silence_herald"), ctx.player.global_position + Vector2(150, 0))
	var technique: EnemyTechniqueData = _technique(&"silence_herald", &"hush")
	check(ctx.frost.technique_hush(herald, technique, ctx.player.global_position), "le Héraut déploie le silence")
	_tick(ctx, technique.telegraph + 0.1)
	check(ctx.frost.silenced(ctx.player.global_position), "le Chasseur est dans le silence")
	check(not ctx.spells.cast(0, ctx.player.global_position + Vector2(100, 0)), "ses sorts ne partent pas")
	check(not ctx.frost.silenced(herald.position + Vector2(900, 0)), "hors du cercle, plus de silence")


func test_spell_echo_needs_a_recent_spell() -> void:
	var ctx: RunContext = _start()
	var herald: Enemy = ctx.enemies.spawn(GameDB.enemy(&"silence_herald"), ctx.player.global_position + Vector2(300, 0))
	var technique: EnemyTechniqueData = _technique(&"silence_herald", &"spell_echo")
	check(not ctx.frost.technique_spell_echo(herald, technique, ctx.player.global_position), "rien à renvoyer")
	ctx.events.spell_cast.emit(&"cleaving_slash")
	check(ctx.frost.technique_spell_echo(herald, technique, ctx.player.global_position), "il renvoie le dernier sort")


func test_avalanche_rolls_and_grows() -> void:
	var ctx: RunContext = _start()
	ctx.player.global_position = Vector2.ZERO
	var yeti: Enemy = ctx.enemies.spawn(GameDB.enemy(&"peak_yeti"), Vector2(500, 0))
	var technique: EnemyTechniqueData = _technique(&"peak_yeti", &"avalanche")
	ctx.frost.technique_avalanche(yeti, technique, ctx.player.global_position)
	ctx.time += technique.telegraph + 0.01
	ctx.enemies._step_pending_actions()
	check_eq(ctx.frost.snowballs.size(), 1, "une boule de neige roule")
	var start: float = ctx.frost.snowballs[0]["radius"]
	_tick(ctx, 0.5)
	check(ctx.frost.snowballs.is_empty() or float(ctx.frost.snowballs[0]["radius"]) > start, "elle grossit en roulant")


func test_trample_exposes_the_mammoth() -> void:
	var ctx: RunContext = _start()
	var mammoth: Enemy = ctx.enemies.spawn(GameDB.enemy(&"frost_mammoth"), ctx.player.global_position + Vector2(400, 0))
	var technique: EnemyTechniqueData = _technique(&"frost_mammoth", &"trample")
	ctx.frost.technique_trample(mammoth, technique, ctx.player.global_position)
	_tick(ctx, technique.telegraph + float(technique.params["duration"]) + 0.1)
	check(mammoth.extra_damage_taken > 1.0, "après la charge, son armure éclate")
	_tick(ctx, float(technique.params["expose"]) + 0.1)
	check_eq(mammoth.extra_damage_taken, 1.0, "puis elle se referme")


func test_cold_rises_away_from_braziers_and_braziers_warm() -> void:
	var ctx: RunContext = _start(func(arena: ArenaData) -> void:
		arena.cold_rate = 50.0
		arena.cold_recover = 50.0
		arena.braziers = [Vector2(2000, 0)])
	check(ctx.cold != null, "froid actif")
	_tick(ctx, 2.2)
	check(ctx.cold.full(), "loin des braseros, la jauge se remplit")
	_tick(ctx, 0.6)
	check(ctx.stats.get_value(&"cold_ticks") >= 1.0 and ctx.player.is_hindered(), "jauge pleine : il gèle")
	ctx.player.global_position = Vector2(2000, 0)
	_tick(ctx, 1.0)
	check(ctx.cold.cold < 100.0, "près d'un brasero allumé, il se réchauffe")
	ctx.cold.snuff(0)
	check(not ctx.cold.warm(Vector2(2000, 0)), "un brasero soufflé ne chauffe plus")
	ctx.time += ctx.arena.brazier_relight + 0.1
	check(ctx.cold.warm(Vector2(2000, 0)), "puis il se rallume")


func test_nivorath_captures_spells_or_chokes() -> void:
	var ctx: RunContext = _start()
	var data: BossData = GameDB.boss(&"nivorath")
	check_eq(data.phases.size(), 3, "trois phases")
	check_eq(data.signature, &"spell_capture", "mécanique phare : l'écho des sorts")
	var boss: Enemy = ctx.enemies.spawn_boss(data, ctx.player.global_position + Vector2(400, 0))
	var brain := BossController.new(ctx, boss)
	var pattern: BossPatternData = null
	for p: BossPatternData in data.phases[1].patterns:
		if p.kind == &"spell_capture":
			pattern = p
	brain._pattern_spell_capture(pattern)
	var mechanics: NivorathMechanics = brain.nivorath()
	ctx.time += pattern.telegraph + 0.1
	check(mechanics.capturing(), "gueule ouverte")
	check(ctx.boss_hold_spells(), "le bot retient ses sorts")
	ctx.time += float(pattern.params["duration"]) + 0.1
	mechanics.step(0.05)
	check(brain.stunned_time > 0.0 and brain.heart_time > 0.0, "sans sort à renvoyer, il s'étouffe")
	brain._pattern_spell_capture(pattern)
	ctx.time += pattern.telegraph + 0.1
	ctx.events.spell_cast.emit(&"prismatic_lance")
	check_eq(int(mechanics.capture["count"]), 1, "le sort lancé est aspiré")
	var tags: Array[StringName] = [DamageInfo.TAG_SPELL]
	check_eq(ctx.combat.deal_damage(boss, DamageInfo.make(100.0, DamageInfo.SourceKind.PLAYER, &"player", tags)), 0.0,
		"il ne blesse pas Nivorath")
