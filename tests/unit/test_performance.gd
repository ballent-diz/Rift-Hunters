extends TestCase
## Charge élevée : 450 ennemis + 300 projectiles. Mesure le temps de simulation par frame (sans rendu).

## Budget de simulation (sans rendu) sur une machine de test modeste ; 16,6 ms par frame à 60 FPS.
const BUDGET_MS := 10.0

var run: RunController


func before_each() -> void:
	run = RunFixture.create(host, &"mossback")


func after_each() -> void:
	RunFixture.dispose(run)


func test_dense_crowd_step_time() -> void:
	var ctx: RunContext = run.ctx
	ctx.player.god_mode = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var ids: Array[StringName] = [&"skitterling", &"husk", &"spitter", &"lunger"]
	for i: int in 450:
		var offset := Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(80.0, 700.0)
		RunFixture.spawn(run, ids[i % ids.size()], offset)
	for i: int in 300:
		var tags: Array[StringName] = [DamageInfo.TAG_BOLT]
		ctx.projectiles.spawn_friendly(ctx.player.global_position, Vector2.RIGHT.rotated(rng.randf() * TAU), 500.0,
			DamageInfo.make(1.0, DamageInfo.SourceKind.PLAYER, &"player", tags), {"life": 3.0, "pierce": 3})
	var delta: float = 1.0 / 60.0
	for i: int in 10:
		_step(ctx, delta)
	var start: int = Time.get_ticks_usec()
	var frames: int = 120
	for i: int in frames:
		for k: int in 6:
			var tags: Array[StringName] = [DamageInfo.TAG_BOLT]
			ctx.projectiles.spawn_friendly(ctx.player.global_position, Vector2.RIGHT.rotated(rng.randf() * TAU), 500.0,
				DamageInfo.make(1.0, DamageInfo.SourceKind.PLAYER, &"player", tags), {"life": 1.2, "pierce": 2})
		_step(ctx, delta)
	var avg_ms: float = (Time.get_ticks_usec() - start) / 1000.0 / frames
	print("    Charge : %d ennemis, %d projectiles → %.2f ms/frame (budget %.0f ms)" % [ctx.enemies.count(),
		ctx.projectiles.friendly.size(), avg_ms, BUDGET_MS])
	check(avg_ms < BUDGET_MS, "simulation trop lente : %.2f ms/frame" % avg_ms)


func _step(ctx: RunContext, delta: float) -> void:
	ctx.time += delta
	ctx.player.step(delta)
	ctx.allies.step(delta)
	ctx.enemies.step(delta)
	ctx.projectiles.step(delta)
	ctx.pickups.step(delta)
	ctx.hazards.step(delta)
	ctx.combat.flush_queue()
	ctx.fx.step(delta)
