extends TestCase
## Lot C3 : arbres des Échos (apprendre / activer, Points d'Écho, un sort équipé) et seconds sorts visés.

var profile: ProfileData
var run: RunController


func before_each() -> void:
	profile = ProfileData.new()


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _node(id: StringName) -> SkillNodeData:
	return EchoTree.node(id)


func test_every_echo_has_its_tree() -> void:
	for id: StringName in GameDB.monsters:
		var nodes: Array[SkillNodeData] = EchoTree.nodes_of(id)
		check_eq(nodes.size(), 5, "%s : 5 nœuds" % id)
		var base: SkillNodeData = _node(StringName(String(id) + "_spell_base"))
		check(base != null and EchoTree.active_rank(profile, base) == 1, "%s : sort d'origine équipé" % id)
		var alt: SkillNodeData = _node(StringName(String(id) + "_spell_alt"))
		check(alt != null and GameDB.techniques.has(alt.spell_id), "%s : second sort défini" % id)


func test_points_come_from_mastery() -> void:
	profile.add_currency("shards", 5000)
	check_eq(EchoTree.points_total(profile, &"ashblade"), 1, "1 point sans maîtrise")
	var might: SkillNodeData = _node(&"ashblade_might")
	check(EchoTree.learn(profile, might), "Puissance apprise")
	check(EchoTree.learn(profile, might), "rang 2 appris")
	check(EchoTree.activate(profile, might), "rang 1 actif")
	check_eq(EchoTree.activation_error(profile, might), "ECHO_TREE_ERR_POINTS", "plus de points")
	profile.mastery_entry(&"ashblade")["xp"] = 60
	check_eq(EchoTree.points_total(profile, &"ashblade"), 3, "1 + niveau de maîtrise 2")
	check(EchoTree.activate(profile, might), "rang 2 actif avec la maîtrise")


func test_one_spell_equipped_per_echo() -> void:
	profile.add_currency("shards", 5000)
	var base: SkillNodeData = _node(&"voltwisp_spell_base")
	var alt: SkillNodeData = _node(&"voltwisp_spell_alt")
	check_eq(EchoTree.status(profile, alt), HunterTree.Status.LOCKED, "second sort : un passif requis")
	EchoTree.learn(profile, _node(&"voltwisp_focus"))
	check(EchoTree.learn(profile, alt), "second sort appris")
	check(EchoTree.activate(profile, alt), "second sort équipé")
	check_eq(EchoTree.active_rank(profile, base), 0, "le sort d'origine est remplacé")
	check_eq(EchoTree.chosen_technique(profile, &"voltwisp").id, &"chain_arc", "Arc chaîné choisi")
	check(EchoTree.activate(profile, base), "retour au sort d'origine")
	check(EchoTree.chosen_technique(profile, &"voltwisp") == null, "sort d'origine en partie")
	HunterTree.set_active_index(profile, 1)
	check_eq(EchoTree.active_rank(profile, base), 1, "chaque build a ses propres choix")


func test_tree_applies_in_run() -> void:
	profile.add_currency("shards", 5000)
	profile.mastery_entry(&"ashblade")["xp"] = 300
	for id: StringName in [&"ashblade_might", &"ashblade_spell_alt", &"ashblade_signature"]:
		check(EchoTree.learn(profile, _node(id)), "apprentissage %s" % id)
	for id: StringName in [&"ashblade_might", &"ashblade_spell_alt", &"ashblade_signature"]:
		check(EchoTree.activate(profile, _node(id)), "activation %s" % id)
	var original: ProfileData = Profile.profile
	Profile.profile = profile
	var setup: RunSetup = Profile.make_run_setup(&"ashblade")
	Profile.profile = original
	setup.autopilot = true
	run = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	var ally: Ally = run.ctx.allies.get_ally(&"ashblade")
	check_eq(ally.technique.id, &"cinder_dash", "second sort équipé en partie")
	check(ally.stats.get_value(StatKeys.DAMAGE) > 1.0, "Puissance : dégâts de l'Écho augmentés")
	check(ally.stats.get_value(StatKeys.ATTACK_SPEED) > 1.0, "Signature : vitesse d'attaque augmentée")
	var evo: EvolutionData = ally.data.evolutions[0]
	if evo.technique:
		ally.apply_modifier(evo)
		check_eq(ally.technique.id, &"cinder_dash", "une évolution ne remplace pas le sort choisi")


func test_every_second_spell_casts() -> void:
	run = RunFixture.create(host, &"mossback")
	for monster_id: StringName in GameDB.sorted_ids(GameDB.monsters):
		if run.ctx.allies.get_ally(monster_id) == null:
			run.ctx.player.stats.add_modifier(StatKeys.TEAM_SLOTS, 1.0, 0.0)
	var player: Vector2 = run.ctx.player.global_position
	for offset: Vector2 in [Vector2(150, 0), Vector2(180, 30), Vector2(200, -20), Vector2(240, 10)]:
		RunFixture.spawn(run, &"husk", offset)
	var ally: Ally = run.ctx.allies.team[0]
	for alt_id: StringName in GameDB.sorted_ids(GameDB.techniques):
		ally.technique = GameDB.techniques[alt_id]
		ally.technique_cd = 0.0
		check(Techniques.cast(ally, run.ctx, player + Vector2(190, 0)), "%s lancé" % alt_id)
		run.ctx.combat.flush_queue()
