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
		"phase 1 : vase, racine jaillissante, sangsues")
	check(data.phases[1].mechanics.has(&"facets") and data.phases[1].mechanics.has(&"mirrors"), "phase 2 : facettes, miroirs")
	check(_pattern(&"prism_beam", 1) != null, "phase 2 : rayon de prisme")
	check(_pattern(&"tide_wave", 2) != null and not data.phases[2].mechanics.has(&"tide_ring"),
		"phase 3 : raz-de-marée, plus d'anneau qui enferme")
	check(_pattern(&"mud_wall", 2) != null, "phase 3 : de la vase pour s'abriter des vagues")
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


func test_root_bursts_without_holding_the_hunter() -> void:
	_fight()
	var pattern: BossPatternData = _pattern(&"root_leash")
	var target: Vector2 = ctx.player.global_position
	brain._pattern_root_leash(pattern)
	_tick(pattern.telegraph + 0.05)
	check(not marsh.root.is_empty() and (marsh.root["anchor"] as Vector2).distance_to(target) < 1.0, "la racine vise le Chasseur")
	ctx.player.global_position = target + Vector2(500, 0)
	_tick(0.1)
	check(ctx.player.global_position.distance_to(target) > 499.0, "rien ne retient le Chasseur")
	var hp: float = ctx.player.hp
	_tick(float(pattern.params["slam_delay"]) + 0.2)
	check(marsh.root.is_empty() and is_equal_approx(ctx.player.hp, hp), "la racine jaillit, le Chasseur écarté est indemne")


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
	# Le soin total du combat est plafonné : le boss reste tuable même si toutes les sangsues passent.
	var cap: float = boss.max_hp * float(pattern.params["heal_cap"])
	for i: int in 40:
		var leech: Enemy = ctx.enemies.spawn(GameDB.enemy(&"mire_leech"), boss.position)
		marsh.leeches.append(leech)
		_tick(0.05)
	check(boss.hp <= boss.max_hp * 0.5 + cap + 0.01, "soin plafonné à %d %% des PV" % int(100.0 * float(pattern.params["heal_cap"])))


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


func test_held_mirror_sends_the_beam_back() -> void:
	_fight()
	_phase(1)
	check_eq(marsh.mirrors.size(), 4, "quatre miroirs")
	var mirror: Dictionary = marsh.mirrors[0]
	var to_boss: Vector2 = boss.position - (mirror["pos"] as Vector2)
	ctx.player.global_position = boss.position + Vector2(0, 700)
	_tick(0.05)
	var traced: Dictionary = marsh.trace(boss.position, -to_boss.normalized(), 1100.0)
	var points: PackedVector2Array = traced["points"]
	var stop: Vector2 = points[points.size() - 1]
	check(not bool(traced["returned"]) and stop.distance_to(mirror["pos"]) < GlauquemireMechanics.MIRROR_RADIUS + 1.0,
		"un miroir seul arrête le rayon")
	# Le Chasseur s'abrite derrière le miroir : il le tient, le rayon repart sur le boss.
	ctx.player.global_position = (mirror["pos"] as Vector2) - to_boss.normalized() * 60.0
	_tick(0.3)
	check(bool(mirror["held"]) and absf((mirror["arrow"] as Vector2).angle_to(to_boss)) < deg_to_rad(10.0),
		"le miroir tenu se tourne vers le boss")
	check(bool(marsh.trace(boss.position, -to_boss.normalized(), 1100.0)["returned"]), "le rayon revient sur le boss")
	var pattern: BossPatternData = _pattern(&"prism_beam", 1)
	brain._pattern_prism_beam(pattern)
	marsh.beam["angle"] = (-to_boss).angle()
	marsh.beam["start"] = ctx.time
	marsh.beam["arc"] = 0.0
	boss.invulnerable_time = 0.0
	var hp: float = boss.hp
	var player_hp: float = ctx.player.hp
	_tick(0.1)
	check(marsh.facets.all(func(f: float) -> bool: return f <= 0.0), "la carapace vole en éclats")
	check(brain.stunned_time > 0.0 and brain.heart_time > 0.0, "le boss est étourdi et vulnérable")
	check(boss.hp < hp, "le rayon renvoyé le blesse")
	check(is_equal_approx(ctx.player.hp, player_hp), "derrière le miroir, le Chasseur est à l'abri")


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


func test_tidal_wave_is_dodged_by_a_dash_or_a_mud_wall() -> void:
	_fight(Vector2(400, 0))
	var pattern: BossPatternData = _pattern(&"tide_wave", 2)
	var start: Vector2 = ctx.player.global_position
	var hp: float = ctx.player.hp
	brain._pattern_tide_wave(pattern)
	check_eq(marsh.waves.size(), int(pattern.params["waves"]), "les vagues partent du boss")
	marsh.waves.resize(1)
	_tick(pattern.telegraph + 400.0 / float(pattern.params["speed"]) + 0.2)
	check(ctx.player.hp < hp, "la vague frappe le Chasseur à découvert")
	check(ctx.player.global_position.distance_to(boss.position) > start.distance_to(boss.position) + 30.0, "et le repousse")
	_tick(4.0)
	check(marsh.waves.is_empty(), "la vague s'éteint au bout de sa course : rien n'enferme le Chasseur")
	# Ruée : la vague est traversée.
	ctx.player.global_position = start
	hp = ctx.player.hp
	brain._pattern_tide_wave(pattern)
	marsh.waves.resize(1)
	_tick(pattern.telegraph + 0.9)
	ctx.player._dash_time = 1.0
	_tick(1.0)
	ctx.player._dash_time = 0.0
	check(is_equal_approx(ctx.player.hp, hp), "une Ruée traverse la vague")
	_tick(4.0)
	# Vase durcie entre le boss et le Chasseur : abri.
	ctx.player.global_position = start
	marsh.puddles.append({"pos": boss.position + Vector2(-250, 0), "radius": 75.0, "harden_at": ctx.time,
		"crumble_at": ctx.time + 20.0, "wall": -1})
	_tick(0.05)
	ctx.player.global_position = start
	check(marsh.sheltered(boss.position, start), "le mur de vase abrite")
	hp = ctx.player.hp
	brain._pattern_tide_wave(pattern)
	_tick(pattern.telegraph + 4.0)
	check(is_equal_approx(ctx.player.hp, hp), "à l'abri de la vase durcie, la vague passe")


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
