extends TestCase
## Carte 22, Sanctuaire des runes (docs/maps/SANCTUAIRE_DES_RUNES.md) : défense du reliquaire, portes runiques qui
## tournent (brique B4, RuneGateDirector) et Golem du sanctuaire.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"rune_sanctum"
	setup.starter_id = &"ashblade"
	setup.run_seed = 7
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func test_arena_and_campaign() -> void:
	var arena: ArenaData = GameDB.arena(&"rune_sanctum")
	check(arena.altar_waves > 0, "défense du reliquaire")
	check_eq(arena.rune_gates.size(), 6, "six portes runiques")
	check(arena.decor_scale < 1.0, "décor réduit (ECHELLE_CHAPITRES_4_5)")
	check_eq(GameDB.boss(arena.boss_id).signature, &"rune_barrage", "gardien : Tempête de runes")
	check_eq(GameDB.chapters.get(&"rift_city").maps[1].arena_id, &"rune_sanctum", "deuxième carte du chapitre 5")


## Chaque groupe de portes fermées (et même les six) laisse le reliquaire joignable de partout.
func test_every_gate_pattern_keeps_the_altar_reachable() -> void:
	var ctx: RunContext = _start()
	var arena: ArenaData = ctx.arena
	check(not ctx.obstacles.blocks(ctx.player.global_position, 20.0), "départ dégagé")
	for point: Vector2 in arena.altar_spawn_points:
		check(not ctx.obstacles.blocks(point, 30.0, false), "arrivée des vagues praticable : %s" % point)
	var foot: Vector2 = ctx.obstacles.push_out(ctx.altar.position + Vector2(0.0, 220.0), 30.0)
	var patterns: Array[PackedInt32Array] = arena.rune_gate_patterns.duplicate()
	patterns.append(PackedInt32Array([0, 1, 2, 3, 4, 5]))
	for pattern: PackedInt32Array in patterns:
		for i: int in ctx.gates._walls.size():
			ctx.obstacles.set_wall_enabled(ctx.gates._walls[i], pattern.has(i))
		var field := FlowField.new()
		field.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
		field.apply_walls(ctx.obstacles)
		field.update(foot)
		check(field.cost_at(ctx.player.global_position) < FlowField.UNREACHED, "départ relié (%s)" % pattern)
		for point: Vector2 in arena.altar_spawn_points:
			check(field.cost_at(point) < FlowField.UNREACHED, "arrivée %s reliée (%s)" % [point, pattern])


func test_gates_warn_then_turn() -> void:
	var ctx: RunContext = _start()
	var gates: RuneGateDirector = ctx.gates
	check(gates.closed_gates().is_empty(), "portes ouvertes au départ")
	gates.step(ctx.arena.rune_gate_first - ctx.arena.rune_gate_warning + 0.1)
	check(gates.next_pattern == 0 and gates.closed_gates().is_empty(), "alerte avant la fermeture")
	gates.step(ctx.arena.rune_gate_warning)
	check_eq(gates.closed_gates(), Array(ctx.arena.rune_gate_patterns[0]), "premier groupe fermé")
	var gate: Rect2 = ctx.arena.rune_gates[ctx.arena.rune_gate_patterns[0][0]]
	check(ctx.obstacles.blocks(gate.get_center(), 4.0), "rideau de runes infranchissable")
	gates.force_turn()
	check_eq(gates.closed_gates(), Array(ctx.arena.rune_gate_patterns[1]), "les portes tournent")
	check(not ctx.obstacles.blocks(gate.get_center(), 4.0), "l'ancienne porte se rouvre")
	check(ctx.stats.counters.get(&"rune_gates_turned", 0.0) >= 2.0, "compté pour l'objectif")
