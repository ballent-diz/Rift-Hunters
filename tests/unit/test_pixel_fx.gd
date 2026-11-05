extends TestCase
## Effets génériques pixelfx (impact, disparition) aux couleurs de la famille de chaque Corrompu.

var run: RunController


func before_each() -> void:
	run = RunFixture.create(host, &"mossback")


func after_each() -> void:
	RunFixture.dispose(run)


func test_every_corrupted_has_a_family_with_its_sheets() -> void:
	var families: Dictionary = {}
	for enemy: EnemyData in GameDB.enemies.values():
		if enemy.id == &"training_dummy":
			continue
		check(enemy.family != &"", "%s : famille renseignée" % enemy.id)
		families[enemy.family] = true
	check_eq(families.size(), 8, "huit familles")
	for family: StringName in families:
		for effect: String in ["hit", "death"]:
			var base: String = PixelFx.ROOT % [effect, family]
			check(ResourceLoader.exists(base + ".png") and FileAccess.file_exists(base + ".json"),
				"feuille %s/%s" % [effect, family])


func test_hits_are_throttled_and_effects_end() -> void:
	var ctx: RunContext = run.ctx
	var enemy: Enemy = RunFixture.spawn(run, &"skitterling", Vector2(120, 0))
	ctx.pixel_fx.hit(enemy)
	ctx.pixel_fx.hit(enemy)
	check_eq(ctx.pixel_fx.active_count(), 1, "un seul impact par Corrompu dans le même instant")
	ctx.pixel_fx.death(enemy)
	check_eq(ctx.pixel_fx.active_count(), 2, "disparition affichée")
	for i: int in 120:
		ctx.pixel_fx.step(1.0 / 60.0)
	check_eq(ctx.pixel_fx.active_count(), 0, "les effets se terminent")
	check_eq(PixelFx.family_of(enemy), &"violet", "le Grouillard est de la famille violette")
