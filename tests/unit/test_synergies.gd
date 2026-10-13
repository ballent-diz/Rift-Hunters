extends TestCase

var run: RunController


func before_each() -> void:
	run = RunFixture.create(host, &"mossback")


func after_each() -> void:
	RunFixture.dispose(run)


func test_synergy_activates_with_pair() -> void:
	check(run.ctx.build.active_synergies.is_empty(), "aucune synergie avec un seul Écho")
	run.ctx.allies.add_monster(&"ashblade")
	check(run.ctx.build.active_synergies.has(&"breach_and_blade"), "Brèche & Lame active avec Mousseroc + Cendrelame")


func test_breach_and_blade_extra_strike() -> void:
	run.ctx.allies.add_monster(&"ashblade")
	var husk: Enemy = RunFixture.spawn(run, &"husk")
	run.ctx.status_system.apply(husk, &"fracture", 1, &"mossback")
	var procs: Array[int] = [0]
	run.ctx.events.synergy_proc.connect(func(id: StringName) -> void:
		if id == &"breach_and_blade":
			procs[0] += 1)
	var hp: float = husk.hp
	var first: float = run.ctx.combat.deal_damage(husk, RunFixture.info(10.0, &"ashblade"))
	run.ctx.combat.flush_queue()
	check_eq(procs[0], 1, "frappe supplémentaire déclenchée")
	check(hp - husk.hp > first * 1.3, "la frappe supplémentaire inflige des dégâts")


func test_no_extra_strike_without_fracture() -> void:
	run.ctx.allies.add_monster(&"ashblade")
	var husk: Enemy = RunFixture.spawn(run, &"husk")
	var procs: Array[int] = [0]
	run.ctx.events.synergy_proc.connect(func(_id: StringName) -> void: procs[0] += 1)
	run.ctx.combat.deal_damage(husk, RunFixture.info(10.0, &"ashblade"))
	run.ctx.combat.flush_queue()
	check_eq(procs[0], 0, "pas de frappe supplémentaire sans Fracture")


func test_prism_ember_spreads_marks() -> void:
	run.ctx.allies.add_monster(&"ashblade")
	run.ctx.player.stats.add_modifier(StatKeys.TEAM_SLOTS, 1.0)
	run.ctx.allies.add_monster(&"glimmerwing")
	check(run.ctx.build.active_synergies.has(&"prism_ember"), "Braise prismatique active")
	var target: Enemy = RunFixture.spawn(run, &"skitterling", Vector2(300, 0))
	var neighbor: Enemy = RunFixture.spawn(run, &"husk", Vector2(340, 0))
	run.ctx.enemies.step(0.0)
	run.ctx.status_system.apply(target, &"mark", 3, &"glimmerwing")
	run.ctx.combat.deal_damage(target, RunFixture.info(9999.0, &"ashblade"))
	run.ctx.combat.flush_queue()
	check_eq(neighbor.statuses.get_stacks(&"mark"), 3, "les Marques se propagent au voisin")


func test_gravity_prism_marks_pulled_enemies() -> void:
	run.ctx.player.stats.add_modifier(StatKeys.TEAM_SLOTS, 1.0)
	run.ctx.allies.add_monster(&"glimmerwing")
	var enemy: Enemy = RunFixture.spawn(run, &"husk", Vector2(150, 0))
	run.ctx.events.well_tick.emit([enemy], &"mossback")
	check_eq(enemy.statuses.get_stacks(&"mark"), 2, "2 Marques par seconde dans le Puits")


func test_mossback_guard_reduces_damage() -> void:
	var ally: Ally = run.ctx.allies.get_ally(&"mossback")
	ally.global_position = run.ctx.player.global_position
	var hp: float = run.ctx.player.hp
	run.ctx.combat.damage_player(20.0, &"test")
	check_near(hp - run.ctx.player.hp, 18.0, 0.01, "Rempart : −10 % de dégâts près de Mousseroc")
