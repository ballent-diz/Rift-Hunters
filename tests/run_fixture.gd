class_name RunFixture
extends RefCounted
## Crée une partie contrôlée pour les tests (pas de boucle automatique : on appelle step à la main).

## `decor` : garde les obstacles du décor (par défaut retirés : les tests de gameplay ne dépendent pas du dessin
## de la map).
static func create(host: Node, starter: StringName = &"", run_seed: int = 7, decor: bool = false) -> RunController:
	var setup := RunSetup.new()
	setup.starter_id = starter
	setup.run_seed = run_seed
	setup.autopilot = true
	setup.unlocked_monsters = GameDB.sorted_ids(GameDB.monsters)
	var run: RunController = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	if not decor:
		run.ctx.obstacles = ObstacleField.new()
	return run


static func spawn(run: RunController, enemy_id: StringName, offset: Vector2 = Vector2(100, 0)) -> Enemy:
	return run.ctx.enemies.spawn(GameDB.enemy(enemy_id), run.ctx.player.global_position + offset)


static func info(amount: float, source: StringName = &"player") -> DamageInfo:
	var kind := DamageInfo.SourceKind.PLAYER if source == &"player" else DamageInfo.SourceKind.ALLY
	var tags: Array[StringName] = [DamageInfo.TAG_ATTACK]
	return DamageInfo.make(amount, kind, source, tags)


static func dispose(run: RunController) -> void:
	run.get_tree().paused = false
	run.queue_free()
