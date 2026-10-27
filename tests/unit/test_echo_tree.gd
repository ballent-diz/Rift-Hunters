extends TestCase
## Lot C3 : arbres des Échos (apprendre / activer, Points d'Écho, un sort équipé) et seconds sorts visés.
## v2 : la maîtrise ouvre les nœuds, variantes liées au sort équipé, signatures exclusives.

var profile: ProfileData
var run: RunController
var _injected: Array[StringName] = []


func before_each() -> void:
	profile = ProfileData.new()


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null
	for id: StringName in _injected:
		GameDB.echo_nodes.erase(id)
	_injected.clear()


## Nœud d'essai ajouté le temps du test (contenu des arbres v2 à venir).
func _inject(id: StringName, kind: SkillNodeData.Kind, prereq: StringName, group: StringName) -> SkillNodeData:
	var n := SkillNodeData.new()
	n.id = id
	n.branch = &"ashblade"
	n.kind = kind
	n.tier = 1
	n.costs = [10]
	n.point_cost = 1
	n.prerequisites = [prereq]
	n.exclusive_group = group
	GameDB.echo_nodes[id] = n
	_injected.append(id)
	return n


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
	check_eq(EchoTree.points_total(profile, &"ashblade"), 2, "2 points sans maîtrise")
	var might: SkillNodeData = _node(&"ashblade_might")
	for rank: int in 3:
		check(EchoTree.learn(profile, might), "Puissance rang %d appris" % (rank + 1))
	check(EchoTree.activate(profile, might), "rang 1 actif")
	check(EchoTree.activate(profile, might), "rang 2 actif")
	check_eq(EchoTree.activation_error(profile, might), "ECHO_TREE_ERR_POINTS", "plus de points")
	profile.mastery_entry(&"ashblade")["xp"] = 60
	check_eq(EchoTree.points_total(profile, &"ashblade"), 4, "2 + niveau de maîtrise 2")
	check(EchoTree.activate(profile, might), "rang 3 actif avec la maîtrise")


func test_one_spell_equipped_per_echo() -> void:
	profile.add_currency("shards", 5000)
	var base: SkillNodeData = _node(&"voltwisp_spell_base")
	var alt: SkillNodeData = _node(&"voltwisp_spell_alt")
	check_eq(EchoTree.status(profile, alt), HunterTree.Status.GATED, "second sort : maîtrise 1 requise")
	profile.mastery_entry(&"voltwisp")["xp"] = 20
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


func test_mastery_opens_the_signature() -> void:
	profile.add_currency("shards", 5000)
	var signature: SkillNodeData = _node(&"ashblade_signature")
	EchoTree.learn(profile, _node(&"ashblade_might"))
	check_eq(EchoTree.status(profile, signature), HunterTree.Status.GATED, "Signature : maîtrise 3 requise")
	profile.mastery_entry(&"ashblade")["xp"] = 120
	check_eq(EchoTree.mastery_level(profile, &"ashblade"), 3, "maîtrise 3")
	check_eq(EchoTree.status(profile, signature), HunterTree.Status.LEARNABLE, "Signature ouverte par la maîtrise")


func test_variants_follow_the_equipped_spell() -> void:
	profile.add_currency("shards", 5000)
	profile.mastery_entry(&"ashblade")["xp"] = 300
	var base_a: SkillNodeData = _inject(&"test_base_a", SkillNodeData.Kind.VARIANT, &"ashblade_spell_base", &"t_base")
	var base_b: SkillNodeData = _inject(&"test_base_b", SkillNodeData.Kind.VARIANT, &"ashblade_spell_base", &"t_base")
	var alt_a: SkillNodeData = _inject(&"test_alt_a", SkillNodeData.Kind.VARIANT, &"ashblade_spell_alt", &"t_alt")
	var alt: SkillNodeData = _node(&"ashblade_spell_alt")
	EchoTree.learn(profile, _node(&"ashblade_might"))
	for n: SkillNodeData in [alt, base_a, base_b, alt_a]:
		check(EchoTree.learn(profile, n), "%s appris" % n.id)
	check(EchoTree.activate(profile, base_a), "variante A du sort d'origine")
	check_eq(EchoTree.rivals(profile, base_b), [base_a] as Array[SkillNodeData], "A et B s'excluent")
	check(EchoTree.activate(profile, base_b), "B remplace A")
	check_eq(EchoTree.active_rank(profile, base_a), 0, "A retirée")
	check_eq(EchoTree.chosen_variant(profile, &"ashblade"), base_b, "variante choisie en partie")
	check_eq(EchoTree.activation_error(profile, alt_a), "TREE_ERR_NEEDS_SPELL", "variante d'un sort non équipé")
	check(EchoTree.activate(profile, alt), "second sort équipé")
	check_eq(EchoTree.active_rank(profile, base_b), 0, "les variantes de l'ancien sort tombent")
	check_eq(EchoTree.points_used(profile, &"ashblade"), 0, "et rendent leurs points")
	check(EchoTree.activate(profile, alt_a), "variante du second sort")
	check_eq(EchoTree.chosen_variant(profile, &"ashblade"), alt_a, "variante du sort équipé")


func test_board_reads_left_to_right() -> void:
	profile.add_currency("shards", 5000)
	var base: Vector2i = EchoTreeBoard.slot_of(_node(&"ashblade_spell_base"))
	var alt: Vector2i = EchoTreeBoard.slot_of(_node(&"ashblade_spell_alt"))
	check(EchoTreeBoard.slot_of(_node(&"ashblade_might")).x < base.x, "fondations à gauche")
	check(base.x < alt.x, "sort d'origine puis second sort")
	check(alt.x < EchoTreeBoard.slot_of(_node(&"ashblade_signature")).x, "apogée à droite")
	var variant: SkillNodeData = _inject(&"test_alt_b", SkillNodeData.Kind.VARIANT, &"ashblade_spell_alt", &"t_alt")
	check_eq(EchoTreeBoard.slot_of(variant), alt + Vector2i(0, 1), "variante sous son sort")
	var board := EchoTreeBoard.new()
	board.setup(profile, GameDB.monster(&"ashblade"), &"")
	check_eq(board.column_gate(2), 1, "second sort : maîtrise 1")
	check_eq(board.column_gate(3), 3, "apogée : maîtrise 3")
	board.free()
