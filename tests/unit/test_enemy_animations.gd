extends TestCase
## Rangées des feuilles d'ennemis jouées en jeu : attaque au contact (mêlée), mort visible puis retirée.

var run: RunController


func before_each() -> void:
	run = RunFixture.create(host)


func after_each() -> void:
	RunFixture.dispose(run)


func _current(enemy: Enemy) -> StringName:
	return enemy.visual._current


func test_melee_contact_plays_attack() -> void:
	var enemy: Enemy = RunFixture.spawn(run, &"heath_runner", Vector2(10, 0))
	check(enemy.visual.has_animation(&"attack"), "feuille avec rangée d'attaque")
	enemy.touch_cooldown = 0.0
	run.ctx.enemies.step(0.016)
	check_eq(_current(enemy), &"attack", "attaque jouée au contact")


func test_death_is_shown_then_removed() -> void:
	var enemy: Enemy = RunFixture.spawn(run, &"heath_runner", Vector2(120, 0))
	check(enemy.visual.has_animation(&"death"), "feuille avec rangée de mort")
	run.ctx.combat.deal_damage(enemy, RunFixture.info(99999.0))
	run.ctx.enemies.step(0.016)
	check(not run.ctx.enemies.list.has(enemy), "le mort quitte la simulation")
	check(is_instance_valid(enemy) and not enemy.is_queued_for_deletion(), "son corps reste affiché")
	check_eq(_current(enemy), &"death", "animation de mort")
	for i: int in 120:
		run.ctx.enemies.step(0.016)
	check(not is_instance_valid(enemy) or enemy.is_queued_for_deletion(), "corps retiré après le fondu")


func test_corpses_are_capped() -> void:
	for i: int in EnemyManager.MAX_CORPSES + 10:
		var enemy: Enemy = RunFixture.spawn(run, &"heath_runner", Vector2(80 + i, 40))
		run.ctx.combat.deal_damage(enemy, RunFixture.info(99999.0))
	run.ctx.enemies.step(0.016)
	check(run.ctx.enemies._corpses.size() <= EnemyManager.MAX_CORPSES, "plafond des corps affichés")
