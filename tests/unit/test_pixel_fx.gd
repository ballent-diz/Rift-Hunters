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
		for effect: String in ["hit", "death", "ring_charge", "ring_burst", "ring_dust"]:
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


## Retour de test : les sorts de boss en cercle de 360° gardent une brèche à portée du Chasseur, et la traverser
## ne blesse pas ; charge, onde de choc et poussière pixelfx accompagnent l'anneau.
func test_boss_rings_keep_a_reachable_gap() -> void:
	var ctx: RunContext = run.ctx
	var player: Player = ctx.player
	var center: Vector2 = player.global_position + Vector2(-300, 0)
	for i: int in 20:
		var gaps: Array = ctx.hazards.fair_gaps(center, [])
		check_eq(gaps.size(), 2, "anneau plein : deux brèches")
		check(absf(wrapf(float(gaps[0]), -PI, PI)) <= HazardManager.RING_GAP_REACH, "une brèche du côté du Chasseur")
	var far: Array = ctx.hazards.fair_gaps(center, [PI])
	check(absf(wrapf(float(far[0]), -PI, PI)) <= HazardManager.RING_GAP_REACH, "brèche lointaine ramenée à portée")
	ctx.hazards.hazards.clear()
	ctx.pixel_fx._active.clear()
	ctx.hazards.add_ring(center, 400.0, 600.0, 20.0, 50.0, true, &"test_boss", [], 0.0, [], 0.5, &"givres")
	check_eq(ctx.pixel_fx.active_count(), 1, "charge jouée pendant l'annonce")
	var ring: Dictionary = ctx.hazards.hazards[0]
	ring["gaps"] = [0.0]
	var hp: float = player.hp
	for f: int in 90:
		ctx.hazards.step(1.0 / 60.0)
	check_eq(player.hp, hp, "dans la brèche : pas touché")
	check(ctx.pixel_fx.active_count() >= 2, "onde de choc et poussière le long du front")
