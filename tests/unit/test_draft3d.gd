extends TestCase
## Premier jet 3D (draft3d/, docs/PREMIER_JET_3D.md) : EXP, niveaux, améliorations du Chasseur seul, absence complète
## des Échos, carte (escaliers, abris, navigation), pause du choix de niveau, défaite, victoire, partie neuve.

var run: DraftRun


func after_each() -> void:
	if run != null:
		host.get_tree().paused = false
		run.queue_free()
		run = null


func _start() -> void:
	run = (load("res://draft3d/main.tscn") as PackedScene).instantiate()
	host.add_child(run)
	for frame: int in 600:
		if run.state == DraftRun.State.PLAYING:
			break
		await host.get_tree().physics_frame
	# Les essais pilotent la partie : plus d'apparitions ni de boss pendant les contrôles.
	run.boss_time = INF
	run.tuning = run.tuning.duplicate()
	run.tuning.waves.assign([{"at": 0.0, "rate": 0.0, "cap": 0, "mix": {"skitterling": 1.0}}])
	run.tuning.swarm_every = INF
	run._swarm_at = INF


func _frames(count: int) -> void:
	for frame: int in count:
		await host.get_tree().physics_frame


func test_catalog_is_hunter_only() -> void:
	var upgrades := DraftUpgrades.new()
	check_eq(upgrades.catalog.size(), 12, "douze cartes : dix communes, deux propres au premier jet")
	var ally_stats: Array[StringName] = [StatKeys.ALLY_DAMAGE, StatKeys.ALLY_ATTACK_SPEED, StatKeys.TECHNIQUE_COOLDOWN,
		StatKeys.TEAM_SLOTS, StatKeys.RECRUIT_RANK, StatKeys.EVOLUTION_RANK]
	for data: UpgradeData in upgrades.catalog:
		check(data.requires_any_monster.is_empty(), "%s : aucune condition d'Écho" % data.id)
		check(tr(data.name_key) != data.name_key and tr(data.desc_key) != data.desc_key, "%s : textes traduits" % data.id)
		for effect: GameplayEffect in data.effects:
			var modifier := effect as StatModifierEffect
			check(modifier != null and not ally_stats.has(modifier.stat), "%s : statistique du Chasseur" % data.id)
	for id: StringName in [&"strong_bond", &"focus_mind", &"frenzy", &"marking_bolt", &"static_bolt"]:
		check(not DraftUpgrades.is_valid(GameDB.upgrades[id]), "%s (Échos ou ancienne simulation) est refusée" % id)


func test_offers_are_distinct_and_respect_caps() -> void:
	var upgrades := DraftUpgrades.new()
	var stats: StatSheet = DraftUpgrades.base_stats(GameDB.balance)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var picks: int = 0
	while true:
		var offers: Array[UpgradeData] = upgrades.roll(rng, 3)
		if offers.is_empty():
			break
		var ids: Dictionary = {}
		for data: UpgradeData in offers:
			ids[data.id] = true
			check(upgrades.stacks_of(data.id) < data.max_stacks, "offre encore utile : %s" % data.id)
		check_eq(ids.size(), offers.size(), "offres distinctes")
		if upgrades.available().size() >= 3:
			check_eq(offers.size(), 3, "trois choix tant que le catalogue le permet")
		check(upgrades.apply(offers[0], stats), "la carte s'applique")
		picks += 1
		check(picks < 200, "le catalogue finit par s'épuiser")
		if picks >= 200:
			break
	for data: UpgradeData in upgrades.catalog:
		check_eq(upgrades.stacks_of(data.id), data.max_stacks, "plafond atteint, jamais dépassé : %s" % data.id)
	check(not upgrades.apply(upgrades.catalog[0], stats), "une carte au plafond ne s'applique plus")


func test_xp_thresholds_and_upgrade_effects() -> void:
	await _start()
	var hunter: DraftHunter = run.hunter
	var balance: BalanceConfig = GameDB.balance
	check_eq(hunter.level, 1, "départ au niveau 1")
	hunter.gain_xp(float(balance.xp_to_next(1)) - 1.0)
	check_eq(hunter.level, 1, "sous le seuil : pas de niveau")
	hunter.gain_xp(1.0)
	check_eq(hunter.level, 2, "seuil atteint : niveau 2")
	check_near(hunter.xp, 0.0, 0.001, "l'EXP repart de zéro")
	hunter.gain_xp(float(balance.xp_to_next(2) + balance.xp_to_next(3)))
	check_eq(hunter.level, 4, "deux seuils franchis d'un coup : deux niveaux")
	# Le choix s'ouvre aussitôt, met le combat en pause, s'applique et rend la main.
	await _frames(2)
	check_eq(run.state, DraftRun.State.CHOOSING, "le niveau ouvre le choix")
	check(host.get_tree().paused and run.hud.offers_open(), "combat en pause pendant le choix")
	var offer: UpgradeData = run._offers[0]
	var damage: float = hunter.bolt_damage()
	var max_hp: float = hunter.max_hp()
	run.choose(0)
	check(not host.get_tree().paused and run.state == DraftRun.State.PLAYING, "le combat reprend après le choix")
	check_eq(run.upgrades.stacks_of(offer.id), 1, "l'amélioration choisie est prise")
	var sheet: StatSheet = DraftUpgrades.base_stats(balance)
	sheet.add_modifier(StatKeys.DAMAGE, 0.0, run.tuning.hunter_damage_pct)
	for effect: GameplayEffect in offer.effects:
		var modifier := effect as StatModifierEffect
		sheet.add_modifier(modifier.stat, modifier.flat, modifier.pct)
	check_near(hunter.bolt_damage(), balance.bolt.damage * sheet.get_value(StatKeys.DAMAGE), 0.001, "dégâts selon la carte")
	check(hunter.bolt_damage() >= damage and hunter.max_hp() >= max_hp, "jamais d'affaiblissement")
	await _frames(2)
	check_eq(run.state, DraftRun.State.CHOOSING, "les niveaux en attente s'enchaînent")
	run.choose(1)
	await _frames(2)
	run.choose(0)
	await _frames(2)
	check(run.state == DraftRun.State.PLAYING and not host.get_tree().paused, "tous les niveaux sont dépensés")


func test_no_echo_anywhere() -> void:
	await _start()
	for node: Node in run.find_children("*", "", true, false):
		check(not (node is Ally) and not String(node.name).to_lower().contains("echo"), "aucun Écho : %s" % node.name)
	for key: StringName in [StatKeys.ALLY_DAMAGE, StatKeys.ALLY_ATTACK_SPEED, StatKeys.TEAM_SLOTS, StatKeys.TECHNIQUE_COOLDOWN]:
		check(not run.hunter.stats.has_base(key), "aucune statistique d'équipe : %s" % key)


func test_map_stairs_shelters_and_heights() -> void:
	await _start()
	var top := Vector3(0, DraftLevel.TERRACE_HEIGHT, -16)
	for from: Vector3 in [DraftLevel.START, Vector3(20, 0, 0), Vector3(-20, 0, 10)]:
		var path: PackedVector3Array = run.level.path(from, top)
		check(path.size() >= 2 and path[path.size() - 1].distance_to(top) < 1.0 and absf(path[path.size() - 1].y - 2.0) < 0.4,
			"la terrasse est accessible depuis %s" % from)
	check(run.level.spawn_points().size() >= 20, "points d'apparition sur le pourtour")
	# Le Chasseur monte réellement l'escalier central.
	run.hunter.global_position = Vector3(0, 0.2, -8)
	run.hunter.reset_motion()
	run.hunter.automating = true
	run.hunter.auto_direction = Vector3(0, 0, -1)
	await _frames(110)
	check(run.hunter.global_position.y > 1.8 and run.hunter.global_position.z < -12.0, "montée de l'escalier : y = %.2f"
		% run.hunter.global_position.y)
	# Limites : on ne sort pas de la carte.
	run.hunter.auto_direction = Vector3(1, 0, 1)
	await _frames(400)
	var pos: Vector3 = run.hunter.global_position
	check(absf(pos.x) < DraftLevel.HALF.x + 0.6 and absf(pos.z) < DraftLevel.HALF.y + 0.6 and pos.y > -0.5, "limites tenues")
	run.hunter.auto_direction = Vector3.ZERO
	# Abris : un mur coupe la vue et arrête les traits ; à découvert le trait touche.
	check(not run.sight_clear(Vector3(13, 0.8, 0), Vector3(17, 0.8, 0)), "le muret est coupe la vue")
	check(run.sight_clear(Vector3(13, 0.8, 8), Vector3(17, 0.8, 8)), "à découvert la vue est libre")
	check(not run.sight_clear(Vector3(0, 0.8, -8), Vector3(6, 2.6, -16)), "le rebord de la terrasse cache ce qui est derrière")
	check(run.sight_clear(Vector3(3.5, 0.8, -4), Vector3(3.5, 2.8, -13)), "de la cour, on voit le bord de la terrasse")
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"husk"), Vector3(17, 0, 0))
	run.hunter.global_position = Vector3(13, 0.2, 0)
	run.hunter.reset_motion()
	await _frames(3)
	check(run.target() == null, "pas de cible derrière un abri")
	run.fire_bolt(Vector3(13, 0.8, 0), Vector3.RIGHT, 5.0, 10.0, 0, 0)
	await _frames(30)
	check(run.blocked_bolts >= 1 and is_equal_approx(foe.hp, foe.max_hp), "le mur arrête le trait")


func test_enemies_reach_hurt_and_kill_then_fresh_run() -> void:
	await _start()
	var hunter: DraftHunter = run.hunter
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"skitterling"), hunter.global_position + Vector3(6, 0, 0))
	hunter.attack_timer = 1000.0
	await _frames(240)
	check(hunter.hp < hunter.max_hp(), "l'ennemi atteint et blesse le Chasseur")
	# Attaque automatique : l'ennemi meurt, lâche de l'EXP, que le Chasseur ramasse.
	hunter.attack_timer = 0.0
	hunter.god_mode = true
	await _frames(240)
	check(not foe.alive and run.kills == 1, "l'attaque automatique tue l'ennemi")
	check(hunter.xp > 0.0 or hunter.level > 1, "l'EXP lâchée est ramassée")
	hunter.god_mode = false
	hunter.invulnerable = 0.0
	hunter.take_damage(100000.0)
	check(not hunter.alive and run.state == DraftRun.State.LOST, "PV à zéro : défaite")
	run.queue_free()
	run = null
	await _start()
	check(run.hunter.level == 1 and run.kills == 0 and run.upgrades.stacks.is_empty() and run.time < 1.0,
		"une partie neuve repart de zéro")
	check_near(run.hunter.hp, run.hunter.max_hp(), 0.001, "PV pleins")


func test_boss_fight_ends_in_victory() -> void:
	await _start()
	run.boss_time = 0.0
	run.hunter.god_mode = true
	run.hunter.global_position = Vector3(10, 0.2, 2)
	run.hunter.reset_motion()
	await _frames(5)
	var boss: DraftEnemies.Foe = run.enemies.boss
	check(boss != null and boss.boss.id == &"nebulorax", "le boss arrive")
	await _frames(400)
	check(boss.hp < boss.max_hp, "l'attaque automatique blesse le boss")
	run.enemies.hit(boss, 1000000.0)
	check_eq(run.state, DraftRun.State.WON, "boss vaincu : victoire")
