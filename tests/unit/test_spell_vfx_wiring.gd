extends TestCase
## Les scènes déjà livrées doivent apparaître lors des vrais lancers, sans changer leurs règles.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func test_every_echo_casts_both_painted_spells() -> void:
	var count: int = 0
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		run = RunFixture.create(host, id)
		var ctx: RunContext = run.ctx
		var ally: Ally = ctx.allies.get_ally(id)
		var techniques: Array[TechniqueData] = [ally.technique]
		var alt: SkillNodeData = EchoTree.node(StringName(String(id) + "_spell_alt"))
		if alt:
			techniques.append(GameDB.techniques[alt.spell_id])
		for tech: TechniqueData in techniques:
			var enemy: Enemy = RunFixture.spawn(run, &"husk", Vector2(100, 0))
			enemy.max_hp = 100000.0
			enemy.hp = enemy.max_hp
			ctx.status_system.apply(enemy, &"mark", 1, id)
			ally.technique = tech
			ally.technique_cd = 0.0
			check(Techniques.cast(ally, ctx, enemy.position), "%s/%s : lancé" % [id, tech.id])
			check(ctx.allies.vfx.layer.get_child_count() > 0, "%s/%s : animation réellement créée" % [id, tech.id])
			check(ally.technique_cd > 0.0, "%s/%s : recharge conservée" % [id, tech.id])
			if tech.technique_kind == &"ash_dance":
				var fx: Node2D = ctx.allies.vfx.layer.get_child(0)
				check(float(fx.get("radius")) <= 48.0, "l’entaille ne prend pas la taille du rayon de sélection")
			ctx.allies.vfx.clear()
			await host.get_tree().process_frame
			count += 1
		RunFixture.dispose(run)
		run = null
		await host.get_tree().process_frame
	check_eq(count, 32, "les deux sorts des seize Échos sont vérifiés")


func test_reflection_follows_the_hunter_and_ends() -> void:
	run = RunFixture.create(host, &"mirrorling")
	var ctx: RunContext = run.ctx
	var ally: Ally = ctx.allies.get_ally(&"mirrorling")
	check(Techniques.cast(ally, ctx, ctx.player.position), "Reflet lancé")
	var fx: Node2D = ctx.allies.vfx.layer.get_child(0)
	ctx.player.position += Vector2(80, 50)
	ctx.allies.vfx.layer.call("_process", 0.0)
	check_eq(fx.global_position, ctx.player.global_position, "le bouclier reste sur la zone réellement protégée")
	check(not bool(fx.get("loop_visual")), "un sort fini ne boucle pas indéfiniment")
	fx.call("_process", ally.technique.duration + 0.1)
	await host.get_tree().process_frame
	check_eq(ctx.allies.vfx.layer.get_child_count(), 0, "le bouclier disparaît à la fin du sort")


func test_ash_dance_without_target_does_not_animate_or_start_cooldown() -> void:
	run = RunFixture.create(host, &"ashblade")
	var ctx: RunContext = run.ctx
	var ally: Ally = ctx.allies.get_ally(&"ashblade")
	check(not Techniques.cast(ally, ctx, ctx.player.position), "aucune cible : lancer refusé")
	check_eq(ctx.allies.vfx.layer.get_child_count(), 0, "aucune animation trompeuse")
	check_eq(ally.technique_cd, 0.0, "aucune recharge consommée")


func test_original_mirror_and_devour_attacks_use_their_painted_scenes() -> void:
	for id: StringName in [&"mirrorling", &"gloommaw"]:
		run = RunFixture.create(host, id)
		var ctx: RunContext = run.ctx
		var ally: Ally = ctx.allies.get_ally(id)
		var enemy: Enemy = RunFixture.spawn(run, &"husk", Vector2(40, 0))
		ally.position = enemy.position + Vector2(-10, 0)
		ally.attack_cd = 0.0
		ally.behavior.tick(ally, ctx, 0.01)
		check(ctx.allies.vfx.layer.get_child_count() > 0, "%s : attaque peinte déclenchée" % id)
		RunFixture.dispose(run)
		run = null
		await host.get_tree().process_frame
