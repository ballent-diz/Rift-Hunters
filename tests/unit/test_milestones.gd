extends TestCase
## Séparation des modes (docs/design/MODES.md) : la campagne progresse par jalons (pas d'XP, un choix par jalon,
## sans petites caractéristiques), le mode survie garde l'XP et les montées de niveau.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start(arena_id: StringName) -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = arena_id
	setup.starter_id = &"mossback"
	setup.autopilot = true
	setup.run_seed = 3
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func _kill(ctx: RunContext, pos: Vector2) -> void:
	var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(&"husk"), pos)
	ctx.combat.deal_damage(enemy, RunFixture.info(1e9))
	ctx.combat.flush_queue()
	ctx.enemies.step(0.0)


func test_campaign_maps_use_milestones_and_survival_keeps_levels() -> void:
	for id: StringName in [&"three_rifts", &"storm_highlands", &"firefly_woods", &"mist_ford"]:
		check_eq(GameDB.arena(id).progression, &"milestones", "%s : progression par jalons" % id)
	check_eq(GameDB.arena(&"fractured_plain").progression, &"levels", "Plaine fracturée : mode survie")


func test_no_xp_in_campaign() -> void:
	var ctx: RunContext = _start(&"three_rifts")
	var gems: int = ctx.pickups.items.size()
	_kill(ctx, ctx.player.global_position + Vector2(200, 0))
	check_eq(ctx.pickups.items.size(), gems, "un Corrompu tué ne laisse pas d'XP en campagne")


func test_survival_still_drops_xp() -> void:
	var ctx: RunContext = _start(&"fractured_plain")
	var gems: int = ctx.pickups.items.size()
	_kill(ctx, ctx.player.global_position + Vector2(200, 0))
	check(ctx.pickups.items.size() > gems, "mode survie : l'XP tombe toujours")


func test_milestone_grants_a_choice_without_small_stats() -> void:
	enable_features([&"relics"])
	var ctx: RunContext = _start(&"three_rifts")
	ctx.events.milestone_reached.emit()
	check_eq(ctx.player.pending_levels, 1, "un jalon : un choix")
	check(run.release_choices, "le choix s'ouvre aussitôt")
	var relics: int = 0
	for i: int in 10:
		for offer: UpgradeOffer in UpgradeOffers.candidates(ctx):
			check(offer.kind != UpgradeOffer.Kind.STAT, "pas de petite caractéristique en campagne (%s)" % offer.key)
			relics += 1 if offer.kind == UpgradeOffer.Kind.RELIC else 0
	check(relics > 0, "des reliques parmi les choix de jalon")
	for offer: UpgradeOffer in UpgradeOffers.candidates(ctx):
		if offer.kind == UpgradeOffer.Kind.RELIC:
			UpgradeOffers.apply(ctx, offer)
			check(ctx.build.relics.has(offer.relic.id), "la relique choisie est gagnée")
			break


func test_zone_wave_end_is_a_milestone() -> void:
	var ctx: RunContext = _start(&"three_rifts")
	var before: int = ctx.player.pending_levels
	ctx.zones._end_wave()
	check_eq(ctx.player.pending_levels, before + 1, "fin de vague : un choix")
