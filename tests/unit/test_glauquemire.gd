extends TestCase
## Glauquemire, Dévoreur du chapitre 3 (docs/design/DEVOREUR_CHAPITRE3.md) : vase qui durcit, racine-laisse, sangsues,
## carapace à facettes, miroirs à orienter (mécanique phare), tourbillon, anneau de marée, engloutissement d'un Écho.

var run: RunController
var ctx: RunContext
var boss: Enemy
var brain: BossController
var marsh: GlauquemireMechanics


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _fight(offset := Vector2(400, 0)) -> void:
	run = RunFixture.create(host, &"ashblade")
	ctx = run.ctx
	boss = ctx.enemies.spawn_boss(GameDB.boss(&"glauquemire"), ctx.player.global_position + offset)
	brain = BossController.new(ctx, boss)
	marsh = brain.marsh()


func _pattern(kind: StringName, phase: int = 0) -> BossPatternData:
	for pattern: BossPatternData in GameDB.boss(&"glauquemire").phases[phase].patterns:
		if pattern.kind == kind:
			return pattern
	return null


func _phase(index: int) -> void:
	brain.phase_index = index
	marsh.on_phase(index, brain.phase())


func _tick(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		ctx.time += 0.05
		brain._run_scheduled()
		marsh.step(0.05)
		ctx.hazards.step(0.05)
		t += 0.05


func _dash(dir: Vector2) -> void:
	ctx.player._dash_time = 0.2
	ctx.player._dash_dir = dir.normalized()
	ctx.stats.add(&"dashes")


func test_three_phases_with_new_mechanics() -> void:
	var data: BossData = GameDB.boss(&"glauquemire")
	check_eq(data.phases.size(), 3, "trois phases")
	check(_pattern(&"mud_wall") != null and _pattern(&"root_leash") != null and _pattern(&"leech_feed") != null,
		"phase 1 : vase, racine-laisse, sangsues")
	check(data.phases[1].mechanics.has(&"facets") and data.phases[1].mechanics.has(&"mirrors"), "phase 2 : facettes, miroirs")
	check(_pattern(&"prism_beam", 1) != null, "phase 2 : rayon de prisme")
	check(data.phases[2].mechanics.has(&"tide_ring"), "phase 3 : anneau de marée")
	check(_pattern(&"whirlpool", 2) != null and _pattern(&"swallow", 2) != null, "phase 3 : tourbillon, engloutissement")
	check(Assets.manifest.has("boss.glauquemire"), "déclaré au manifeste (sprites à venir)")


func test_mud_hardens_into_walls() -> void:
	_fight()
	var pattern: BossPatternData = _pattern(&"mud_wall")
	brain._pattern_mud_wall(pattern)
	_tick(pattern.telegraph + 0.1)
	check_eq(marsh.puddles.size(), int(pattern.params["count"]), "les jets laissent des flaques")
	var spot: Vector2 = marsh.puddles[0]["pos"]
	ctx.player.global_position = spot
	_tick(0.1)
	check(ctx.player.is_hindered(), "la vase ralentit")
	_tick(float(pattern.params["harden"]))
	check_eq(marsh.wall_rects().size(), int(pattern.params["count"]), "la vase durcit en murs")
	check(ctx.obstacles.blocks(spot, 1.0), "le mur bloque le passage")
	check(not marsh.wall_rects()[0].has_point(ctx.player.global_position), "le Chasseur est repoussé hors du mur")
	_tick(float(pattern.params["wall_time"]) + 0.2)
	check(marsh.wall_rects().is_empty(), "les murs retombent")
	check(not ctx.obstacles.blocks(spot, 1.0), "et libèrent le passage")


func test_leash_holds_until_a_dash() -> void:
	_fight()
	var pattern: BossPatternData = _pattern(&"root_leash")
	brain._pattern_root_leash(pattern)
	_tick(pattern.telegraph + 0.05)
	check(marsh.leashed(), "le Chasseur est attaché")
	var anchor: Vector2 = marsh.leash["anchor"]
	ctx.player.global_position = anchor + Vector2(500, 0)
	_tick(0.05)
	check(ctx.player.global_position.distance_to(anchor) <= float(pattern.params["length"]) + 1.0, "la laisse retient")
	_dash(Vector2.LEFT)
	_tick(0.05)
	check(not marsh.leashed(), "la Ruée casse la racine")


func test_leeches_heal_when_they_reach_the_boss() -> void:
	_fight()
	var pattern: BossPatternData = _pattern(&"leech_feed")
	brain._pattern_leech_feed(pattern)
	_tick(pattern.telegraph + 0.1)
	check_eq(marsh.leeches.size(), int(pattern.params["count"]), "les sangsues arrivent")
	check(marsh.leeches[0].taunt_target == boss, "elles rampent vers le boss")
	boss.hp = boss.max_hp * 0.5
	marsh.leeches[0].position = boss.position
	_tick(0.05)
	check(boss.hp > boss.max_hp * 0.5, "une sangsue qui l'atteint le soigne")
	check(not marsh.leeches[0].alive, "et disparaît")


func test_facets_dampen_hits_by_side() -> void:
	_fight()
	_phase(1)
	check_eq(marsh.facets.size(), 4, "quatre faces")
	ctx.player.global_position = boss.position + Vector2(-300, 0)
	var side: int = marsh.side_of(ctx.player.global_position)
	var damped: float = ctx.combat.deal_damage(boss, RunFixture.info(100.0))
	marsh.facets[side] = 0.0
	var open: float = ctx.combat.deal_damage(boss, RunFixture.info(100.0))
	check(damped < open * 0.5, "une face intacte amortit le coup")
	ctx.player.global_position = boss.position + Vector2(0, 300)
	check(marsh.side_of(ctx.player.global_position) != side, "un autre côté a sa propre face")


func test_dash_turns_a_mirror_and_the_beam_comes_back() -> void:
	_fight()
	_phase(1)
	check_eq(marsh.mirrors.size(), 4, "quatre miroirs")
	var mirror: Dictionary = marsh.mirrors[0]
	var to_boss: Vector2 = boss.position - (mirror["pos"] as Vector2)
	ctx.player.global_position = mirror["pos"]
	_dash(to_boss)
	_tick(0.05)
	check(absf((mirror["arrow"] as Vector2).angle_to(to_boss)) < deg_to_rad(23.0), "le miroir se tourne dans le sens de la Ruée")
	ctx.player._dash_time = 0.0
	ctx.player.global_position = boss.position + Vector2(0, 500)
	var traced: Dictionary = marsh.trace(boss.position, -to_boss.normalized(), 1100.0)
	check(bool(traced["returned"]), "le rayon qui frappe le miroir revient sur le boss")
	var pattern: BossPatternData = _pattern(&"prism_beam", 1)
	brain._pattern_prism_beam(pattern)
	check(absf((mirror["arrow"] as Vector2).angle_to(to_boss)) > deg_to_rad(30.0), "le boss trouble les miroirs")
	mirror["arrow"] = to_boss.normalized()
	marsh.beam["angle"] = (-to_boss).angle()
	marsh.beam["start"] = ctx.time
	marsh.beam["arc"] = 0.0
	boss.invulnerable_time = 0.0
	var hp: float = boss.hp
	_tick(0.1)
	check(marsh.facets.all(func(f: float) -> bool: return f <= 0.0), "la carapace vole en éclats")
	check(brain.stunned_time > 0.0 and brain.heart_time > 0.0, "le boss est étourdi et vulnérable")
	check(boss.hp < hp, "le rayon renvoyé le blesse")


func test_beam_is_stopped_by_hardened_mud() -> void:
	_fight()
	marsh.mirrors.clear()
	var target: Vector2 = boss.position + Vector2(0, -300)
	marsh.puddles.append({"pos": target, "radius": 75.0, "harden_at": ctx.time, "crumble_at": ctx.time + 10.0, "wall": -1})
	_tick(0.05)
	var traced: Dictionary = marsh.trace(boss.position, Vector2.UP, 1100.0)
	var points: PackedVector2Array = traced["points"]
	check(points[points.size() - 1].distance_to(boss.position) < 300.0, "le mur de vase arrête le rayon")


func test_whirlpool_pulls_toward_the_boss() -> void:
	_fight(Vector2(500, 0))
	var pattern: BossPatternData = _pattern(&"whirlpool", 2)
	brain._pattern_whirlpool(pattern)
	_tick(pattern.telegraph + 0.05)
	var before: float = ctx.player.global_position.distance_to(boss.position)
	_tick(1.0)
	var after: float = ctx.player.global_position.distance_to(boss.position)
	check(after < before - 80.0, "le tourbillon aspire le Chasseur")


func test_tide_shrinks_and_hits_push_it_back() -> void:
	_fight()
	_phase(2)
	check(not marsh.tide.is_empty(), "la marée monte en phase 3")
	var start: float = marsh.tide["radius"]
	_tick(5.0)
	var shrunk: float = marsh.tide["radius"]
	check(shrunk < start - 50.0, "l'arène rétrécit")
	ctx.combat.deal_damage(boss, RunFixture.info(500.0))
	check(float(marsh.tide["radius"]) > shrunk, "un coup au boss fait reculer l'eau")
	ctx.player.global_position = marsh.tide["center"] + Vector2(float(marsh.tide["radius"]) + 200.0, 0)
	var hp: float = ctx.player.hp
	_tick(0.6)
	check(ctx.player.hp < hp, "l'eau blesse hors de l'anneau")


func test_swallowed_echo_is_freed_by_hitting_the_boss() -> void:
	_fight(Vector2(200, 0))
	var ally: Ally = ctx.allies.team[0]
	ally.global_position = boss.position + Vector2(-100, 0)
	var pattern: BossPatternData = _pattern(&"swallow", 2)
	brain._pattern_swallow(pattern)
	_tick(pattern.telegraph + 0.05)
	check(ally.swallowed and not ally.visible, "l'Écho est englouti")
	boss.invulnerable_time = 0.0
	for i: int in 20:
		ctx.combat.deal_damage(boss, RunFixture.info(400.0))
		if not ally.swallowed:
			break
	check(not ally.swallowed and ally.visible, "frapper le boss libère l'Écho")
	check(brain.stunned_time > 0.0, "le boss est sonné")


func test_swallowed_echo_comes_back_dazed_in_time() -> void:
	_fight(Vector2(200, 0))
	var ally: Ally = ctx.allies.team[0]
	ally.global_position = boss.position + Vector2(-100, 0)
	var pattern: BossPatternData = _pattern(&"swallow", 2)
	brain._pattern_swallow(pattern)
	_tick(pattern.telegraph + float(pattern.params["duration"]) + 0.2)
	check(not ally.swallowed, "l'Écho ressort de lui-même")
	check(ally.attack_cd > 1.0 and ally.technique_cd > 1.0, "sonné quelques secondes")
