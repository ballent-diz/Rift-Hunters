extends TestCase
## Phase 4 : nouveaux Échos, ennemis, capture, modificateurs, arène et boss.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _run_with(starter: StringName, arena: StringName = &"fractured_plain", modifiers: Array[StringName] = []) -> RunController:
	var setup := RunSetup.new()
	setup.starter_id = starter
	setup.arena_id = arena
	setup.run_seed = 11
	setup.autopilot = true
	setup.modifier_ids = modifiers
	setup.unlocked_monsters = GameDB.sorted_ids(GameDB.monsters)
	run = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run


func test_gloommaw_devours_weak_enemies_only() -> void:
	_run_with(&"gloommaw")
	var ally: Ally = run.ctx.allies.get_ally(&"gloommaw")
	var weak: Enemy = RunFixture.spawn(run, &"husk", Vector2(60, 0))
	weak.hp = weak.max_hp * 0.2
	var before: float = ally.damage_mult()
	check(DevourBehavior.try_devour(ally, run.ctx, weak), "ennemi affaibli dévoré")
	check(not weak.alive and ally.damage_mult() > before, "dévoré et dégâts accrus")
	var affixes: Array[EliteAffixData] = [GameDB.affix(&"hasted")]
	var elite: Enemy = run.ctx.enemies.spawn(GameDB.enemy(&"husk"), Vector2(120, 0), affixes)
	elite.hp = elite.max_hp * 0.1
	check(not DevourBehavior.try_devour(ally, run.ctx, elite), "les élites ne sont jamais dévorées")


func test_mirrorling_reflects_projectiles() -> void:
	_run_with(&"mirrorling")
	var ally: Ally = run.ctx.allies.get_ally(&"mirrorling")
	RunFixture.spawn(run, &"spitter", Vector2(300, 0))
	run.ctx.enemies.step(0.0)
	var pos: Vector2 = run.ctx.player.global_position + Vector2(40, 0)
	run.ctx.projectiles.spawn_hostile(pos, Vector2.LEFT, 150.0, 9.0, &"spitter")
	var friendly_before: int = run.ctx.projectiles.friendly.size()
	check_eq(MirrorBehavior.reflect(ally, run.ctx, 130.0), 1, "un projectile renvoyé")
	check(run.ctx.projectiles.hostile.is_empty(), "le projectile ennemi a disparu")
	check_eq(run.ctx.projectiles.friendly.size(), friendly_before + 1, "un projectile allié créé")


func test_thornweave_wall_roots_but_not_bosses() -> void:
	_run_with(&"thornweave")
	var ally: Ally = run.ctx.allies.get_ally(&"thornweave")
	var enemy: Enemy = RunFixture.spawn(run, &"husk", Vector2(140, 0))
	run.ctx.enemies.step(0.0)
	check(Techniques.cast(ally, run.ctx, run.ctx.player.global_position + Vector2(200, 0)), "Mur de ronces lancé")
	run.ctx.hazards.step(0.01)
	check(enemy.statuses.has(&"root"), "ennemi enraciné")
	check_near(enemy.statuses.speed_mult(), 0.0, 0.001, "immobilisé")
	var boss: Enemy = run.ctx.enemies.spawn_boss(GameDB.boss(&"nebulorax"), Vector2(-400, 0))
	check_eq(run.ctx.status_system.apply(boss, &"root", 1, &"thornweave"), 0, "les Dévoreurs ignorent les Racines")


func test_voltwisp_chains_and_charges() -> void:
	_run_with(&"voltwisp")
	var ally: Ally = run.ctx.allies.get_ally(&"voltwisp")
	check(ally.attack.chain >= 3, "foudre en chaîne")
	var enemy: Enemy = RunFixture.spawn(run, &"husk", Vector2(150, 0))
	run.ctx.status_system.apply(enemy, &"static", 1, &"voltwisp")
	check(enemy.get_damage_taken_mult() >= 1.2, "Électrisé : +20 % de dégâts subis")


func test_warden_and_summoner_brains() -> void:
	_run_with(&"mossback")
	var warden: Enemy = RunFixture.spawn(run, &"crystal_warden", Vector2(500, 0))
	var friend: Enemy = RunFixture.spawn(run, &"skitterling", Vector2(540, 0))
	var brood: Enemy = RunFixture.spawn(run, &"broodmother", Vector2(-500, 0))
	warden.attack_timer = 0.0
	brood.attack_timer = 0.0
	var count: int = run.ctx.enemies.count()
	run.ctx.enemies.step(1.0 / 60.0)
	check(friend.statuses.has(&"warded"), "le Gardien protège ses voisins")
	check(run.ctx.enemies.count() > count, "la Nuée-mère fait éclore des Grouillards")


func test_shade_stalker_teleports_behind() -> void:
	_run_with(&"mossback")
	var stalker: Enemy = RunFixture.spawn(run, &"shade_stalker", Vector2(250, 0))
	stalker.attack_timer = 0.0
	for i: int in 60:
		run.ctx.enemies.step(1.0 / 60.0)
	check(stalker.position.x < run.ctx.player.global_position.x + 50.0,
			"le Rôdeur est passé derrière le Chasseur (%s)" % stalker.position)


func test_capture_recruits_and_records() -> void:
	_run_with(&"mossback")
	run.ctx.pickups.spawn_capture(run.ctx.player.global_position, &"gloommaw")
	for i: int in 200:
		run.ctx.pickups.step(1.0 / 60.0)
	check(run.ctx.has_monster(&"gloommaw"), "l'Écho capturé rejoint l'équipe")
	check(run.ctx.build.captures.has(&"gloommaw"), "capture enregistrée")
	var profile := ProfileData.new()
	var result: Dictionary = run.build_result()
	MetaProgression.apply_run_result(profile, result)
	check(profile.has_unlock("monsters", &"gloommaw"), "capturer un Écho verrouillé le débloque définitivement")


func test_modifiers_raise_difficulty_and_rewards() -> void:
	var base: DifficultyData = GameDB.difficulty(&"tension_2")
	var mods: Array[StringName] = [&"horde", &"heavy_rift"]
	var combined: DifficultyData = RunController.combine_difficulty(base, mods)
	check(combined.spawn_rate_mult > base.spawn_rate_mult and combined.enemy_hp_mult > base.enemy_hp_mult, "plus difficile")
	check_near(combined.reward_mult, base.reward_mult * 1.5, 0.001, "récompenses +50 %")
	check_near(base.spawn_rate_mult, 1.2, 0.001, "la Tension d'origine n'est pas modifiée")


func test_glass_hunter_reduces_hp() -> void:
	var mods: Array[StringName] = [&"glass_hunter"]
	_run_with(&"mossback", &"fractured_plain", mods)
	check(run.ctx.player.max_hp < GameDB.balance.player_max_hp, "Chasseur de verre : PV réduits")
	check_eq(int(run.ctx.stats.get_value(&"modifiers_count")), 1, "modificateurs comptés")


func test_crystal_abyss_rules_and_obstacles() -> void:
	_run_with(&"mossback", &"crystal_abyss")
	check_eq(run.ctx.enemies.obstacles.size(), 14, "14 cristaux au départ")
	for crystal: Enemy in run.ctx.enemies.obstacles:
		check(crystal.position.distance_to(Vector2.ZERO) >= 250.0, "aucun cristal sur le Chasseur")
	check(run.ctx.player.stats.get_value(StatKeys.ALLY_DAMAGE) > 1.0, "règle d'arène installée")


func test_vorgranite_armor_breaks_in_phase_two() -> void:
	_run_with(&"mossback", &"crystal_abyss")
	var boss: Enemy = run.ctx.enemies.spawn_boss(GameDB.boss(&"vorgranite"), Vector2(400, 0))
	run.ctx.boss = boss
	var controller := BossController.new(run.ctx, boss)
	check_near(boss.base_defense, 60.0, 0.01, "carapace en phase 1")
	boss.hp = boss.max_hp * 0.4
	controller.step(1.0 / 60.0)
	check_eq(controller.phase_index, 1, "phase 2")
	check_near(boss.base_defense, 0.0, 0.01, "armure brisée en phase 2")


func test_deep_roots_and_predators_synergies() -> void:
	_run_with(&"mossback")
	run.ctx.allies.add_monster(&"thornweave")
	check(run.ctx.build.active_synergies.has(&"deep_roots"), "Racines brisantes active")
	var enemy: Enemy = RunFixture.spawn(run, &"husk", Vector2(150, 0))
	run.ctx.status_system.apply(enemy, &"root", 1, &"thornweave")
	run.ctx.combat.flush_queue()
	check(enemy.statuses.has(&"fracture"), "les Racines fracturent")
	RunFixture.dispose(run)
	run = null
	_run_with(&"ashblade")
	run.ctx.allies.add_monster(&"gloommaw")
	check(run.ctx.build.active_synergies.has(&"predators"), "Prédateurs : synergie par affinités")
