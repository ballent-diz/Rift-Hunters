extends TestCase
## Carte 13, Jardins de cristal (docs/design/CARTES.md) : cristaux-miroirs (brique B5, variante rayons) et gardienne
## Mère des spores, dont le voile ne brûle que sous un rayon de cristal (docs/design/MONSTRES.md).

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"crystal_gardens"
	setup.starter_id = &"ashblade"
	setup.run_seed = 3
	setup.autopilot = true
	var arena: ArenaData = GameDB.arena(&"crystal_gardens").duplicate()
	arena.crystal_mirrors = [Vector2(-1450, -80)]
	setup.arena_override = arena
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	run.ctx.player.global_position = Vector2(-1600, -80)
	return run.ctx


func _crystal(ctx: RunContext) -> Dictionary:
	return ctx.pods.pods[0]


func _tick(ctx: RunContext, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		ctx.time += 0.05
		ctx.pods.step(0.05)
		t += 0.05


func test_arena_and_campaign() -> void:
	var arena: ArenaData = GameDB.arena(&"crystal_gardens")
	check(arena != null and arena.zones.size() == 2 and arena.has_finale(), "deux zones puis la terrasse")
	check_eq(arena.crystal_mirrors.size(), 9, "trois cristaux par clairière")
	check_eq(arena.boss_id, &"spore_matriarch", "gardienne : la Mère des spores")
	var marshes: ChapterData = GameDB.chapters.get(&"sunken_marshes")
	check_eq(marshes.maps.size(), 3, "chapitre 3 : trois cartes")
	check_eq(marshes.maps[2].arena_id, &"crystal_gardens", "les Jardins ferment le chapitre pour l'instant")
	check_eq(GameDB.monster(&"voltwisp").discovery_arena, &"crystal_gardens", "Fulgurine s'y découvre")


func test_crystals_stand_on_open_ground() -> void:
	var ctx: RunContext = _start()
	for pos: Vector2 in GameDB.arena(&"crystal_gardens").crystal_mirrors:
		check(not ctx.obstacles.blocks(pos, 40.0), "cristal en %s : sur un sol praticable" % pos)


func test_crystal_beam_pierces_the_line_in_the_blow_direction() -> void:
	var ctx: RunContext = _start()
	var crystal: Enemy = _crystal(ctx)["enemy"]
	var ahead: Enemy = ctx.enemies.spawn(GameDB.enemy(&"mire_leech"), crystal.position + Vector2(300, 0))
	var aside: Enemy = ctx.enemies.spawn(GameDB.enemy(&"mire_leech"), crystal.position + Vector2(0, 300))
	ctx.pods.prime(crystal, ctx.player.global_position)
	check_eq(_crystal(ctx)["state"], PodDirector.State.PRIMED, "le coup charge le cristal")
	check(((_crystal(ctx)["dir"]) as Vector2).is_equal_approx(Vector2.RIGHT), "premier rayon dans le sens du coup")
	var before_ahead: float = ahead.hp
	var before_aside: float = aside.hp
	_tick(ctx, ctx.arena.crystal_prime + 0.1)
	check(not ahead.alive or ahead.hp < before_ahead, "le Corrompu dans l'axe est transpercé")
	check_eq(aside.hp, before_aside, "celui hors des trois rayons est épargné")
	check_eq(_crystal(ctx)["state"], PodDirector.State.EMPTY, "puis le cristal se vide")
	_tick(ctx, ctx.arena.crystal_regrow + 0.1)
	check_eq(_crystal(ctx)["state"], PodDirector.State.IDLE, "et repousse")


func test_spore_veil_burns_only_under_a_crystal_beam() -> void:
	var ctx: RunContext = _start()
	var crystal: Enemy = _crystal(ctx)["enemy"]
	var boss: Enemy = ctx.enemies.spawn_boss(GameDB.boss(&"spore_matriarch"), crystal.position + Vector2(260, 0))
	ctx.boss = boss
	var brain := BossController.new(ctx, boss)
	var veil: SporeGuardian = brain.spore()
	check(veil.veiled(), "le voile est levé dès l'arrivée")
	var tags: Array[StringName] = []
	var blow: float = ctx.combat.deal_damage(boss, DamageInfo.make(100.0, DamageInfo.SourceKind.PLAYER, &"player", tags))
	check(blow < 40.0, "sous le voile, les coups glissent")
	ctx.pods.prime(crystal, crystal.position + Vector2(-80, 30))
	_tick(ctx, ctx.arena.crystal_prime + 0.1)
	check(not veil.veiled(), "le rayon du cristal (aimanté vers elle) brûle le voile")
	check(brain.stunned_time > 0.0 and brain.heart_time > 0.0, "sonnée, dégâts doublés")
	ctx.time += float(veil.veil["burn"]) + float(veil.veil["regrow"]) + 0.1
	check(veil.veiled(), "puis le voile repousse")


func test_bot_takes_place_behind_an_aligned_crystal() -> void:
	var ctx: RunContext = _start()
	var crystal: Enemy = _crystal(ctx)["enemy"]
	var boss: Enemy = ctx.enemies.spawn_boss(GameDB.boss(&"spore_matriarch"), crystal.position + Vector2(300, 0))
	var brain := BossController.new(ctx, boss)
	var spot: Vector2 = brain.spore().bot_crystal_spot(ctx.player.global_position)
	check(spot != Vector2.INF and spot.x < crystal.position.x, "le bot vise l'arrière du cristal, côté opposé à elle")
