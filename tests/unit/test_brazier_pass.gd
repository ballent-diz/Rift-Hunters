extends TestCase
## Carte 17, Col des braseros (docs/maps/COL_DES_BRASEROS.md) : fermeture de failles de nuit, en montant vers le nord ;
## froid et braseros (brique B7) qui éclairent la nuit ; Chaman ancestral et son Grand gel au sommet.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"brazier_pass"
	setup.starter_id = &"ashblade"
	setup.run_seed = 3
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func test_arena_and_campaign() -> void:
	var arena: ArenaData = GameDB.arena(&"brazier_pass")
	check_eq(arena.rift_points.size(), 4, "quatre failles")
	check_eq(arena.braziers.size(), 10, "dix braseros sur les foyers")
	check(arena.cold_rate > 0.0 and arena.night > 0.0, "froid et nuit")
	check_eq(arena.boss_id, &"rime_elder", "gardien : le Chaman ancestral")
	check_eq(GameDB.boss(&"rime_elder").signature, &"deep_freeze", "mécanique phare : le Grand gel")
	var glacier: ChapterData = GameDB.chapters.get(&"silent_glacier")
	check_eq(glacier.maps[1].arena_id, &"brazier_pass", "deuxième carte du chapitre 4")


func test_points_stand_on_open_ground_and_connect() -> void:
	var ctx: RunContext = _start()
	var arena: ArenaData = ctx.arena
	check(not ctx.obstacles.blocks(ctx.player.global_position, 20.0), "départ sur la place du camp")
	check(ctx.cold.warm(ctx.player.global_position), "départ dans la chaleur du premier brasero")
	var field := FlowField.new()
	field.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
	field.update(arena.finale_center)
	check(field.cost_at(ctx.player.global_position) < FlowField.UNREACHED, "le départ mène au sommet")
	for pos: Vector2 in arena.rift_points:
		check(not ctx.obstacles.blocks(pos, 60.0, false), "faille en %s : sol dégagé" % pos)
		check(field.cost_at(pos) < FlowField.UNREACHED, "faille en %s : sur le parcours" % pos)
	for pos: Vector2 in arena.braziers:
		check(field.cost_at(pos + Vector2(0, 60)) < FlowField.UNREACHED
			or field.cost_at(pos + Vector2(60, 0)) < FlowField.UNREACHED, "brasero en %s : atteignable" % pos)
	check(not ctx.obstacles.blocks(arena.finale_center, 200.0, false), "replat du sommet dégagé")


## Nuit : un brasero allumé éclaire autour de lui ; éteint, il ne l'éclaire plus.
func test_lit_braziers_light_the_night() -> void:
	var ctx: RunContext = _start()
	check(ctx.night != null and ctx.cold != null, "nuit et froid actifs")
	var pos: Vector2 = ctx.arena.braziers[5] + Vector2(80, 0)
	check(ctx.night.is_lit(pos), "près d'un brasero allumé : éclairé")
	ctx.cold.snuff(5)
	check(not ctx.night.is_lit(pos), "brasero soufflé : dans le noir")


## Grand gel : un seul brasero reste allumé ; hors de sa chaleur, dégâts et prison ; dedans, rien.
func test_deep_freeze_spares_the_last_brazier() -> void:
	var ctx: RunContext = _start()
	var boss: Enemy = ctx.enemies.spawn_boss(GameDB.boss(&"rime_elder"), ctx.arena.finale_center)
	var brain := BossController.new(ctx, boss)
	var pattern: BossPatternData = GameDB.boss(&"rime_elder").phases[0].patterns[2]
	ctx.player.global_position = ctx.arena.finale_center
	brain.frost_elder().deep_freeze(pattern)
	var keep: int = int(brain.frost_elder().freeze["keep"])
	check(keep >= 0 and ctx.cold.is_lit(keep), "un brasero gardé, allumé")
	var lit: int = 0
	for i: int in ctx.arena.braziers.size():
		if ctx.arena.braziers[i].distance_to(boss.position) <= 1400.0 and ctx.cold.is_lit(i):
			lit += 1
	check_eq(lit, 1, "les autres braseros proches sont soufflés")
	var hp: float = ctx.player.hp
	ctx.player.global_position = ctx.arena.braziers[keep] + Vector2(40, 0)
	brain.frost_elder()._release()
	check_eq(ctx.player.hp, hp, "dans la chaleur : épargné")
	check(not ctx.frost.imprisoned(), "pas de prison")
	brain.frost_elder().deep_freeze(pattern)
	ctx.player.global_position = ctx.arena.braziers[int(brain.frost_elder().freeze["keep"])] + Vector2(900, 0)
	brain.frost_elder()._release()
	check(ctx.frost.imprisoned(), "hors de la chaleur : prison de glace")
