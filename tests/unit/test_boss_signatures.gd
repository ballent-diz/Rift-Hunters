extends TestCase
## Montée en puissance des boss (docs/design/MONSTRES.md) : chaque boss a une mécanique phare qu'aucun autre n'a, et les
## Dévoreurs de fin de chapitre sont de plus en plus forts. Orbes de source, couronne d'astres, séquence des cratères.

const FINALES: Array[StringName] = [&"source_devourer", &"pyrevorn", &"glauquemire"]

var run: RunController
var ctx: RunContext
var boss: Enemy
var brain: BossController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _fight(id: StringName, offset := Vector2(400, 0)) -> void:
	run = RunFixture.create(host, &"ashblade")
	ctx = run.ctx
	boss = ctx.enemies.spawn_boss(GameDB.boss(id), ctx.player.global_position + offset)
	brain = BossController.new(ctx, boss)


func _pattern(id: StringName, kind: StringName, phase: int = 0) -> BossPatternData:
	for pattern: BossPatternData in GameDB.boss(id).phases[phase].patterns:
		if pattern.kind == kind:
			return pattern
	return null


func _tick(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		ctx.time += 0.05
		brain._run_scheduled()
		for mechanics: BossMechanics in ctx.boss_mechanics:
			mechanics.step(0.05)
		ctx.hazards.step(0.05)
		ctx.projectiles.step(0.05)
		t += 0.05


func _kinds(data: BossData) -> Dictionary:
	var kinds: Dictionary = {}
	for phase: BossPhaseData in data.phases:
		for pattern: BossPatternData in phase.patterns:
			kinds[pattern.kind] = true
	return kinds


func test_each_boss_has_its_own_signature() -> void:
	for id: StringName in GameDB.bosses:
		var data: BossData = GameDB.bosses[id]
		if data.guardian:
			continue
		check(data.signature != &"", "%s : mécanique phare déclarée" % id)
		check(_kinds(data).has(data.signature), "%s : sa mécanique phare fait partie de ses attaques" % id)
		for other: StringName in GameDB.bosses:
			if other != id:
				check(not _kinds(GameDB.bosses[other]).has(data.signature),
					"%s : la mécanique phare de %s ne sert à aucun autre boss" % [other, id])


func test_chapter_finales_grow_stronger() -> void:
	for i: int in range(1, FINALES.size()):
		var before: BossData = GameDB.boss(FINALES[i - 1])
		var after: BossData = GameDB.boss(FINALES[i])
		check(after.max_hp > before.max_hp, "%s a plus de PV que %s" % [after.id, before.id])
		check(after.phases.size() >= before.phases.size(), "%s : au moins autant de phases" % after.id)
		var hit_before: float = 0.0
		var hit_after: float = 0.0
		for phase: BossPhaseData in before.phases:
			for pattern: BossPatternData in phase.patterns:
				hit_before = maxf(hit_before, pattern.damage)
		for phase: BossPhaseData in after.phases:
			for pattern: BossPatternData in phase.patterns:
				hit_after = maxf(hit_after, pattern.damage)
		check(hit_after > hit_before, "%s frappe plus fort que %s" % [after.id, before.id])
	check_eq(GameDB.boss(&"glauquemire").phases.size(), 3, "le Dévoreur du chapitre 3 a trois phases")


func test_dash_sends_the_orb_back_and_stuns() -> void:
	_fight(&"source_devourer")
	var pattern: BossPatternData = _pattern(&"source_devourer", &"source_orb")
	brain._pattern_source_orb(pattern)
	_tick(pattern.telegraph + 0.1)
	var orbs: Array[Dictionary] = brain.signatures().orbs
	check_eq(orbs.size(), 1, "un orbe en phase 1")
	ctx.player.global_position = orbs[0]["pos"]
	ctx.player._dash_time = 0.2
	_tick(0.05)
	check(bool(orbs[0]["reflected"]), "la Ruée renvoie l'orbe")
	_tick(1.5)
	check(boss.hp < boss.max_hp, "l'orbe renvoyé blesse le Dévoreur")
	check(brain.stunned_time > 0.0, "l'orbe doré étourdit")
	check(orbs.is_empty(), "l'orbe a disparu")


func test_orb_hurts_without_dash() -> void:
	_fight(&"source_devourer")
	brain._pattern_source_orb(_pattern(&"source_devourer", &"source_orb"))
	_tick(1.0)
	var hp: float = ctx.player.hp
	ctx.player.global_position = brain.signatures().orbs[0]["pos"]
	_tick(0.1)
	check(ctx.player.hp < hp, "un orbe touché sans Ruée blesse")
	check(ctx.player.is_hindered(), "et ralentit")
	check(brain.signatures().orbs.is_empty(), "l'orbe éclate")


func test_salvo_has_a_single_golden_orb() -> void:
	_fight(&"source_devourer")
	brain._pattern_source_orb(_pattern(&"source_devourer", &"source_orb", 1))
	_tick(1.0)
	var golden: int = 0
	for orb: Dictionary in brain.signatures().orbs:
		golden += int(orb["golden"])
	check_eq(brain.signatures().orbs.size(), 3, "salve de trois orbes en phase 2")
	check_eq(golden, 1, "un seul orbe doré")


func test_crown_absorbs_hits_from_outside() -> void:
	_fight(&"astravorn", Vector2(600, 0))
	var pattern: BossPatternData = _pattern(&"astravorn", &"star_crown")
	brain._pattern_star_crown(pattern)
	_tick(pattern.telegraph + 0.1)
	var signatures: BossSignatures = brain.signatures()
	check(signatures.crown_active(), "la couronne est dressée")
	boss.invulnerable_time = 0.0
	var outside: float = ctx.combat.deal_damage(boss, RunFixture.info(100.0))
	ctx.player.global_position = boss.position + Vector2(60, 0)
	var inside: float = ctx.combat.deal_damage(boss, RunFixture.info(100.0))
	check(inside > 0.0 and outside < inside * 0.25, "de l'extérieur, les coups sont presque tous absorbés")


func test_crown_stars_hurt_then_fly_outward() -> void:
	_fight(&"astravorn", Vector2(600, 0))
	var pattern: BossPatternData = _pattern(&"astravorn", &"star_crown")
	brain._pattern_star_crown(pattern)
	_tick(pattern.telegraph + 0.1)
	var signatures: BossSignatures = brain.signatures()
	var stars: PackedVector2Array = signatures.star_positions()
	check(stars.size() < int(pattern.params["stars"]), "la couronne a des brèches")
	var hp: float = ctx.player.hp
	ctx.player.global_position = stars[0]
	_tick(0.05)
	check(ctx.player.hp < hp, "une étoile blesse")
	ctx.player.global_position = boss.position + Vector2(40, 0)
	_tick(float(pattern.params["duration"]) + 0.2)
	check(not signatures.crown_active(), "la couronne se défait")
	check(ctx.projectiles.hostile.size() > 0, "les étoiles partent vers l'extérieur")


func test_craters_erupt_in_the_shown_order() -> void:
	_fight(&"pyrevorn", Vector2(600, 0))
	var pattern: BossPatternData = _pattern(&"pyrevorn", &"crater_sequence")
	brain._pattern_crater_sequence(pattern)
	var signatures: BossSignatures = brain.signatures()
	var steps: Array[Dictionary] = signatures.crater_steps
	check_eq(steps.size(), int(pattern.params["steps"]), "autant d'étapes que prévu")
	check_eq(signatures.crater_cells.size(), 9, "grille de 3 × 3 cases")
	for k: int in range(1, steps.size()):
		check(float(steps[k]["lit_at"]) > float(steps[k - 1]["lit_at"]), "allumage une case après l'autre")
		check(float(steps[k]["erupt_at"]) > float(steps[k - 1]["erupt_at"]), "éruptions dans le même ordre")
		check(float(steps[k]["erupt_at"]) > float(steps.back()["lit_at"]), "les éruptions suivent les lumières")
	# Une case hors de la séquence est sûre ; la première case de la séquence explose.
	var used: Dictionary = {}
	for step_data: Dictionary in steps:
		used[int(step_data["cell"])] = true
	var safe: int = 0
	while used.has(safe):
		safe += 1
	ctx.player.global_position = signatures.crater_cells[safe].get_center()
	var hp: float = ctx.player.hp
	_tick(float(steps.back()["erupt_at"]) - ctx.time + 0.1)
	check_eq(ctx.player.hp, hp, "une case qui ne s'est pas allumée est sûre")
	brain._pattern_crater_sequence(pattern)
	ctx.player.global_position = signatures.crater_cells[int(signatures.crater_steps[0]["cell"])].get_center()
	_tick(float(signatures.crater_steps[0]["erupt_at"]) - ctx.time + 0.1)
	check(ctx.player.hp < hp, "la première case allumée explose")
