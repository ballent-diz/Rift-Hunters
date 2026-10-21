extends TestCase
## Mode « défense d'autel » (docs/design/CARTES.md, carte 4) : vagues, pillards, réparation, gardien, défaite.

var run: RunController


func before_each() -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"fractured_plain"
	setup.starter_id = &"mossback"
	setup.autopilot = true
	setup.run_seed = 3
	setup.arena_override = TestArena.build(&"fractured_plain", &"", ["altar"])
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	run.ctx.player.god_mode = true


func after_each() -> void:
	RunFixture.dispose(run)


func _advance(seconds: float, step: float = 0.25) -> void:
	var ctx: RunContext = run.ctx
	for i: int in int(seconds / step):
		ctx.time += step
		ctx.altar.step(step)
		run.spawner.step(step)
		ctx.enemies.rebuild_grid()


func _clear_enemies() -> void:
	for enemy: Enemy in run.ctx.enemies.list.duplicate():
		if enemy.alive and not enemy.is_boss:
			run.ctx.combat.deal_damage(enemy, RunFixture.info(1e9))
	run.ctx.combat.flush_queue()
	run.ctx.enemies.step(0.0)


func test_waves_come_with_raiders_and_no_timed_spawns() -> void:
	var ctx: RunContext = run.ctx
	check(ctx.altar != null, "mode défense d'autel actif")
	run.spawner.step(5.0)
	check_eq(ctx.enemies.count(), 0, "pas d'apparitions classiques au chrono")
	_advance(AltarDirector.START_DELAY + 8.0)
	check_eq(ctx.altar.phase, AltarDirector.Phase.WAVE, "première vague lancée")
	check(ctx.enemies.count() > 5, "les Corrompus arrivent")
	var raiders: int = 0
	for enemy: Enemy in ctx.enemies.list:
		if enemy.taunt_target == ctx.altar:
			raiders += 1
			check(enemy.goal_flow == ctx.altar.guide, "un pillard suit la route vers l'autel")
	check(raiders > 0, "une partie des Corrompus vise l'autel")


func test_contacts_damage_the_altar_and_breaking_it_loses() -> void:
	var ctx: RunContext = run.ctx
	var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(&"husk"), ctx.altar.position + Vector2(20, 0))
	enemy.max_hp = 1e6
	enemy.hp = 1e6
	ctx.enemies.rebuild_grid()
	var before: float = ctx.altar.hp
	ctx.altar.step(1.0)
	check(ctx.altar.hp < before, "un Corrompu au contact abîme l'autel")
	ctx.altar.hp = 1.0
	ctx.altar.step(1.0)
	check(ctx.altar.destroyed, "autel détruit")
	for i: int in 200:
		if ctx.finished:
			break
		run._physics_process(1.0 / 60.0)
	check(ctx.finished and not ctx.victory, "autel détruit : expédition perdue")


func test_held_waves_repair_reward_then_guardian() -> void:
	var ctx: RunContext = run.ctx
	var chests: Array[int] = [0]
	ctx.events.chest_collected.connect(func() -> void: chests[0] += 1)
	_advance(AltarDirector.START_DELAY + 1.0)
	for wave: int in ctx.altar.waves():
		check_eq(ctx.altar.wave_index, wave, "vague %d en cours" % (wave + 1))
		ctx.altar.hp = ctx.altar.max_hp * 0.5
		_advance(ctx.arena.altar_wave_duration)
		_clear_enemies()
		if wave < ctx.altar.waves() - 1:
			check_eq(ctx.altar.phase, AltarDirector.Phase.PAUSE, "pause après la vague %d" % (wave + 1))
			check(ctx.altar.hp > ctx.altar.max_hp * 0.5, "le sceau se répare")
			_advance(ctx.arena.altar_wave_pause + 0.5)
	check_eq(chests[0], ctx.altar.waves() - 1, "un coffre par vague repoussée")
	check_eq(ctx.altar.phase, AltarDirector.Phase.BOSS, "après la dernière vague : le gardien")
	check(ctx.boss != null and ctx.boss.boss_data.guardian, "le gardien de la carte s'éveille")
	check(ctx.altar.shattered and not ctx.altar._seal.visible, "le sceau se brise et disparaît")
	var seal_center: Vector2 = ctx.altar.position + ctx.altar._body_center
	check(not ctx.obstacles.blocks(seal_center, 10.0, false), "plus de collision : toute la carte est libre")
	check(ctx.boss.position.distance_to(seal_center) < 1.0, "le gardien sort du sceau brisé")
	var hp: float = ctx.altar.hp
	var raider: Enemy = ctx.enemies.spawn(GameDB.enemy(&"husk"), ctx.altar.position)
	ctx.enemies.rebuild_grid()
	ctx.altar.step(2.0)
	check_eq(ctx.altar.hp, hp, "sceau refermé : le combat du gardien ne peut plus faire perdre l'autel")
	check(raider.taunt_target != ctx.altar, "plus de pillards pendant le combat du gardien")
	for enemy: Enemy in ctx.enemies.list:
		if enemy != raider and enemy.alive:
			check(enemy.is_boss, "l'onde du sceau a purifié les Corrompus restants")
	check_eq(ctx.objective_direction(ctx.player.global_position + Vector2(2000, 0)), Vector2.ZERO,
		"pas de flèche vers l'autel pendant le combat du gardien")


func test_seal_visual_follows_the_altar_state() -> void:
	var altar: AltarDirector = run.ctx.altar
	check(altar._seal != null, "sprite du sceau chargé (object.altar_seal)")
	altar.step(0.01)
	check_eq(altar._seal.animation, &"intact", "intact au départ")
	altar.hp = altar.max_hp * (AltarDirector.DAMAGED_RATIO - 0.05)
	altar.step(0.01)
	check_eq(altar._seal.animation, &"damaged", "fendu sous la moitié de ses PV")
	altar._play_burst(&"hit")
	check(altar._burst.visible and altar._burst.animation == &"hit", "éclat quand il est frappé")
	altar.phase = AltarDirector.Phase.BOSS
	altar.step(0.01)
	check_eq(altar._seal.animation, &"sealed", "scellé pendant le combat du gardien")


func test_whole_seal_is_solid_and_still_attackable() -> void:
	var ctx: RunContext = run.ctx
	var altar: AltarDirector = ctx.altar
	var center: Vector2 = altar.position + altar._body_center
	var s: float = Assets.pixel_scale(AltarDirector.VISUAL_ID)
	var top: Vector2 = altar.position + Vector2(0.0, (AltarDirector.SEAL_TOP - Assets.anchor(AltarDirector.VISUAL_ID).y) * s)
	for pos: Vector2 in [center, top + Vector2(0, 8), center + Vector2(altar._body_radius - 6.0, 0)]:
		check(ctx.obstacles.blocks(pos, 1.0, false), "le sceau est solide en %s" % pos)
	var pushed: Vector2 = ctx.obstacles.push_out(center + Vector2(10, 0), ctx.player.radius)
	check(pushed.distance_to(center) >= altar._body_radius, "le Chasseur est repoussé hors du sceau")
	var hp: float = altar.hp
	ctx.enemies.spawn(GameDB.enemy(&"husk"), pushed)
	ctx.enemies.rebuild_grid()
	altar.phase = AltarDirector.Phase.WAVE
	altar._suffer_contacts(1.0)
	check(altar.hp < hp, "un Corrompu collé au bord du sceau le frappe")
