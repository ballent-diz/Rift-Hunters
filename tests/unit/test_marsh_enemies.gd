extends TestCase
## Chapitre 3 (docs/design/MONSTRES.md) : marque qui explose (E14), bouclier des alliés (E15), téléportation (E16),
## clones (E17), aura de soin, miroir renvoyeur, rayon qui balaie, volants et furtifs.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	run = RunFixture.create(host, &"ashblade", 3)
	return run.ctx


func _tech(enemy_id: StringName, kind: StringName) -> EnemyTechniqueData:
	for technique: EnemyTechniqueData in GameDB.enemy(enemy_id).techniques:
		if technique.kind == kind:
			return technique
	return null


func _advance(ctx: RunContext, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		ctx.time += 0.05
		ctx.enemies._step_pending_actions()
		ctx.player.step(0.05)
		ctx.hazards.step(0.05)
		t += 0.05


func test_fourteen_marsh_monsters_exist() -> void:
	for id: StringName in [&"mire_leech", &"bloat_toad", &"rift_gnat", &"creeping_root", &"spore_mother", &"bark_warden",
			&"marsh_maw", &"wandering_shard", &"glass_sentinel", &"quartz_golem", &"creeping_mirror", &"mirror_priestess",
			&"crystal_colossus", &"reflection_huntress"]:
		check(GameDB.enemy(id) != null, "%s en données" % id)


func test_mark_explodes_unless_dashed() -> void:
	var ctx: RunContext = _start()
	var mother: Enemy = ctx.enemies.spawn(GameDB.enemy(&"spore_mother"), ctx.player.global_position + Vector2(300, 0))
	check(ctx.enemies.marsh.technique_mark(mother, _tech(&"spore_mother", &"mark"), ctx.player.global_position), "marque lancée")
	_advance(ctx, 0.8)
	check(ctx.player.is_marked(), "le Chasseur est marqué")
	var hp: float = ctx.player.hp
	_advance(ctx, 3.2)
	check(not ctx.player.is_marked() and ctx.player.hp < hp, "la marque explose")
	ctx.player.mark(2.0, 30.0, 100.0, &"test")
	ctx.player._start_dash(Vector2.RIGHT)
	_advance(ctx, 0.1)
	check(not ctx.player.is_marked(), "la Ruée efface la marque")


func test_bark_shield_protects_allies_until_the_warden_dies() -> void:
	var ctx: RunContext = _start()
	var pos: Vector2 = ctx.player.global_position + Vector2(400, 0)
	var warden: Enemy = ctx.enemies.spawn(GameDB.enemy(&"bark_warden"), pos)
	var leech: Enemy = ctx.enemies.spawn(GameDB.enemy(&"mire_leech"), pos + Vector2(60, 0))
	check(ctx.enemies.marsh.technique_ally_shield(warden, _tech(&"bark_warden", &"ally_shield"), ctx.player.global_position),
		"bouclier levé")
	check_eq(ctx.combat.deal_damage(leech, RunFixture.info(5.0)), 0.0, "allié protégé")
	ctx.combat.deal_damage(warden, RunFixture.info(999999.0))
	check(ctx.combat.deal_damage(leech, RunFixture.info(5.0)) > 0.0, "le bouclier tombe avec le gardien")


func test_blink_lands_beside_the_hunter() -> void:
	var ctx: RunContext = _start()
	var mirror: Enemy = ctx.enemies.spawn(GameDB.enemy(&"creeping_mirror"), ctx.player.global_position + Vector2(450, 0))
	ctx.enemies.marsh.technique_blink(mirror, _tech(&"creeping_mirror", &"blink"), ctx.player.global_position)
	_advance(ctx, 0.2)
	check(mirror.position.distance_to(ctx.player.global_position) < 200.0, "réapparaît sur un flanc du Chasseur")


func test_clones_are_fragile_and_vanish() -> void:
	var ctx: RunContext = _start()
	var priestess: Enemy = ctx.enemies.spawn(GameDB.enemy(&"mirror_priestess"), ctx.player.global_position + Vector2(400, 0))
	var before: int = ctx.enemies.count()
	ctx.enemies.marsh.technique_clones(priestess, _tech(&"mirror_priestess", &"clones"), ctx.player.global_position)
	_advance(ctx, 1.0)
	check_eq(ctx.enemies.count(), before + 2, "deux reflets")
	var clone: Enemy = ctx.enemies.list.back()
	check(clone.is_clone and clone.max_hp < priestess.max_hp * 0.2, "reflet fragile")
	ctx.time = clone.clone_until + 0.1
	ctx.enemies.step(0.016)
	check_eq(ctx.enemies.count(), before, "les reflets se dissipent")


func test_reflect_sends_frontal_shots_back() -> void:
	var ctx: RunContext = _start()
	var priestess: Enemy = ctx.enemies.spawn(GameDB.enemy(&"mirror_priestess"), ctx.player.global_position + Vector2(300, 0))
	ctx.enemies.marsh.technique_reflect(priestess, _tech(&"mirror_priestess", &"reflect"), ctx.player.global_position)
	check(ctx.enemies.marsh.reflects(priestess, priestess.position + Vector2(-20, 0), 10.0), "tir de face renvoyé")
	check(not ctx.enemies.marsh.reflects(priestess, priestess.position + Vector2(20, 0), 10.0), "pas par derrière")


func test_heal_aura_mends_nearby_corrupted() -> void:
	var ctx: RunContext = _start()
	var pos: Vector2 = ctx.player.global_position + Vector2(400, 0)
	var mother: Enemy = ctx.enemies.spawn(GameDB.enemy(&"spore_mother"), pos)
	var toad: Enemy = ctx.enemies.spawn(GameDB.enemy(&"bloat_toad"), pos + Vector2(50, 0))
	toad.hp = toad.max_hp * 0.5
	ctx.enemies.marsh.technique_heal_aura(mother, _tech(&"spore_mother", &"heal_aura"), ctx.player.global_position)
	check(toad.hp > toad.max_hp * 0.5, "soigné")


func test_flyers_ignore_scenery_and_stealth_hides() -> void:
	var ctx: RunContext = _start()
	check(GameDB.enemy(&"rift_gnat").flying, "moustique volant")
	var huntress: Enemy = ctx.enemies.spawn(GameDB.enemy(&"reflection_huntress"), ctx.player.global_position + Vector2(600, 0))
	check(ctx.enemies.marsh.hidden(huntress), "invisible de loin")
	check(ctx.enemies.find_nearest(ctx.player.global_position, 900.0) != huntress, "impossible à viser de loin")
	huntress.position = ctx.player.global_position + Vector2(150, 0)
	check(not ctx.enemies.marsh.hidden(huntress), "visible de près")


func test_colossus_sweep_then_weak_window() -> void:
	var ctx: RunContext = _start()
	var colossus: Enemy = ctx.enemies.spawn(GameDB.enemy(&"crystal_colossus"), ctx.player.global_position + Vector2(350, 0))
	ctx.enemies.marsh.technique_sweep_beam(colossus, _tech(&"crystal_colossus", &"sweep_beam"), ctx.player.global_position)
	_advance(ctx, 2.8)
	check(colossus.extra_damage_taken > 1.0, "cœur à nu après le rayon")
