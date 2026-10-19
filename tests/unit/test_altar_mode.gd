extends TestCase
## Mode « défense d'autel » (docs/design/CARTES.md, carte 4) : vagues, pillards, réparation, gardien, défaite.

var run: RunController


func before_each() -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"fractured_plain"
	setup.starter_id = &"mossback"
	setup.autopilot = true
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
