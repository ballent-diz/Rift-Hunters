extends TestCase
## Carte 20, Cœur du Silence (docs/maps/COEUR_DU_SILENCE.md) : vagues par zone d'est en ouest, glace (B1), écho des
## sorts (B9) et Nivorath dans la cathédrale gelée.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"silent_heart"
	setup.starter_id = &"ashblade"
	setup.run_seed = 4
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func test_arena_and_campaign() -> void:
	var arena: ArenaData = GameDB.arena(&"silent_heart")
	check(arena.zones.size() == 2 and arena.has_finale(), "deux zones puis la cathédrale")
	check_eq(arena.ice_patches.size(), 10, "dix plaques de glace")
	check(arena.spell_echo > 0.0, "écho des sorts")
	check_eq(arena.boss_id, &"nivorath", "Dévoreur du chapitre 4")
	check_eq(GameDB.chapters.get(&"silent_glacier").maps[4].arena_id, &"silent_heart", "cinquième carte du chapitre 4")


func test_points_stand_on_open_ground_and_zones_are_sealed() -> void:
	var ctx: RunContext = _start()
	var arena: ArenaData = ctx.arena
	check(not ctx.obstacles.blocks(ctx.player.global_position, 20.0), "départ dégagé")
	for zone: LevelZoneData in arena.zones:
		check(not ctx.obstacles.blocks(zone.anchor, 40.0, false), "centre de zone praticable : %s" % zone.anchor)
	check(not ctx.obstacles.blocks(arena.finale_center, 150.0, false), "cathédrale dégagée")
	# Barrières fermées : le départ ne mène pas à la cathédrale ; ouvertes, si.
	var field := FlowField.new()
	field.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
	field.apply_walls(ctx.obstacles)
	field.update(arena.finale_center)
	check(field.cost_at(ctx.player.global_position) >= FlowField.UNREACHED, "barrières étanches")
	for i: int in ctx.obstacles.walls.size():
		ctx.obstacles.set_wall_enabled(i, false)
	field.apply_walls(ctx.obstacles)
	field.update(arena.finale_center)
	check(field.cost_at(ctx.player.global_position) < FlowField.UNREACHED, "le départ mène à la cathédrale")
	for zone: LevelZoneData in arena.zones:
		check(field.cost_at(zone.anchor) < FlowField.UNREACHED, "zone %s sur le parcours" % zone.anchor)


func test_spells_echo_once() -> void:
	var ctx: RunContext = _start()
	var spells: HunterSpells = ctx.spells
	var slot: int = -1
	for i: int in spells.slots.size():
		if spells.slots[i] and HunterSpells.ECHO_KINDS.has(spells.slots[i].spell_kind):
			slot = i
			break
	check(slot >= 0, "un sort offensif équipé")
	if slot < 0:
		return
	check(spells.cast(slot, ctx.player.global_position + Vector2(200, 0)), "sort lancé")
	check_eq(spells._echoes.size(), 1, "un écho en attente")
	spells.step(ctx.arena.spell_echo_delay + 0.05)
	check(spells._echoes.is_empty(), "l'écho est parti")
	check_eq(ctx.stats.counters.get(&"spell_echoes_cast", 0.0), 1.0, "compté pour l'objectif")
