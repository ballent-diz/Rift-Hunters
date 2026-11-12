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
	check_eq(families.size(), 10, "dix familles")
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
			if moment in ["time", "param", "at"]:
				continue
			var names: Array = entry[moment] if entry[moment] is Array else [entry[moment]]
			for effect: String in names:
				var source: String = str((effects.get(effect, {}) as Dictionary).get("source", "impacts/" + effect))
				var category: String = source.get_slice("/", 0)
				var allowed: bool = "%s/%s" % [owner, effect] in (catalog.get("exceptions", []) as Array)
				check(allowed or category in common or category in (catalog["allowed"][family] as Array),
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


## Armure qui se fend (E8, Gardien d'écorce) : son bouclier tombé, il encaisse davantage quelques secondes.
func test_bark_warden_armor_cracks_after_its_shield() -> void:
	var warden: Enemy = RunFixture.spawn(run, &"bark_warden", Vector2(150, 0))
	RunFixture.spawn(run, &"mire_leech", Vector2(190, 0))
	var shield: EnemyTechniqueData = warden.data.techniques[1]
	check(run.ctx.enemies.marsh.technique_ally_shield(warden, shield, Vector2.ZERO), "bouclier levé")
	var duration: float = float(shield.params["duration"])
	for i: int in int((duration + 0.5) * 60.0):
		run.ctx.time += 1.0 / 60.0
		run.ctx.enemies.step(1.0 / 60.0)
	check_eq(warden.extra_damage_taken, 1.5, "écorce fendue : dégâts subis × 1,5")
	for i: int in int(3.5 * 60.0):
		run.ctx.time += 1.0 / 60.0
		run.ctx.enemies.step(1.0 / 60.0)
	check_eq(warden.extra_damage_taken, 1.0, "puis l'écorce se referme")


func test_floe_colossus_uses_its_ice_family_and_signature() -> void:
	var boss: Enemy = run.ctx.enemies.spawn_boss(GameDB.boss(&"floe_colossus"), Vector2(200, 0))
	check_eq(PixelFx.family_of(boss), &"silence", "le Colosse utilise la palette de son corps, pas le violet par défaut")
	var fx: PixelFx = run.ctx.pixel_fx
	fx._active.clear()
	fx.technique(boss, &"floe_quake")
	fx.impact(&"floe_colossus", Vector2(220, 30))
	check_eq(fx.active_count(), 1, "éclatement de glace au point de frappe")
	check_eq(fx._active[0]["pos"], Vector2(220, 30), "impact localisé")


func test_projectile_fallback_preserves_explicit_assignments_and_ignores_unknown_sources() -> void:
	var fx: PixelFx = run.ctx.pixel_fx
	fx._active.clear()
	for id: StringName in [&"rime_archer", &"floe_colossus", &"abyssarch"]:
		fx.shot(id, Vector2(100, 20))
	check_eq(fx.active_count(), 3, "tirs de monstres et de boss couverts")
	fx.shot(&"source_inconnue", Vector2.ZERO)
	check_eq(fx.active_count(), 3, "aucun effet inventé pour une source inconnue")
	var catalog: Dictionary = PixelFx.catalog()
	for family: String in catalog["shots"]:
		var effect: String = catalog["shots"][family]
		var category: String = str(catalog["effects"][effect]["source"]).get_slice("/", 0)
		check(category in catalog["common"] or category in catalog["allowed"][family], "impact dans son élément")
		check(ResourceLoader.exists(PixelFx.ROOT % [effect, family] + ".png"), "feuille d'impact livrée")


func test_beam_waits_for_telegraph_keeps_its_kind_and_ends() -> void:
	var ctx: RunContext = run.ctx
	var fx: PixelFx = ctx.pixel_fx
	fx._active.clear()
	var origin: Vector2 = ctx.player.position + Vector2(300, 300)
	ctx.hazards.add_beam(origin, Vector2.UP, 300.0, 40.0, 0.2, 0.5, 10.0, &"nivorath", &"breath")
	ctx.hazards.step(0.1)
	check_eq(fx.active_count(), 0, "aucun souffle avant la fin de l'annonce")
	var boss: Enemy = ctx.enemies.spawn_boss(GameDB.boss(&"nivorath"), origin)
	fx.technique(boss, &"ice_spikes")
	ctx.hazards.step(0.11)
	ctx.hazards.step(0.01)
	check_eq(fx.active_count(), 1, "le rayon crée une animation malgré le changement de motif du boss")
	if fx.active_count() == 1:
		check_near(float(fx._active[0]["rotation"]), -PI * 0.5, 0.001, "souffle dirigé vers le haut")
		check_eq(fx._active[0]["pos"], origin, "départ au point réel du rayon")
	ctx.hazards.step(0.1)
	check_eq(fx.active_count(), 1, "pas une nouvelle animation par tick de dégâts")
	fx.step(0.6)
	check_eq(fx.active_count(), 0, "fin avec le rayon")


func test_beam_stops_at_cover_and_keeps_visible_fallback_when_budget_is_full() -> void:
	var ctx: RunContext = run.ctx
	var fx: PixelFx = ctx.pixel_fx
	var origin: Vector2 = ctx.player.position + Vector2(300, 200)
	ctx.obstacles.add(origin + Vector2(120, 0), 40.0)
	ctx.hazards.add_beam(origin, Vector2.RIGHT, 400.0, 30.0, 0.0, 0.8, 10.0, &"abyssarch", &"breath")
	var h: Dictionary = ctx.hazards.hazards.back()
	var length: float = h["length"]
	check(length > 0.0 and length < 120.0, "la portée s'arrête devant l'abri")
	fx._active.clear()
	ctx.hazards.step(0.01)
	check(bool(h.get("painted", false)), "le rayon PixelFX remplace le trait générique actif")
	check_near((fx._active[0]["stretch"] as Vector2).x, length / 168.0, 0.001, "image à la portée réellement libre")
	fx._active.clear()
	for i: int in PixelFx.MAX_ACTIVE:
		fx.play(&"hit", &"violet", origin)
	ctx.hazards.add_beam(origin, Vector2.RIGHT, 400.0, 30.0, 0.0, 0.8, 10.0, &"abyssarch", &"breath")
	ctx.hazards.step(0.01)
	check_eq(fx.active_count(), PixelFx.MAX_ACTIVE, "plafond partagé conservé")
	check(not bool(ctx.hazards.hazards.back().get("painted", false)), "le trait du jeu reste visible si le budget est plein")


func test_all_families_have_elemental_projectile_art_and_pool_reuse_clears_it() -> void:
	var ctx: RunContext = run.ctx
	var catalog: Dictionary = PixelFx.catalog()
	for family: String in catalog["flights"]:
		var effect: String = catalog["flights"][family]
		var spec: Dictionary = catalog["effects"][effect]
		var category: String = str(spec["source"]).get_slice("/", 0)
		check(category in catalog["common"] or category in catalog["allowed"][family], "projectile dans son élément")
		check(ResourceLoader.exists(PixelFx.ROOT % [effect, family] + ".png"), "feuille de projectile livrée")
	var shot: Projectile = ctx.projectiles.spawn_hostile(ctx.player.position + Vector2(200, 0), Vector2.LEFT,
		200.0, 10.0, &"rime_archer")
	check(not shot.pixel_art.is_empty(), "la vraie flèche ennemie reçoit sa feuille")
	ctx.projectiles.step(0.1)
	check_near(shot.visual_time, 0.1, 0.001, "animation avancée avec le projectile")
	check(shot.pixel_art.get("directional", false), "la flèche suit la direction du tir")
	ctx.projectiles.clear_hostile()
	var friendly: Projectile = ctx.projectiles.spawn_friendly(ctx.player.position, Vector2.RIGHT, 200.0,
		RunFixture.info(5.0))
	check(friendly == shot, "objet réutilisé depuis le pool")
	check(friendly.pixel_art.is_empty(), "un tir allié ne récupère pas le dessin ennemi précédent")
	check_eq(friendly.visual_time, 0.0, "temps graphique réinitialisé")
	check(ctx.pixel_fx.projectile_art(&"source_inconnue").is_empty(), "source inconnue : dessin de secours du jeu")


func test_existing_painted_boss_beam_keeps_its_scene_priority() -> void:
	var ctx: RunContext = run.ctx
	ctx.pixel_fx._active.clear()
	ctx.hazards.add_beam(ctx.player.position + Vector2(300, 300), Vector2.UP, 300.0, 40.0, 0.0, 0.5,
		10.0, &"source_devourer", &"breath")
	ctx.hazards.mark_last_painted()
	ctx.hazards.step(0.01)
	check(bool(ctx.hazards.hazards.back().get("painted", false)), "le rayon peint garde la main sur son dessin")
	check_eq(ctx.pixel_fx.active_count(), 0, "aucune animation PixelFX superposée à la scène peinte")
