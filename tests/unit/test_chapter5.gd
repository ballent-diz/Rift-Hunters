extends TestCase
## Chapitre 5, la Cité de la Faille (docs/design/MONSTRES.md) : Déchus, Enfants de la Faille et Statue éveillée ;
## carreau corrompu, ralliement, lien d'âme, sceau de corruption, armure de dalles, éveil des statues, onde de pierre.

const FALLEN: Array[StringName] = [&"fallen_militia", &"corrupted_hound", &"lantern_wraith", &"fallen_crossbowman",
	&"fallen_captain", &"rift_herald", &"cobble_golem"]
const RIFTBORN: Array[StringName] = [&"rift_larva", &"drifting_eye", &"void_crawler", &"torn_shade", &"portal_strider",
	&"echo_mirror", &"statue_keeper", &"awakened_statue"]

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"fractured_plain"
	setup.starter_id = &"ashblade"
	setup.run_seed = 2
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func _technique(enemy_id: StringName, kind: StringName) -> EnemyTechniqueData:
	for technique: EnemyTechniqueData in GameDB.enemy(enemy_id).techniques:
		if technique.kind == kind:
			return technique
	return null


func _advance(ctx: RunContext, seconds: float) -> void:
	var steps: int = int(ceil(seconds / 0.1))
	for i: int in steps:
		ctx.time += 0.1
		ctx.enemies.step(0.1)
		ctx.city.step(0.1)
		ctx.hazards.step(0.1)


func test_roster_families_and_sprites() -> void:
	for id: StringName in FALLEN:
		var data: EnemyData = GameDB.enemy(id)
		check(data != null and data.family == &"fallen", "%s : Déchu" % id)
		check(Assets.get_sprite_frames(StringName("enemy." + String(id))) != null, "%s : sprite" % id)
	for id: StringName in RIFTBORN:
		var data: EnemyData = GameDB.enemy(id)
		check(data != null and data.family == &"riftborn", "%s : Enfant de la Faille" % id)
		check(Assets.get_sprite_frames(StringName("enemy." + String(id))) != null, "%s : sprite" % id)
	check(GameDB.enemy(&"lantern_wraith").flying and GameDB.enemy(&"drifting_eye").flying, "deux volants")
	check(not GameDB.enemy(&"awakened_statue").can_be_elite, "la Statue n'est jamais élite")
	# Chaque animation de technique existe dans la feuille de son monstre.
	for id: StringName in FALLEN + RIFTBORN:
		for technique: EnemyTechniqueData in GameDB.enemy(id).techniques:
			if technique.anim != &"":
				var frames: SpriteFrames = Assets.get_sprite_frames(StringName("enemy." + String(id)))
				check(frames != null and frames.has_animation(technique.anim),
					"%s : animation %s" % [id, technique.anim])


func test_corrupted_bolt_fires_after_telegraph() -> void:
	var ctx: RunContext = _start()
	var shooter: Enemy = ctx.enemies.spawn(GameDB.enemy(&"fallen_crossbowman"), ctx.player.global_position + Vector2(400, 0))
	var before: int = ctx.projectiles.hostile.size()
	check(ctx.city.technique_corrupted_bolt(shooter, _technique(&"fallen_crossbowman", &"corrupted_bolt"),
		ctx.player.global_position), "il épaule")
	check_eq(ctx.projectiles.hostile.size(), before, "pas de tir pendant l'alerte")
	_advance(ctx, 1.1)
	check(ctx.projectiles.hostile.size() > before, "le carreau part")


func test_rally_speeds_up_then_wears_off() -> void:
	var ctx: RunContext = _start()
	var pos: Vector2 = ctx.player.global_position + Vector2(500, 0)
	var captain: Enemy = ctx.enemies.spawn(GameDB.enemy(&"fallen_captain"), pos)
	var militia: Enemy = ctx.enemies.spawn(GameDB.enemy(&"fallen_militia"), pos + Vector2(60, 0))
	var speed: float = militia.move_speed
	ctx.city.technique_rally(captain, _technique(&"fallen_captain", &"rally"), ctx.player.global_position)
	_advance(ctx, 1.0)
	check(militia.move_speed > speed * 1.2, "le milicien accélère")
	_advance(ctx, 5.5)
	check_near(militia.move_speed, speed, 0.01, "l'effet retombe")


func test_soul_link_shields_until_the_herald_falls() -> void:
	var ctx: RunContext = _start()
	var pos: Vector2 = ctx.player.global_position + Vector2(500, 0)
	var herald: Enemy = ctx.enemies.spawn(GameDB.enemy(&"rift_herald"), pos)
	var militia: Enemy = ctx.enemies.spawn(GameDB.enemy(&"fallen_militia"), pos + Vector2(80, 0))
	check(ctx.city.technique_soul_link(herald, _technique(&"rift_herald", &"soul_link"), ctx.player.global_position),
		"lien lancé")
	_advance(ctx, 1.0)
	check(ctx.city.linked(militia) and militia.extra_damage_taken < 0.5, "le milicien est protégé")
	herald.alive = false
	_advance(ctx, 0.2)
	check(not ctx.city.linked(militia) and is_equal_approx(militia.extra_damage_taken, 1.0), "lien rompu")


func test_corruption_seal_lingers_and_hurts() -> void:
	var ctx: RunContext = _start()
	var herald: Enemy = ctx.enemies.spawn(GameDB.enemy(&"rift_herald"), ctx.player.global_position + Vector2(300, 0))
	ctx.city.technique_corruption_seal(herald, _technique(&"rift_herald", &"corruption_seal"), ctx.player.global_position)
	_advance(ctx, 1.3)
	check(ctx.city.in_seal(ctx.player.global_position), "le sceau reste au sol")
	check(ctx.danger_vector(ctx.player.global_position + Vector2(10, 0)).length() > 0.0, "le bot en sort")
	herald.alive = false
	_advance(ctx, 5.0)
	check(not ctx.city.in_seal(ctx.player.global_position), "le sceau s'efface")


func test_slab_armor_then_exposed() -> void:
	var ctx: RunContext = _start()
	var golem: Enemy = ctx.enemies.spawn(GameDB.enemy(&"cobble_golem"), ctx.player.global_position + Vector2(400, 0))
	ctx.city.technique_slab_armor(golem, _technique(&"cobble_golem", &"slab_armor"), ctx.player.global_position)
	_advance(ctx, 1.0)
	check(golem.extra_damage_taken < 0.5, "armure de dalles")
	_advance(ctx, 4.0)
	check(golem.extra_damage_taken > 1.0, "à découvert après l'éclatement")
	_advance(ctx, 3.0)
	check(is_equal_approx(golem.extra_damage_taken, 1.0), "de retour à la normale")


func test_keeper_awakens_statues_and_casts_a_stone_wave() -> void:
	var ctx: RunContext = _start()
	var keeper: Enemy = ctx.enemies.spawn(GameDB.enemy(&"statue_keeper"), ctx.player.global_position + Vector2(500, 0))
	var technique: EnemyTechniqueData = _technique(&"statue_keeper", &"awaken_statues")
	check(ctx.city.technique_awaken_statues(keeper, technique, ctx.player.global_position), "éveil")
	_advance(ctx, 1.4)
	var statues: Array[Enemy] = []
	for enemy: Enemy in ctx.enemies.list:
		if enemy.alive and enemy.data.id == &"awakened_statue":
			statues.append(enemy)
	check_eq(statues.size(), 1, "une Statue éveillée")
	check(statues[0].invulnerable_time > 0.0, "invulnérable pendant l'éveil")
	ctx.city.technique_awaken_statues(keeper, technique, ctx.player.global_position)
	_advance(ctx, 1.4)
	check(not ctx.city.technique_awaken_statues(keeper, technique, ctx.player.global_position), "deux au plus")
	var rings: int = ctx.hazards.hazards.size()
	check(ctx.city.technique_stone_wave(keeper, _technique(&"statue_keeper", &"stone_wave"), ctx.player.global_position),
		"onde de pierre")
	check(ctx.hazards.hazards.size() > rings, "anneau au sol")
