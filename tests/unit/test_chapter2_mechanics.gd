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
