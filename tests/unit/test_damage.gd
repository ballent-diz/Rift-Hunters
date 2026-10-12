extends TestCase

var run: RunController


func before_each() -> void:
	run = RunFixture.create(host)


func after_each() -> void:
	RunFixture.dispose(run)


func test_defense_formula() -> void:
	check_near(CombatSystem.defense_multiplier(0.0), 1.0)
	check_near(CombatSystem.defense_multiplier(100.0), 0.5)
	check_near(CombatSystem.defense_multiplier(-50.0), 1.0, 0.001, "défense négative bornée à 0")


func test_damage_applies_defense() -> void:
	var husk: Enemy = RunFixture.spawn(run, &"husk")
	var expected: float = 20.0 * 100.0 / (100.0 + husk.get_defense())
	var dealt: float = run.ctx.combat.deal_damage(husk, RunFixture.info(20.0))
	check_near(dealt, expected, 0.01, "dégâts réduits par la défense de la Carapace")


func test_fracture_amplifies_damage() -> void:
	var husk: Enemy = RunFixture.spawn(run, &"husk")
	var before: float = run.ctx.combat.compute_damage(husk, RunFixture.info(20.0))
	run.ctx.status_system.apply(husk, &"fracture", 1, &"player")
	var after: float = run.ctx.combat.compute_damage(husk, RunFixture.info(20.0))
	check(after > before * 1.4, "la Fracture rend la Carapace bien plus vulnérable (%.1f → %.1f)" % [before, after])


func test_kill_drops_xp_and_counts() -> void:
	var enemy: Enemy = RunFixture.spawn(run, &"skitterling")
	run.ctx.combat.deal_damage(enemy, RunFixture.info(9999.0))
	check(not enemy.alive, "ennemi mort")
	check_eq(int(run.ctx.stats.get_value(&"kills")), 1, "élimination comptée")
	check(run.ctx.pickups.items.size() >= 1, "gemme d'XP lâchée")


func test_elite_drops_chest() -> void:
	var affixes: Array[EliteAffixData] = [GameDB.affix(&"hasted")]
	var elite: Enemy = run.ctx.enemies.spawn(GameDB.enemy(&"skitterling"), Vector2(200, 0), affixes)
	check(elite.is_elite and elite.max_hp > GameDB.enemy(&"skitterling").max_hp * 2.0, "élite renforcée")
	run.ctx.combat.deal_damage(elite, RunFixture.info(99999.0))
	var chests: int = 0
	for item: Dictionary in run.ctx.pickups.items:
		if item["kind"] == PickupManager.Kind.CHEST:
			chests += 1
	check_eq(chests, 1, "un coffre lâché par l'élite")


func test_player_iframes() -> void:
	var player: Player = run.ctx.player
	var hp: float = player.hp
	run.ctx.combat.damage_player(10.0, &"test")
	run.ctx.combat.damage_player(10.0, &"test")
	check_near(player.hp, hp - 10.0, 0.01, "un seul coup encaissé pendant l'invulnérabilité")


func test_last_breath_prevents_death() -> void:
	var player: Player = run.ctx.player
	player.stats.add_modifier(StatKeys.LAST_BREATH, 1.0)
	run.ctx.combat.damage_player(9999.0, &"test")
	check(player.alive and player.hp >= 1.0, "Dernier souffle sauve le Chasseur une fois")


func test_status_stacking_and_detonation() -> void:
	var enemy: Enemy = RunFixture.spawn(run, &"husk")
	for i: int in 8:
		run.ctx.status_system.apply(enemy, &"mark", 1, &"glimmerwing")
	check_eq(enemy.statuses.get_stacks(&"mark"), 5, "Marques plafonnées à 5")
	var hp: float = enemy.hp
	var consumed: int = run.ctx.status_system.detonate(enemy, 10.0, &"glimmerwing")
	check_eq(consumed, 5, "5 cumuls consommés")
	check(enemy.hp < hp and not enemy.statuses.has(&"mark"), "détonation : dégâts et Marques retirées")


func test_mark_bonus_stacks_from_stats() -> void:
	var enemy: Enemy = RunFixture.spawn(run, &"husk")
	run.ctx.player.stats.add_modifier(StatKeys.MARK_MAX_STACKS, 3.0)
	for i: int in 10:
		run.ctx.status_system.apply(enemy, &"mark", 1, &"glimmerwing")
	check_eq(enemy.statuses.get_stacks(&"mark"), 8, "Prisme fêlé : cumul maximal 8")


func test_burn_ticks() -> void:
	var enemy: Enemy = RunFixture.spawn(run, &"husk")
	run.ctx.status_system.apply(enemy, &"burn", 3, &"player")
	var hp: float = enemy.hp
	for i: int in 60:
		run.ctx.enemies.step(1.0 / 60.0)
	check(enemy.hp < hp, "la Brûlure inflige des dégâts sur la durée")
