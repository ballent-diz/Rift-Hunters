extends TestCase
## Mécaniques de la carte 7 (docs/design/CARTES.md, MONSTRES.md) : bulbes de braise (B5), Bond du Chien de suie (E1),
## Charge et Taille tournoyante du Chevalier calciné (E6).

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


## Partie sur la Lisière calcinée, avec des bulbes ajoutés à une copie de l'arène.
func _start(pods: Array[Vector2] = []) -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"scorched_verge"
	setup.starter_id = &"ashblade"
	setup.run_seed = 4
	setup.autopilot = true
	var arena: ArenaData = GameDB.arena(&"scorched_verge").duplicate()
	arena.ember_pods = pods
	setup.arena_override = arena
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func _step(ctx: RunContext, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		ctx.time += 0.05
		if ctx.pods:
			ctx.pods.step(0.05)
		ctx.enemies.step(0.05)
		ctx.hazards.step(0.05)
		t += 0.05


## Bulbe à cet écart du départ de la carte (point « start » du décor dans le manifeste).
func _pod_near(offset: Vector2) -> Array[Vector2]:
	var start: Array = Assets.entry(&"environment.scorched_verge")["start"]
	var list: Array[Vector2] = [Vector2(start[0], start[1]) + offset]
	return list


func test_pod_is_primed_by_a_hit_then_bursts_and_regrows() -> void:
	var ctx: RunContext = _start(_pod_near(Vector2(300, 0)))
	var pod: Enemy = ctx.pods.pods[0]["enemy"]
	var golem: Enemy = ctx.enemies.spawn(GameDB.enemy(&"char_golem"), pod.position + Vector2(60, 0))
	var kills: float = ctx.stats.get_value(&"kills")
	check_eq(ctx.combat.deal_damage(pod, RunFixture.info(50.0)), 0.0, "un coup n'abîme pas le bulbe")
	check_eq(ctx.pods.pods[0]["state"], PodDirector.State.PRIMED, "il est amorcé")
	var hp: float = golem.hp
	_step(ctx, ctx.arena.pod_prime + 0.2)
	check(golem.hp < hp - ctx.arena.pod_damage, "l'éclatement ravage les Corrompus autour")
	check(pod.dormant and not pod.is_target(), "coque vide : plus une cible")
	check_eq(ctx.stats.get_value(&"kills"), kills, "aucune élimination comptée pour le bulbe")
	_step(ctx, ctx.arena.pod_regrow + 0.2)
	check_eq(ctx.pods.pods[0]["state"], PodDirector.State.IDLE, "il repousse")


func test_pod_ignores_enemy_damage() -> void:
	var ctx: RunContext = _start(_pod_near(Vector2(300, 0)))
	var pod: Enemy = ctx.pods.pods[0]["enemy"]
	var info := DamageInfo.make(20.0, DamageInfo.SourceKind.ENVIRONMENT, &"burn")
	ctx.combat.deal_damage(pod, info)
	check_eq(ctx.pods.pods[0]["state"], PodDirector.State.IDLE, "seuls le Chasseur et les Échos l'amorcent")


func test_soot_hound_leaps_onto_the_hunter() -> void:
	var ctx: RunContext = _start()
	ctx.time = 10.0
	var hound: Enemy = ctx.enemies.spawn(GameDB.enemy(&"ash_hound"), ctx.player.global_position + Vector2(260, 0))
	hound.spawn_time = 0.0
	var start: Vector2 = hound.position
	ctx.enemies.step(0.05)
	check_eq(hound.motion.get("kind", &""), &"leap", "bond lancé à portée")
	check_eq(hound.visual._current, &"leap", "animation du bond")
	_step(ctx, 0.5)
	check(hound.visual.position.y < 0.0 or hound.motion.is_empty(), "en l'air pendant le bond")
	_step(ctx, 0.6)
	check(hound.position.distance_to(ctx.player.global_position) < start.distance_to(ctx.player.global_position) - 150.0,
		"atterrit près du Chasseur")
	check_eq(hound.visual.position.y, 0.0, "au sol après le bond")


func test_cinder_knight_charges_then_spins() -> void:
	var ctx: RunContext = _start()
	ctx.time = 10.0
	var knight: Enemy = ctx.enemies.spawn(GameDB.enemy(&"cinder_knight"), ctx.player.global_position + Vector2(400, 0))
	knight.spawn_time = 0.0
	var start: Vector2 = knight.position
	ctx.enemies.step(0.05)
	check_eq(knight.motion.get("kind", &""), &"charge", "charge lancée à portée")
	var hazards: int = ctx.hazards.hazards.size()
	_step(ctx, 1.5)
	check(knight.position.distance_to(start) > 200.0, "la ruée parcourt la ligne")
	check(ctx.hazards.hazards.size() > hazards or knight.visual._current == &"spinning_slash", "taille tournoyante à l'arrivée")


func _elite(ctx: RunContext, id: StringName, offset: Vector2) -> Enemy:
	ctx.time = maxf(ctx.time, 10.0)
	var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(id), ctx.player.global_position + offset)
	enemy.spawn_time = 0.0
	return enemy


func _technique(enemy: Enemy, kind: StringName) -> EnemyTechniqueData:
	for technique: EnemyTechniqueData in enemy.data.techniques:
		if technique.kind == kind:
			return technique
	return null


func test_ashen_widow_eggs_hatch_unless_broken() -> void:
	var ctx: RunContext = _start()
	var widow: Enemy = _elite(ctx, &"ashen_widow", Vector2(500, 0))
	check(ctx.enemies._technique_lay_eggs(widow, _technique(widow, &"lay_eggs"), ctx.player.global_position), "ponte")
	check_eq(ctx.enemies._eggs.size(), 3, "trois œufs")
	var broken: Enemy = ctx.enemies._eggs[0]["egg"]
	check(broken.is_target(), "un œuf se cible et se casse")
	ctx.combat.deal_damage(broken, RunFixture.info(999.0))
	var crawlers: int = _count(ctx, &"cinder_crawler")
	_step(ctx, 5.5)
	check_eq(_count(ctx, &"cinder_crawler") - crawlers, 4, "les deux œufs restants éclosent (2 chacun)")


func _count(ctx: RunContext, id: StringName) -> int:
	var n: int = 0
	for enemy: Enemy in ctx.enemies.list:
		n += 1 if enemy.alive and enemy.data and enemy.data.id == id else 0
	return n


func test_soot_web_hinders_the_hunter() -> void:
	var ctx: RunContext = _start()
	var widow: Enemy = _elite(ctx, &"ashen_widow", Vector2(250, 0))
	ctx.enemies._technique_web(widow, _technique(widow, &"web"), ctx.player.global_position)
	for i: int in 40:
		ctx.time += 0.05
		ctx.enemies.step(0.05)
		ctx.projectiles.step(0.05)
	check(ctx.player.is_hindered(), "toile : le Chasseur est entravé")


func test_lava_lurker_burrows_and_surfaces_under_the_hunter() -> void:
	var ctx: RunContext = _start()
	var lurker: Enemy = _elite(ctx, &"lava_lurker", Vector2(400, 0))
	ctx.enemies.step(0.05)
	check_eq(lurker.motion.get("kind", &""), &"burrow", "plongée lancée")
	_step(ctx, 1.0)
	check(not lurker.visual.visible and lurker.is_invulnerable(), "sous terre : invisible et intouchable")
	_step(ctx, 1.6)
	check(lurker.visual.visible, "ressorti")
	check(lurker.position.distance_to(ctx.player.global_position) < 120.0, "sous le Chasseur")


func test_caldera_titan_opens_its_crater_after_eruption() -> void:
	var ctx: RunContext = _start()
	var titan: Enemy = _elite(ctx, &"caldera_titan", Vector2(300, 0))
	var technique: EnemyTechniqueData = _technique(titan, &"eruption")
	var hazards: int = ctx.hazards.hazards.size()
	ctx.enemies._technique_eruption(titan, technique, ctx.player.global_position)
	check_eq(ctx.hazards.hazards.size() - hazards, int(technique.params["count"]), "geysers télégraphiés")
	var armored: float = titan.get_defense()
	_step(ctx, technique.telegraph + 0.1)
	check(titan.get_defense() < armored and titan.extra_damage_taken > 1.0, "cratère ouvert : point faible")
	_step(ctx, float(technique.params["crater_window"]))
	check_eq(titan.extra_damage_taken, 1.0, "le cratère se referme")


func test_flame_wyrmling_breathes_and_dives_untouchable() -> void:
	var ctx: RunContext = _start()
	var wyrm: Enemy = _elite(ctx, &"flame_wyrmling", Vector2(150, 0))
	var before: int = ctx.hazards.hazards.size()
	ctx.enemies._technique_breath(wyrm, _technique(wyrm, &"breath"), ctx.player.global_position)
	check_eq(ctx.hazards.hazards.back()["kind"], HazardManager.Kind.CONE, "souffle en cône")
	check(ctx.hazards.hazards.size() > before, "télégraphié")
	wyrm.technique_busy = 0.0
	ctx.enemies._technique_leap(wyrm, _technique(wyrm, &"leap"), ctx.player.global_position)
	check(wyrm.is_invulnerable(), "piqué : intouchable en l'air")


func test_slag_matron_broods_then_molts() -> void:
	var ctx: RunContext = _start()
	var matron: Enemy = _elite(ctx, &"slag_matron", Vector2(300, 0))
	var mites: int = _count(ctx, &"magma_mite")
	ctx.enemies._technique_brood(matron, _technique(matron, &"brood"), ctx.player.global_position)
	_step(ctx, 1.0)
	check(_count(ctx, &"magma_mite") > mites, "couvée : acariens recrachés")
	matron.hp = matron.max_hp * 0.4
	var defense: float = matron.base_defense
	check(ctx.enemies._technique_molt(matron, _technique(matron, &"molt"), ctx.player.global_position), "mue")
	check(matron.base_defense < defense, "croûte tombée")
	ctx.player.global_position = matron.position
	ctx.burn.step(0.6)
	check(ctx.player.is_hindered(), "les scories entravent le Chasseur")
