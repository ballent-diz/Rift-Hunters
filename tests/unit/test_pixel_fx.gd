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


## Compétences (docs/design/VFX_COMPETENCES.md) : chaque effet du catalogue existe, appartient à une catégorie permise
## pour la famille du lanceur (un Corrompu de feu ne lance pas un effet d'eau) et a sa feuille dans sa palette.
func test_technique_catalog_respects_family_elements() -> void:
	var catalog: Dictionary = PixelFx.catalog()
	var effects: Dictionary = catalog["effects"]
	var common: Array = catalog["common"]
	var check_entry := func(owner: String, family: String, entry: Dictionary) -> void:
		for moment: String in entry:
			if moment in ["time", "param"]:
				continue
			var names: Array = entry[moment] if entry[moment] is Array else [entry[moment]]
			for effect: String in names:
				var source: String = str((effects.get(effect, {}) as Dictionary).get("source", "impacts/" + effect))
				var category: String = source.get_slice("/", 0)
				check(category in common or category in (catalog["allowed"][family] as Array),
					"%s (%s) : %s hors de l'élément de la famille" % [owner, family, source])
				var base: String = PixelFx.ROOT % [effect, family]
				check(ResourceLoader.exists(base + ".png"), "feuille %s/%s" % [effect, family])
	for enemy_id: String in catalog["enemies"]:
		var data: EnemyData = GameDB.enemies.get(StringName(enemy_id))
		check(data != null, "Corrompu du catalogue : %s" % enemy_id)
		if data:
			for kind: String in catalog["enemies"][enemy_id]:
				check_entry.call(enemy_id, String(data.family), catalog["enemies"][enemy_id][kind])
	for boss_id: String in catalog["boss_families"]:
		check(GameDB.boss(StringName(boss_id)) != null, "boss du catalogue : %s" % boss_id)
		var family: String = catalog["boss_families"][boss_id]
		for entry: Dictionary in (catalog["boss_common"] as Dictionary).values():
			check_entry.call(boss_id, family, entry)
		for kind: String in (catalog["bosses"] as Dictionary).get(boss_id, {}):
			check_entry.call(boss_id, family, catalog["bosses"][boss_id][kind])


func test_technique_effects_cast_impact_and_state() -> void:
	var ctx: RunContext = run.ctx
	var fx: PixelFx = ctx.pixel_fx
	fx._active.clear()
	var brute: Enemy = RunFixture.spawn(run, &"pyre_brute", Vector2(200, 0))
	fx.technique(brute, &"burn_slam")
	fx.impact(&"pyre_brute", Vector2(220, 0))
	check_eq(fx.active_count(), 1, "Bûcher écrasé : colonne de flammes à l'impact")
	fx.technique(brute, &"rage")
	check_eq(_states(fx), 2, "Rage : deux états en boucle")
	for i: int in 240:
		fx.step(1.0 / 60.0)
	check_eq(_states(fx), 2, "les états durent tant que la Brute vit")
	brute.alive = false
	fx.step(1.0 / 60.0)
	check_eq(_states(fx), 0, "à sa mort, ses états s'arrêtent")
	var before: int = fx.active_count()
	fx.technique(brute, &"unknown_kind")
	check_eq(fx.active_count(), before, "compétence sans effet prévu : rien")
	var boss_family: StringName = PixelFx.family_of(RunFixture.spawn(run, &"ash_hound", Vector2(400, 0)))
	check_eq(boss_family, &"calcines", "famille d'un Corrompu : la sienne")


func _states(fx: PixelFx) -> int:
	var count: int = 0
	for effect: Dictionary in fx._active:
		if effect.has("follow"):
			count += 1
	return count
