extends TestCase
## Élites du chapitre 1 (docs/ROADMAP.md, décision du 2 novembre 2026) : Saut (E1) pour la Chimère des sommets et le
## Chevalier fulgurant, Tunnel (E2) pour le Gardien des menhirs et la Couveuse. Le tunnel ne traverse ni mur ni barrière.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	run = RunFixture.create(host, &"ashblade")
	run.set_physics_process(false)
	return run.ctx


func _elite(ctx: RunContext, id: StringName, offset: Vector2) -> Enemy:
	ctx.time = maxf(ctx.time, 10.0)
	var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(id), ctx.player.global_position + offset)
	enemy.spawn_time = 0.0
	return enemy


func _step(ctx: RunContext, seconds: float, each: Callable = Callable()) -> void:
	var t: float = 0.0
	while t < seconds:
		ctx.time += 0.05
		ctx.enemies.step(0.05)
		ctx.hazards.step(0.05)
		if each.is_valid():
			each.call()
		t += 0.05


func test_four_elites_have_their_technique() -> void:
	for pair: Array in [[&"peak_chimera", &"leap"], [&"storm_knight", &"leap"], [&"menhir_warden", &"burrow"],
			[&"broodmother", &"burrow"]]:
		var data: EnemyData = GameDB.enemy(pair[0])
		check_eq(data.techniques.size(), 1, "%s : une technique" % pair[0])
		check_eq(data.techniques[0].kind, pair[1], "%s : %s" % [pair[0], pair[1]])
		check(data.techniques[0].telegraph >= 0.5, "%s : alerte lisible au chapitre 1" % pair[0])


func test_storm_knight_leaps_onto_the_hunter() -> void:
	var ctx: RunContext = _start()
	var knight: Enemy = _elite(ctx, &"storm_knight", Vector2(300, 0))
	var hazards: int = ctx.hazards.hazards.size()
	ctx.enemies.step(0.05)
	check_eq(knight.motion.get("kind", &""), &"leap", "bond lancé")
	check(ctx.hazards.hazards.size() > hazards, "zone d'impact annoncée dès le départ")
	_step(ctx, 1.4)
	check(knight.position.distance_to(ctx.player.global_position) < 160.0, "atterri près du Chasseur")


func test_menhir_warden_tunnels_without_crossing_a_wall() -> void:
	var ctx: RunContext = _start()
	var origin: Vector2 = ctx.player.global_position
	ctx.obstacles.add_wall(Rect2(origin + Vector2(160, -400), Vector2(60, 800)))
	var warden: Enemy = _elite(ctx, &"menhir_warden", Vector2(420, 0))
	ctx.enemies.step(0.05)
	check_eq(warden.motion.get("kind", &""), &"burrow", "tunnel lancé")
	var crossed: Array[bool] = [false]
	_step(ctx, 3.0, func() -> void:
		if warden.position.x < origin.x + 220.0:
			crossed[0] = true)
	check(not crossed[0], "sous terre, il bute contre le mur au lieu de le traverser")
	check(warden.visual.visible, "il ressort")


func test_broodmother_tunnels_under_the_hunter() -> void:
	var ctx: RunContext = _start()
	var brood: Enemy = _elite(ctx, &"broodmother", Vector2(-380, 0))
	ctx.enemies.step(0.05)
	check_eq(brood.motion.get("kind", &""), &"burrow", "tunnel lancé")
	_step(ctx, 0.9)
	check(not brood.visual.visible and brood.is_invulnerable(), "sous terre : invisible et intouchable")
	_step(ctx, 2.0)
	check(brood.visual.visible and brood.position.distance_to(ctx.player.global_position) < 140.0,
		"ressortie sous le Chasseur")
