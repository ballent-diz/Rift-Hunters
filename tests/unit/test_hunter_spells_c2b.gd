extends TestCase
## Sorts du lot C2b (Bond, Parade, Rupture, Cristal, Singularité, Mur, Failles, Appel, Égide, Permutation),
## leurs variantes, les passifs transformants et les clés de voûte.

var run: RunController


func before_each() -> void:
	run = RunFixture.create(host, &"mossback")


func after_each() -> void:
	RunFixture.dispose(run)


func _equip(spell_id: StringName, variant: StringName = &"") -> HunterSpells:
	var spells: HunterSpells = run.ctx.spells
	spells.slots[0] = GameDB.spells[spell_id]
	spells.variants[0] = variant
	spells.cooldowns[0] = 0.0
	return spells


func _pos(offset: Vector2) -> Vector2:
	return run.ctx.player.global_position + offset


func _hurt(enemy: Enemy) -> bool:
	return not enemy.alive or enemy.hp < enemy.max_hp


func _steps(seconds: float) -> void:
	for i: int in int(seconds * 60.0):
		run.ctx.time += 1.0 / 60.0
		run.ctx.player.step(1.0 / 60.0)
		run.ctx.spells.step(1.0 / 60.0)
		run.ctx.projectiles.step(1.0 / 60.0)
		run.ctx.hazards.step(1.0 / 60.0)
	run.ctx.combat.flush_queue()


func test_leap_moves_hunter_and_shocks_on_landing() -> void:
	var spells: HunterSpells = _equip(&"rift_leap")
	var target: Vector2 = _pos(Vector2(300, 0))
	var enemy: Enemy = RunFixture.spawn(run, &"husk", Vector2(320, 0))
	check(spells.cast(0, target), "Bond lancé")
	check(not run.ctx.player.can_be_hurt(), "invulnérable pendant le saut")
	_steps(0.27)
	check(run.ctx.player.global_position.distance_to(target) < 20.0, "le Chasseur atterrit au curseur")
	check(_hurt(enemy), "onde de choc à l'arrivée")


func test_leap_never_crosses_a_barrier() -> void:
	var spells: HunterSpells = _equip(&"rift_leap")
	var start: Vector2 = run.ctx.player.global_position
	run.ctx.obstacles.add_wall(Rect2(start + Vector2(140, -200), Vector2(40, 400)))
	spells.cast(0, start + Vector2(350, 0))
	_steps(0.4)
	check(run.ctx.player.global_position.x < start.x + 140.0, "le Bond s'arrête avant la barrière")


func test_leap_return_variant() -> void:
	var spells: HunterSpells = _equip(&"rift_leap", &"return")
	var start: Vector2 = run.ctx.player.global_position
	spells.cast(0, start + Vector2(250, 0))
	_steps(0.4)
	var cooldown: float = spells.cooldowns[0]
	check(spells.cast(0, start + Vector2(500, 0)), "second appui : retour")
	_steps(0.27)
	check(run.ctx.player.global_position.distance_to(start) < 20.0, "retour au point de départ")
	check(spells.cooldowns[0] <= cooldown, "le retour ne relance pas la recharge")


func test_parry_cancels_hit_and_counters() -> void:
	var spells: HunterSpells = _equip(&"parry")
	var enemy: Enemy = RunFixture.spawn(run, &"husk", Vector2(60, 0))
	var hp: float = run.ctx.player.hp
	check(spells.cast(0, _pos(Vector2(50, 0))), "Parade lancée")
	check_eq(run.ctx.combat.damage_player(20.0, &"husk"), 0.0, "coup paré")
	run.ctx.combat.flush_queue()
	check_eq(run.ctx.player.hp, hp, "aucun dégât")
	check(_hurt(enemy), "contre-attaque")
	if enemy.alive:
		check(enemy.statuses.get_stacks(&"root") > 0, "ennemi étourdi")
	check_eq(spells.cooldowns[0], 0.0, "recharge remise à zéro")


func test_rupture_detonates_marks_and_reaction_spreads() -> void:
	var spells: HunterSpells = _equip(&"rupture", &"reaction")
	var marked: Enemy = RunFixture.spawn(run, &"husk", Vector2(200, 0))
	var neighbour: Enemy = RunFixture.spawn(run, &"husk", Vector2(260, 0))
	run.ctx.status_system.apply(marked, &"mark", 2, &"player")
	check(spells.cast(0, marked.global_position), "Rupture lancée")
	run.ctx.combat.flush_queue()
	check(_hurt(marked), "détonation")
	check_eq(marked.statuses.get_stacks(&"mark") if marked.alive else 0, 0, "Marques consommées")
	check(neighbour.statuses.get_stacks(&"mark") > 0, "Réaction : Marque posée à côté")


func test_crystal_splits_friendly_shots() -> void:
	var spells: HunterSpells = _equip(&"refracting_crystal")
	var crystal: Vector2 = _pos(Vector2(150, 0))
	spells.cast(0, crystal)
	var info: DamageInfo = RunFixture.info(5.0)
	run.ctx.projectiles.spawn_friendly(_pos(Vector2.ZERO), Vector2.RIGHT, 600.0, info, {"life": 1.0})
	var before: int = run.ctx.projectiles.friendly.size()
	_steps(0.3)
	check(run.ctx.projectiles.friendly.size() >= before + 2, "le tir se divise en 3")


func test_singularity_creates_well_and_horizon_amplifies() -> void:
	var spells: HunterSpells = _equip(&"singularity", &"horizon")
	var enemy: Enemy = RunFixture.spawn(run, &"husk", Vector2(200, 0))
	var before: int = run.ctx.hazards.hazards.size()
	spells.cast(0, enemy.global_position)
	check_eq(run.ctx.hazards.hazards.size(), before + 1, "puits créé")
	check_eq(spells.world._horizon_modifier(enemy, RunFixture.info(1.0)), 1.15, "Horizon : +15 % de dégâts subis")


func test_wall_blocks_then_disappears() -> void:
	var spells: HunterSpells = _equip(&"rift_wall")
	var center: Vector2 = _pos(Vector2(200, 0))
	spells.cast(0, center)
	check(run.ctx.obstacles.blocks(center, 4.0), "le mur bloque")
	check(spells.blocks_projectile(center), "le mur arrête les projectiles ennemis")
	_steps(4.2)
	check(not run.ctx.obstacles.blocks(center, 4.0), "le mur disparaît après 4 s")


func test_twin_rifts_teleport_shots() -> void:
	var spells: HunterSpells = _equip(&"twin_rifts")
	var entrance: Vector2 = _pos(Vector2(120, 0))
	var exit_point: Vector2 = _pos(Vector2(0, 400))
	check(spells.cast(0, entrance), "entrée posée")
	check(spells.cast(0, exit_point), "sortie posée (appui gratuit)")
	var p: Projectile = run.ctx.projectiles.spawn_friendly(_pos(Vector2.ZERO), Vector2.RIGHT, 600.0,
		RunFixture.info(5.0), {"life": 1.0})
	_steps(0.25)
	check(p.position.distance_to(exit_point) < 200.0, "le tir ressort par la sortie")


func test_pack_call_sends_echoes() -> void:
	var spells: HunterSpells = _equip(&"pack_call")
	var enemy: Enemy = RunFixture.spawn(run, &"husk", Vector2(300, 0))
	check(spells.cast(0, enemy.global_position), "Appel lancé")
	run.ctx.combat.flush_queue()
	check(run.ctx.allies.team[0].global_position.distance_to(enemy.global_position) < 80.0, "l'Écho a bondi")
	check(_hurt(enemy), "frappe groupée")


func test_aegis_shields_then_expires() -> void:
	var spells: HunterSpells = _equip(&"aegis")
	spells.cast(0, _pos(Vector2.ZERO))
	var expected: float = run.ctx.player.max_hp * 0.25 * (1.0 + 0.05 * run.ctx.allies.team.size())
	check(absf(run.ctx.player.shield - expected) < 0.5, "bouclier de 25 % (+5 % par Écho)")
	_steps(4.2)
	check_eq(run.ctx.player.shield, 0.0, "bouclier retiré après 4 s")


func test_swap_exchanges_places_and_taunts() -> void:
	var spells: HunterSpells = _equip(&"swap")
	var ally: Ally = run.ctx.allies.team[0]
	ally.global_position = _pos(Vector2(200, 0))
	var start: Vector2 = run.ctx.player.global_position
	var enemy: Enemy = RunFixture.spawn(run, &"husk", Vector2(40, 0))
	check(spells.cast(0, ally.global_position), "Permutation lancée")
	check(run.ctx.player.global_position.distance_to(start + Vector2(200, 0)) < 1.0, "le Chasseur prend la place")
	check(ally.global_position.distance_to(start) < 1.0, "l'Écho prend celle du Chasseur")
	check(enemy.taunt_target == ally and enemy.taunt_time > 0.0, "ennemi provoqué")


func _talent(id: StringName) -> void:
	var effect := HunterTalentEffect.new()
	effect.talent = id
	effect.install(run.ctx, &"")


func test_talents_slicing_dash_and_counter_cut() -> void:
	_talent(&"slicing_dash")
	_talent(&"counter_cut")
	var enemy: Enemy = RunFixture.spawn(run, &"husk", Vector2(70, 0))
	run.ctx.events.player_dashed.emit(_pos(Vector2.ZERO), _pos(Vector2(140, 0)))
	run.ctx.combat.flush_queue()
	check(_hurt(enemy), "Ruée tranchante")
	run.ctx.events.player_dodged.emit()
	check(run.ctx.spells.world.blade_empowered, "Contre-taille : sort de Lame renforcé")
	check_eq(run.ctx.spells.world.consume_power(GameDB.spells[&"cleaving_slash"]), 1.5, "+50 % au prochain sort de Lame")


func test_talents_propagation_and_void_master() -> void:
	_talent(&"propagation")
	_talent(&"void_master")
	var dying: Enemy = RunFixture.spawn(run, &"skitterling", Vector2(100, 0))
	var next: Enemy = RunFixture.spawn(run, &"husk", Vector2(150, 0))
	run.ctx.status_system.apply(dying, &"mark", 2, &"player")
	run.ctx.combat.deal_damage(dying, RunFixture.info(1e6))
	check(next.statuses.get_stacks(&"mark") >= 2, "Propagation : Marques transmises")
	var base: float = run.ctx.combat.compute_damage(next, RunFixture.info(100.0))
	run.ctx.status_system.apply(next, &"root", 1, &"player")
	check(run.ctx.combat.compute_damage(next, RunFixture.info(100.0)) > base * 1.2, "Maître du vide : +25 %")


func test_keystones_blade_master_and_pack_soul() -> void:
	_talent(&"blade_master")
	_talent(&"pack_soul")
	var spells: HunterSpells = run.ctx.spells
	spells.cooldowns[1] = 5.0
	var ally: Ally = run.ctx.allies.team[0]
	ally.technique_cd = 5.0
	spells.cast(0, _pos(Vector2(100, 0)))
	check(absf(spells.cooldowns[1] - 4.0) < 0.01, "Maître-lame : −1 s aux autres sorts")
	check(absf(ally.technique_cd - 4.0) < 0.01, "Âme de meute : −1 s aux sorts d'Échos")


## Chaque variante de l'arbre et chaque talent fonctionnent dans une mêlée (aucune erreur, sort bien lancé).
func test_every_variant_and_talent_runs_in_a_brawl() -> void:
	for offset: Vector2 in [Vector2(60, 0), Vector2(-80, 30), Vector2(150, -40), Vector2(220, 60), Vector2(0, 120)]:
		var enemy: Enemy = RunFixture.spawn(run, &"husk", offset)
		run.ctx.status_system.apply(enemy, &"mark", 2, &"player")
	for id: StringName in GameDB.sorted_ids(GameDB.skill_nodes):
		var node: SkillNodeData = GameDB.skill_nodes[id]
		if node.kind == SkillNodeData.Kind.TRANSFORM or node.kind == SkillNodeData.Kind.KEYSTONE:
			for effect: GameplayEffect in node.effects:
				effect.install(run.ctx, &"")
	run.ctx.player.god_mode = true
	for id: StringName in GameDB.sorted_ids(GameDB.skill_nodes):
		var node: SkillNodeData = GameDB.skill_nodes[id]
		if node.kind != SkillNodeData.Kind.VARIANT:
			continue
		var spells: HunterSpells = _equip(node.spell_id, node.variant_kind)
		var before: float = run.ctx.stats.get_value(&"spells_cast")
		var cast: bool = spells.cast(0, _pos(Vector2(160, 20)))
		if node.spell_id == &"twin_rifts":
			spells.cast(0, _pos(Vector2(-200, 0)))
		check(cast and run.ctx.stats.get_value(&"spells_cast") > before, "%s lancé" % id)
		run.ctx.events.player_dashed.emit(_pos(Vector2.ZERO), _pos(Vector2(80, 0)))
		run.ctx.combat.damage_player(5.0, &"husk")
		_steps(0.5)
		run.ctx.spells.world.return_until = -1.0
		run.ctx.spells.world.portals = {}
	check(run.ctx.player.alive, "le Chasseur survit au test")
