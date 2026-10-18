extends TestCase
## Lot C7 : les 9 nouveaux Échos attaquent, lancent leurs deux sorts et appliquent leurs mécaniques propres
## (Aveuglement, Poison contagieux, Marque creuse, riposte, soins, accélération) ; effets peints et duos.

const NEW_ECHOES: Array[StringName] = [&"cinderwing", &"magmander", &"hollowflame", &"moonspore", &"gravishell",
	&"grovestag", &"sunclaw", &"glowmoth", &"stormshell"]
const STEP := 1.0 / 30.0

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start(starter: StringName) -> RunContext:
	run = RunFixture.create(host, starter)
	run.ctx.player.god_mode = true
	return run.ctx


## Groupe d'ennemis robustes autour d'un point (ils ne bougent pas : enemies.step n'est pas appelé).
func _pack(ctx: RunContext, center: Vector2, count: int = 8) -> Array[Enemy]:
	var pack: Array[Enemy] = []
	for i: int in count:
		var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(&"husk"), center + Vector2.RIGHT.rotated(TAU * i / count) * 40.0)
		enemy.max_hp = 5000.0
		enemy.hp = 5000.0
		pack.append(enemy)
	ctx.enemies.rebuild_grid()
	return pack


func _simulate(ctx: RunContext, seconds: float, ally: Ally = null) -> void:
	for i: int in int(seconds / STEP):
		ctx.time += STEP
		if ally:
			ally.behavior.tick(ally, ctx, STEP)
		ctx.hazards.step(STEP)
		ctx.projectiles.step(STEP)
		ctx.combat.flush_queue()


func _damage(ctx: RunContext, id: StringName) -> float:
	return float(ctx.stats.damage_by_source.get(id, 0.0))


func test_each_new_echo_attacks_and_casts_both_spells() -> void:
	for id: StringName in NEW_ECHOES:
		var ctx: RunContext = _start(id)
		var ally: Ally = ctx.allies.get_ally(id)
		check(ally != null, "%s : en équipe" % id)
		if ally == null:
			continue
		var target: Vector2 = ctx.player.global_position + Vector2(160, 0)
		_pack(ctx, target)
		_simulate(ctx, 4.0, ally)
		check(_damage(ctx, id) > 0.0, "%s : l'attaque touche" % id)
		var alt: SkillNodeData = EchoTree.node(StringName(String(id) + "_spell_alt"))
		for tech: TechniqueData in [GameDB.monster(id).technique, GameDB.techniques.get(alt.spell_id)]:
			check(tech != null, "%s : sort défini" % id)
			if tech == null:
				continue
			ally.technique = tech
			ally.global_position = ctx.player.global_position + Vector2(-30, 0)
			var before: float = _damage(ctx, id)
			var shield: float = ctx.player.shield
			check(Techniques.cast(ally, ctx, target), "%s : %s lancé" % [id, tech.id])
			_simulate(ctx, 3.0)  # la Singularité frappe à l'implosion (2,5 s)
			check(_damage(ctx, id) > before or ctx.player.shield > shield, "%s : %s a un effet" % [id, tech.id])
		check(ctx.allies.vfx.layer.get_child_count() > 0, "%s : effets peints joués" % id)
		RunFixture.dispose(run)
		run = null


func test_blinded_enemies_miss_half_their_attacks() -> void:
	var ctx: RunContext = _start(&"sunclaw")
	var enemy: Enemy = RunFixture.spawn(run, &"husk")
	check(not ctx.enemies.misses(enemy), "sans Aveuglement, l'attaque porte")
	ctx.status_system.apply(enemy, &"blind", 1, &"sunclaw")
	var missed: int = 0
	for i: int in 400:
		if ctx.enemies.misses(enemy):
			missed += 1
	check(missed > 140 and missed < 260, "Aveuglé : environ une attaque sur deux ratée (%d / 400)" % missed)


func test_poison_spreads_and_hollow_marks_implode() -> void:
	var ctx: RunContext = _start(&"moonspore")
	ctx.player.stats.add_modifier(StatKeys.TEAM_SLOTS, 1.0, 0.0)
	ctx.allies.add_monster(&"hollowflame")
	var pack: Array[Enemy] = _pack(ctx, ctx.player.global_position + Vector2(200, 0), 6)
	var victim: Enemy = pack[0]
	ctx.status_system.apply(victim, &"poison", 3, &"moonspore")
	ctx.status_system.apply(victim, &"hollow", 1, &"hollowflame")
	victim.hp = 1.0
	var neighbour: Enemy = pack[1]
	var hp: float = neighbour.hp
	ctx.combat.deal_damage(victim, RunFixture.info(10.0))
	ctx.combat.flush_queue()
	check(not victim.alive, "victime tuée")
	check(neighbour.statuses.get_stacks(&"poison") > 0, "le Poison se propage aux voisins")
	check(neighbour.hp < hp, "la Marque creuse implose et blesse les voisins")


func test_stormshell_strikes_back_when_the_hunter_is_hit() -> void:
	var ctx: RunContext = _start(&"stormshell")
	ctx.player.god_mode = false
	var enemy: Enemy = RunFixture.spawn(run, &"husk", Vector2(90, 0))
	enemy.max_hp = 5000.0
	enemy.hp = 5000.0
	ctx.enemies.rebuild_grid()
	ctx.combat.damage_player(10.0, &"husk")
	ctx.combat.flush_queue()
	check(enemy.hp < 5000.0, "riposte électrique sur l'ennemi proche")
	check(enemy.statuses.has(&"static"), "l'ennemi est Électrisé")


func test_grove_heals_and_swarm_haste_expires() -> void:
	var ctx: RunContext = _start(&"grovestag")
	var grovestag: Ally = ctx.allies.get_ally(&"grovestag")
	ctx.player.hp = ctx.player.max_hp * 0.5
	grovestag.technique = GameDB.techniques[&"healing_grove"]
	check(Techniques.cast(grovestag, ctx, ctx.player.global_position), "Bosquet lancé")
	_simulate(ctx, 2.0)
	check(ctx.player.hp > ctx.player.max_hp * 0.5, "le Bosquet soigne le Chasseur qui s'y tient")
	ctx.player.stats.add_modifier(StatKeys.TEAM_SLOTS, 1.0, 0.0)
	var glowmoth: Ally = ctx.allies.add_monster(&"glowmoth")
	var speed: float = ctx.player.stats.get_value(StatKeys.MOVE_SPEED)
	check(Techniques.cast(glowmoth, ctx, ctx.player.global_position + Vector2(100, 0)), "Essaim lancé")
	check(ctx.player.stats.get_value(StatKeys.MOVE_SPEED) > speed, "Essaim : le Chasseur accélère")
	Techniques.cast(glowmoth, ctx, ctx.player.global_position)
	ctx.time += 6.0
	ctx.allies.step(0.0)
	check_near(ctx.player.stats.get_value(StatKeys.MOVE_SPEED), speed, 0.01, "accélération retirée, sans cumul")


func test_new_named_duos_activate() -> void:
	var duos: Dictionary = {&"ember_storm": [&"cinderwing", &"voltwisp"], &"stone_flow": [&"magmander", &"mossback"],
		&"putrid_feast": [&"moonspore", &"gloommaw"], &"collapse": [&"gravishell", &"hollowflame"],
		&"living_forest": [&"grovestag", &"thornweave"], &"dawn_hunt": [&"sunclaw", &"ashblade"],
		&"constellation": [&"glowmoth", &"glimmerwing"], &"total_reflection": [&"stormshell", &"mirrorling"]}
	for duo: StringName in duos:
		var pair: Array = duos[duo]
		var ctx: RunContext = _start(pair[0])
		ctx.player.stats.add_modifier(StatKeys.TEAM_SLOTS, 1.0, 0.0)
		ctx.allies.add_monster(pair[1])
		check(ctx.build.active_synergies.has(duo), "duo %s actif" % duo)
		RunFixture.dispose(run)
		run = null


func test_every_new_echo_is_complete() -> void:
	for id: StringName in NEW_ECHOES:
		var monster: MonsterData = GameDB.monster(id)
		check(monster != null and Assets.has_sheet(monster.visual.visual_id), "%s : fiche et sprite" % id)
		check_eq(EchoTree.nodes_of(id).size(), 5, "%s : arbre de 5 nœuds" % id)
		for n: SkillNodeData in EchoTree.nodes_of(id):
			check(EchoTreeBoard.node_icon(n) != null, "%s : icône du nœud %s" % [id, n.id])
		check(not monster.unlocked_by_default, "%s : se débloque en jeu (Rite de lien)" % id)
