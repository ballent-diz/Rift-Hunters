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
	var top := Vector3(0, DraftLevelRuins.TERRACE_HEIGHT, -16)
	for from: Vector3 in [DraftLevelRuins.START, Vector3(20, 0, 0), Vector3(-20, 0, 10)]:
		var path: PackedVector3Array = run.level.path(from, top)
		check(path.size() >= 2 and path[path.size() - 1].distance_to(top) < 1.0 and absf(path[path.size() - 1].y - 2.0) < 0.4,
			"la terrasse est accessible depuis %s" % from)
	check(run.level.spawn_points().size() >= 50, "points d'apparition sur le pourtour")
	# Le Chasseur monte réellement l'escalier central.
	run.hunter.global_position = Vector3(0, 0.2, -8)
	run.hunter.reset_motion()
	run.hunter.automating = true
	run.hunter.auto_direction = Vector3(0, 0, -1)
	await _frames(110)
	check(run.hunter.global_position.y > 1.8 and run.hunter.global_position.z < -12.0, "montée de l'escalier : y = %.2f"
		% run.hunter.global_position.y)
	# Limites : on ne sort pas de la carte.
	run.hunter.global_position = Vector3(31, 0.2, 22)
	run.hunter.reset_motion()
	run.hunter.auto_direction = Vector3(1, 0, 1)
	await _frames(400)
	var pos: Vector3 = run.hunter.global_position
	check(pos.x < DraftLevelRuins.MAX.x + 0.6 and pos.z < DraftLevelRuins.MAX.y + 0.6 and pos.x > 40.0 and pos.y > -0.5,
		"limites tenues, et l'on traverse la carte jusqu'au coin : %s" % pos)
	# Tous les quartiers communiquent : Parvis, Entrepôts, Colonnade, petite terrasse d'angle.
	for spot: Vector3 in [Vector3(-40, 0, 30), Vector3(-44, 0, -16), Vector3(42, 0, 30), Vector3(30, 0, -16),
			Vector3(40, DraftLevelRuins.TERRACE_HEIGHT, -16)]:
		var route: PackedVector3Array = run.level.path(DraftLevelRuins.BOSS_SPOT, spot)
		check(route.size() >= 2 and route[route.size() - 1].distance_to(spot) < 1.2, "quartier relié à la Cour : %s" % spot)
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
	for i: int in run.spells.cooldowns.size():
		run.spells.cooldowns[i] = 1000.0
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
	check(boss != null and boss.boss == run.roster.boss and boss.final, "le Dévoreur du chapitre arrive")
	await _frames(400)
	check(boss.hp < boss.max_hp, "l'attaque automatique blesse le boss")
	run.enemies.hit(boss, 1000000.0)
	check_eq(run.state, DraftRun.State.WON, "boss vaincu : victoire")


func test_rosters_cover_the_five_chapters() -> void:
	var seen: Dictionary = {}
	check_eq(DraftRoster.chapters().size(), 5, "cinq chapitres")
	for order: int in range(1, 6):
		var roster: DraftRoster = DraftRoster.for_chapter(order)
		check(roster.enemies.size() >= 8, "chapitre %d : au moins huit monstres (%d)" % [order, roster.enemies.size()])
		check(roster.boss != null and roster.guardians.size() >= 3, "chapitre %d : gardiens et Dévoreur" % order)
		for data: EnemyData in roster.enemies:
			seen[data.id] = true
			check(DraftRoster.usable(data), "%s : mobile et dessiné" % data.id)
		for boss: BossData in roster.guardians + [roster.boss]:
			check(boss.id != &"nebulorax", "Nebulorax est écarté")
			check(Assets.has_sheet(boss.visual.visual_id), "%s : feuille de sprites" % boss.id)
		check_eq(roster.mix(0.0).size(), 1, "première vague : un seul monstre")
		check_eq(roster.mix(1.0).size(), roster.enemies.size(), "dernière vague : tout le bestiaire")
	check(seen.size() >= 40, "au moins quarante monstres différents sur les cinq chapitres (%d)" % seen.size())


func test_every_chapter_plays_with_guardian_and_devourer() -> void:
	for order: int in range(1, 6):
		DraftRun.chosen_chapter = order
		await _start()
		check_eq(run.chapter, order, "chapitre %d lancé" % order)
		check(run.find_children("Prop", "", true, false).is_empty(), "aucun objet de la v1 dans le décor")
		var family: StringName = DraftPixelFx.boss_family(run.roster.boss)
		for effect: StringName in [&"hit", &"death", &"claw_swipe", &"ring_burst", DraftPixelFx.RAIN[family],
				DraftPixelFx.shot_effect("flights", family), DraftPixelFx.shot_effect("shots", family)]:
			check(not DraftPixelFx.sheet(effect, family).is_empty(), "effet PixelFX %s en palette %s" % [effect, family])
		for data: EnemyData in run.roster.enemies:
			run.enemies.spawn(data, run.level.spawn_point(run.rng, run.hunter.global_position))
		run.hunter.god_mode = true
		run.tuning.guardian_time = 0.0
		await _frames(90)
		var guardian: DraftEnemies.Foe = run.enemies.boss
		check(guardian != null and not guardian.final, "chapitre %d : un gardien arrive" % order)
		run.enemies.hit(guardian, 1000000.0)
		check(run.state == DraftRun.State.PLAYING and not run.gems.is_empty(), "gardien vaincu : EXP, la partie continue")
		run.boss_time = 0.0
		await _frames(60)
		check(run.enemies.boss != null and run.enemies.boss.final, "chapitre %d : le Dévoreur arrive" % order)
		run.enemies.hit(run.enemies.boss, 1000000.0)
		check_eq(run.state, DraftRun.State.WON, "chapitre %d : victoire" % order)
		run.queue_free()
		run = null
	DraftRun.chosen_chapter = 0


func test_audio_follows_the_run() -> void:
	await _start()
	check_eq(Audio.current_context, "run", "musique de partie au lancement")
	check(Audio.beat.is_connected(run._on_beat), "le tempo de la musique est branché")
	run.boss_time = 0.0
	run.hunter.god_mode = true
	await _frames(5)
	check_eq(Audio.current_context, "boss", "musique de boss à son arrivée")
	run.enemies.hit(run.enemies.boss, run.enemies.boss.max_hp * 0.6 / CombatSystem.defense_multiplier(run.enemies.boss.defense))
	await _frames(3)
	check_eq(Audio.current_context, "boss_phase2", "seconde phase : musique de seconde phase")
	run.enemies.hit(run.enemies.boss, 1000000.0)
	check_eq(Audio.current_context, "victory", "victoire : jingle de victoire")
	for id: StringName in [&"bolt_fire", &"enemy_hit", &"enemy_death", &"player_hurt", &"dash", &"xp_pickup", &"level_up",
			&"ui_click", &"boss_roar", &"boss_telegraph", &"elite_spawn", &"heart_exposed"]:
		check(Audio.sfx_events.has(String(id)), "son déclaré au manifeste audio : %s" % id)


func test_spells_tree_and_campaign() -> void:
	var previous: ProfileData = Profile.profile
	var tested := ProfileData.new()
	HunterTree.unlock_all_for_testing(tested)
	Profile.profile = tested
	await _start()
	Profile.profile = previous
	check(run.tree_effects > 0, "l'arbre du profil s'applique (%d effets)" % run.tree_effects)
	check(not run.spells.spells.is_empty(), "des sorts équipés sont raccordés")
	for data: SpellData in run.spells.spells:
		check(DraftSpells.SUPPORTED.has(data.spell_kind), "sort pris en charge : %s" % data.id)
	run.queue_free()
	run = null
	# Profil neuf : sorts de départ de l'équilibrage (Taille et Lance), qui partent seuls et blessent.
	Profile.profile = ProfileData.new()
	await _start()
	Profile.profile = previous
	check_eq(run.spells.spells.size(), 2, "deux sorts de départ")
	run.hunter.attack_timer = 100000.0
	run.hunter.god_mode = true
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"husk"), run.hunter.global_position + Vector3(2, 0, 0))
	await _frames(480)
	check(run.spells.casts >= 1 and (not foe.alive or foe.hp < foe.max_hp), "un sort part seul et blesse (%d lancés)"
		% run.spells.casts)
	check(run.spells.cooldowns[0] > 0.0 or run.spells.cooldowns[1] > 0.0, "le sort lancé se recharge")
	# Campagne : un chapitre s'ouvre quand le précédent est vaincu ; sauvegarde à part du profil.
	check_eq(DraftProgress.path, "", "essais : aucune sauvegarde écrite")
	check(DraftProgress.is_unlocked(1, []) and not DraftProgress.is_unlocked(2, []), "seul le chapitre 1 est ouvert")
	check(DraftProgress.is_unlocked(2, [1]) and not DraftProgress.is_unlocked(3, [1]), "vaincre le 1 ouvre le 2")
	DraftProgress.path = "user://draft3d_progress_test.json"
	DraftProgress.record_victory(1)
	DraftProgress.record_victory(2)
	check_eq(DraftProgress.cleared(), [1, 2] as Array[int], "victoires enregistrées")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DraftProgress.path))
	DraftProgress.path = ""


func test_second_level_graveyard() -> void:
	DraftRun.chosen_chapter = 2
	await _start()
	DraftRun.chosen_chapter = 0
	check(run.level is DraftLevelGraveyard, "le chapitre 2 se joue sur le Cimetière des Cendres")
	check(run.level.spawn_points().size() >= 60, "points d'apparition sur le pourtour (%d)" % run.level.spawn_points().size())
	check(run.hunter.global_position.distance_to(DraftLevelGraveyard.START) < 1.0, "départ devant le portail")
	# Tous les quartiers et le sommet du Tertre sont reliés au parvis de la crypte.
	for spot: Vector3 in [DraftLevelGraveyard.START, Vector3(-40, 0, 28), Vector3(40, 0, 28), Vector3(40, 0, -28),
			Vector3(-20, 0, -28), Vector3(0, 0, -26), Vector3(-32, DraftLevelGraveyard.MOUND_HEIGHT, -25)]:
		var route: PackedVector3Array = run.level.path(DraftLevelGraveyard.BOSS_SPOT, spot)
		check(route.size() >= 2 and route[route.size() - 1].distance_to(spot) < 1.5, "quartier relié : %s" % spot)
	# Le Chasseur monte réellement sur le Tertre par l'escalier sud.
	run.hunter.global_position = Vector3(-32, 0.2, -13)
	run.hunter.reset_motion()
	run.hunter.automating = true
	run.hunter.auto_direction = Vector3(0, 0, -1)
	await _frames(100)
	check(run.hunter.global_position.y > 1.8, "montée du Tertre : y = %.2f" % run.hunter.global_position.y)
	run.hunter.auto_direction = Vector3.ZERO
	# La crypte arrête la vue et les tirs ; un tronc aussi ; le feuillage non.
	check(not run.sight_clear(Vector3(-8, 0.8, -16), Vector3(8, 0.8, -16)), "la crypte coupe la vue")
	check(not run.sight_clear(Vector3(9, 0.8, 11), Vector3(13, 0.8, 11)), "un tronc coupe la vue")
	check(run.sight_clear(Vector3(9, 3.2, 11), Vector3(13, 3.2, 11)), "le feuillage ne bloque pas")
	check(run.sight_clear(Vector3(-4, 0.8, 2), Vector3(4, 0.8, 2)), "le parvis est dégagé")
	# Limites : on ne sort pas par le portail ni par les grilles.
	run.hunter.global_position = Vector3(0, 0.2, 28)
	run.hunter.reset_motion()
	run.hunter.auto_direction = Vector3(0, 0, 1)
	await _frames(120)
	check(run.hunter.global_position.z < DraftLevelGraveyard.MAX.y + 0.6, "le portail ferme la carte")


func test_ring_wave_is_blocked_by_cover() -> void:
	await _start()
	var hunter: DraftHunter = run.hunter
	# À découvert : l'onde frappe.
	hunter.global_position = Vector3(13, 0.2, 8)
	hunter.reset_motion()
	run.hazards.ring(Vector3(19, 0, 8), 8.5, 20.0, 0.1, 10.0)
	await _frames(90)
	check(hunter.hp < hunter.max_hp(), "à découvert, l'onde blesse")
	# Derrière le muret (x = 15) : elle est arrêtée.
	hunter.hp = hunter.max_hp()
	hunter.invulnerable = 0.0
	hunter.global_position = Vector3(13, 0.2, 0)
	hunter.reset_motion()
	run.hazards.ring(Vector3(19, 0, 0), 8.5, 20.0, 0.1, 10.0)
	await _frames(90)
	check_near(hunter.hp, hunter.max_hp(), 0.001, "derrière un obstacle, l'onde ne passe pas")
	# L'onde est coupée à l'image aussi : des tronçons s'éteignent sur le décor, les autres continuent.
	run.hazards.ring(Vector3(19, 0, 0), 8.5, 12.0, 0.05, 10.0)
	await _frames(40)
	var alive: PackedByteArray = run.hazards._items[run.hazards._items.size() - 1]["alive"]
	check(alive.count(0) > 5 and alive.count(1) > 5, "onde coupée par les obstacles : %d tronçons éteints sur %d"
		% [alive.count(0), alive.size()])
	hunter.god_mode = true
	var shot_foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"spitter"), hunter.global_position + Vector3(-6, 0, 8))
	run.enemy_shot(shot_foe)
	check((run.hostile[run.hostile.size() - 1]["visual"] as Sprite3D).flip_h == false, "tir vers la droite : dessin à l'endroit")
	shot_foe.pos = hunter.global_position + Vector3(6, 0, 0)
	run.enemy_shot(shot_foe)
	check((run.hostile[run.hostile.size() - 1]["visual"] as Sprite3D).flip_h, "tir vers la gauche : dessin retourné")


func test_third_level_village() -> void:
	DraftRun.chosen_chapter = 3
	await _start()
	DraftRun.chosen_chapter = 0
	check(run.level is DraftLevelVillage, "le chapitre 3 se joue sur le Hameau du Gué")
	check(run.level.spawn_points().size() >= 60, "points d'apparition sur le pourtour (%d)" % run.level.spawn_points().size())
	# Tous les quartiers et le sommet de la butte sont reliés à la place, par les ponts.
	for spot: Vector3 in [Vector3(-42, 0, 20), Vector3(34, 0, 20), Vector3(-42, 0, -16), Vector3(12, 0, -27), Vector3(34, 0, -8),
			DraftLevelVillage.BOSS_SPOT, Vector3(4, DraftLevelVillage.KNOLL_HEIGHT, -24)]:
		var route: PackedVector3Array = run.level.path(DraftLevelVillage.START, spot)
		check(route.size() >= 2 and route[route.size() - 1].distance_to(spot) < 1.5, "quartier relié : %s" % spot)
	# La rivière ne se traverse que par les ponts.
	var hunter: DraftHunter = run.hunter
	hunter.automating = true
	hunter.global_position = Vector3(12, 0.2, 8)
	hunter.reset_motion()
	hunter.auto_direction = Vector3(0, 0, -1)
	await _frames(150)
	check(hunter.global_position.z > DraftLevelVillage.RIVER.y - 0.3, "la berge arrête le Chasseur : z = %.1f"
		% hunter.global_position.z)
	hunter.global_position = Vector3(-26, 0.2, 8)
	hunter.reset_motion()
	await _frames(150)
	check(hunter.global_position.z < DraftLevelVillage.RIVER.x and hunter.global_position.y > -0.3,
		"le pont ouest se traverse : %s" % hunter.global_position)
	# Montée de la butte par l'escalier sud.
	hunter.global_position = Vector3(0, 0.2, -13)
	hunter.reset_motion()
	await _frames(110)
	check(hunter.global_position.y > 1.8, "montée de la butte : y = %.2f" % hunter.global_position.y)
	hunter.auto_direction = Vector3.ZERO
	check(not run.sight_clear(Vector3(-15, 0.8, 12), Vector3(-15, 0.8, 24)), "un bâtiment coupe la vue")
	check(run.sight_clear(Vector3(10, 0.8, 5), Vector3(10, 0.8, -5)), "on tire par-dessus la rivière")
