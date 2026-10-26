extends TestCase
## Équilibrage du chapitre 1 : chaque carte peut affaiblir ou renforcer son boss (PV et dégâts), indépendamment des
## multiplicateurs des vagues (ArenaData.boss_hp_mult, boss_damage_mult).

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start(arena: StringName) -> void:
	var setup := RunSetup.new()
	setup.arena_id = arena
	setup.starter_id = &"ashblade"
	setup.run_seed = 3
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)


func test_boss_hp_and_damage_follow_the_arena() -> void:
	_start(&"three_rifts")
	var ctx: RunContext = run.ctx
	check(ctx.arena.boss_hp_mult < 1.0 and ctx.arena.boss_damage_mult < 1.0, "boss de la carte 1 adouci")
	var data: BossData = GameDB.boss(ctx.arena.boss_id)
	var boss: Enemy = ctx.enemies.spawn_boss(data, ctx.player.global_position + Vector2(400, 0))
	check_near(boss.max_hp, data.max_hp * ctx.difficulty.enemy_hp_mult * ctx.arena.boss_hp_mult, 0.01, "PV du boss")
	check_near(boss.contact_damage, data.damage * ctx.difficulty.enemy_damage_mult * ctx.arena.boss_damage_mult, 0.01,
		"dégâts de contact du boss")
	var brain := BossController.new(ctx, boss)
	var pattern: BossPatternData = data.phases[0].patterns[0]
	check_near(brain._damage(pattern), pattern.damage * ctx.difficulty.enemy_damage_mult * ctx.arena.boss_damage_mult,
		0.01, "dégâts des attaques du boss")


func test_default_arena_keeps_full_boss() -> void:
	var arena := ArenaData.new()
	check_eq(arena.boss_hp_mult, 1.0, "PV par défaut")
	check_eq(arena.boss_damage_mult, 1.0, "dégâts par défaut")
