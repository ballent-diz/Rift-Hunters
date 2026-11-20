extends TestCase
## Premier jet 3D (draft3d/, docs/PREMIER_JET_3D.md) : EXP, niveaux, améliorations du Chasseur seul, absence complète
## des Échos, carte (escaliers, abris, navigation), pause du choix de niveau, défaite, victoire, partie neuve.

## Contrôle de composition (DraftLevelAudit, docs/maps/CARTES_3D.md) sur toutes les cartes. La Cité Effondrée n'a
## aucune incohérence ; les cartes 1 à 4 ont des incohérences relevées le 15 novembre et non corrigées (en attente de
## validation, liste dans CARTES_3D.md) : l'essai échoue si leur nombre augmente.
const KNOWN_ISSUES: Dictionary = {1: 4, 2: 2, 3: 40, 4: 13, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0}
## Étages de la tour du chapitre 6 (DraftTower.floor_level) : aucun écart admis.
const TOWER_FLOORS: Array[int] = [0, 1]

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
	# Cartes de statistiques remises au tirage pour vérifier les plafonds (hors tirage normal de la v2).
	upgrades.tuning = upgrades.tuning.duplicate()
	upgrades.tuning.stat_cards_in_pool = true
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
	# Cartes de statistiques seulement : les cartes de sort ont leurs essais (test_draft3d_spells).
	run.upgrades.spells = null
	run.upgrades.tuning = run.upgrades.tuning.duplicate()
	run.upgrades.tuning.stat_cards_in_pool = true
	var hunter: DraftHunter = run.hunter
	var balance: BalanceConfig = GameDB.balance
	check_eq(hunter.level, 1, "départ au niveau 1")
	hunter.xp_scale = 1.0
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
	# Croissance automatique de la v2 : un palier de dégâts par niveau gagné (3 niveaux ici).
	for level: int in 3:
		sheet.add_modifier(StatKeys.DAMAGE, 0.0, run.tuning.level_damage_pct)
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
	# Flanc de l'escalier : la collision couvre toute la largeur du modèle (±3,5 m), on ne traverse pas ses rebords.
	run.hunter.global_position = Vector3(6.0, 0.2, -10.5)
	run.hunter.reset_motion()
	run.hunter.auto_direction = Vector3(-1, 0, 0)
	await _frames(90)
	check(run.hunter.global_position.x > 3.5, "le flanc de l'escalier arrête le Chasseur : x = %.2f"
		% run.hunter.global_position.x)
	# Rambarde de l'escalier : depuis les marches, on ne passe pas par-dessus (paroi de marche seule).
	run.hunter.global_position = Vector3(0.0, 1.3, -9.5)
	run.hunter.reset_motion()
	run.hunter.auto_direction = Vector3(1, 0, 0)
	await _frames(90)
	check(run.hunter.global_position.x < 2.8 and run.hunter.global_position.y > 0.5,
		"la rambarde retient le Chasseur sur les marches : %s" % run.hunter.global_position)
	check(run.sight_clear(Vector3(-6, 1.6, -9.5), Vector3(6, 1.6, -9.5)), "la rambarde n'arrête ni la vue ni les tirs")
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



## Bug des ennemis bloqués au pied des plateformes : un chemin épuisé alors que le Chasseur, immobile, est sur la
## terrasse doit être recalculé (sinon l'ennemi fonce droit contre le rebord et n'en bouge plus).
func test_enemy_with_spent_path_climbs_to_the_terrace() -> void:
	await _start()
	run.hunter.god_mode = true
	run.hunter.attack_timer = 100000.0
	run.hunter.global_position = Vector3(6, DraftLevelRuins.TERRACE_HEIGHT + 0.2, -16)
	run.hunter.reset_motion()
	await _frames(10)
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"husk"), Vector3(6, 0, -6))
	foe.path = PackedVector3Array([foe.pos])
	foe.path_index = 1
	foe.path_target = run.hunter.global_position
	foe.path_timer = 0.0
	await _frames(720)
	check(foe.pos.y > DraftLevelRuins.TERRACE_HEIGHT - 0.5, "l'ennemi rejoint la terrasse : %s" % foe.pos)

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


func test_rosters_cover_the_nine_chapters() -> void:
	var seen: Dictionary = {}
	check_eq(DraftRoster.chapters().size(), 9, "neuf chapitres : cinq de la campagne, quatre propres à la v2")
	for order: int in range(1, 10):
		var roster: DraftRoster = DraftRoster.for_chapter(order)
		# Famille propre à la v2 : ses sept monstres seulement (docs/design/BOSS_V2.md, section 9).
		var least: int = 7 if DraftRoster.v2_entry(roster.chapter.id).has("enemies") else 8
		check(roster.enemies.size() >= least, "chapitre %d : au moins %d monstres (%d)" % [order, least, roster.enemies.size()])
		check(roster.boss != null and roster.guardians.size() >= 3, "chapitre %d : gardiens et Dévoreur" % order)
		for data: EnemyData in roster.enemies:
			seen[data.id] = true
			check(DraftRoster.usable(data), "%s : mobile et dessiné" % data.id)
		for boss: BossData in roster.guardians + [roster.boss]:
			check(boss.id != &"nebulorax", "Nebulorax est écarté")
			check(Assets.has_sheet(boss.visual.visual_id), "%s : feuille de sprites" % boss.id)
		check_eq(roster.mix(0.0).size(), 1, "première vague : un seul monstre")
		check_eq(roster.mix(1.0).size(), roster.enemies.size(), "dernière vague : tout le bestiaire")
	check(seen.size() >= 40, "au moins quarante monstres différents sur les chapitres (%d)" % seen.size())
	for order: int in range(6, 10):
		check_eq(DraftRoster.for_chapter(order).chapter.order, order, "chapitre %d : rang" % order)


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
	# Direction C : l'arbre v1 ne s'applique plus à la v2 (déblocages DraftUnlocks).
	check_eq(run.hunter.stats.get_value(StatKeys.MAX_HP), GameDB.balance.player_max_hp, "l'arbre v1 ne s'applique plus")
	# Toujours Taille et Lance au départ, même avec un arbre qui équipe d'autres sorts (décision du 15 novembre).
	check_eq(run.spells.slots[0].id, &"cleaving_slash", "Taille au départ malgré l'arbre")
	check_eq(run.spells.slots[1].id, &"prismatic_lance", "Lance au départ malgré l'arbre")
	check_eq(run.spells.free_slots(), DraftSpells.SLOTS - 2, "les deux autres emplacements restent à apprendre")
	run.queue_free()
	run = null
	# Profil neuf : sorts de départ de l'équilibrage (Taille et Lance), qui partent seuls et blessent.
	Profile.profile = ProfileData.new()
	await _start()
	Profile.profile = previous
	check_eq(run.spells.free_slots(), DraftSpells.SLOTS - 2, "deux sorts de départ")
	run.spells.auto_cast = true
	run.hunter.attack_timer = 100000.0
	run.hunter.god_mode = true
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"husk"), run.hunter.global_position + Vector3(2, 0, 0))
	await _frames(480)
	check(run.spells.casts >= 1 and (not foe.alive or foe.hp < foe.max_hp), "le bot lance un sort qui blesse (%d lancés)"
		% run.spells.casts)
	check(run.spells.cooldowns[0] > 0.0 or run.spells.cooldowns[1] > 0.0, "le sort lancé se recharge")
	# Campagne : un chapitre s'ouvre quand le précédent est vaincu ; sauvegarde à part du profil.
	check_eq(DraftSave.path, "", "essais : aucune sauvegarde écrite")
	check(DraftProgress.is_unlocked(1, []) and not DraftProgress.is_unlocked(2, []), "seul le chapitre 1 est ouvert")
	check(DraftProgress.is_unlocked(2, [1]) and not DraftProgress.is_unlocked(3, [1]), "vaincre le 1 ouvre le 2")
	DraftSave.reset()
	DraftProgress.record_victory(1)
	DraftProgress.record_victory(2)
	check_eq(DraftProgress.cleared(), [1, 2] as Array[int], "victoires enregistrées")
	check_eq(DraftProgress.reached(), [1, 2, 3] as Array[int], "chapitres atteints")
	DraftSave.reset()


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


func test_fourth_level_outpost() -> void:
	DraftRun.chosen_chapter = 4
	await _start()
	DraftRun.chosen_chapter = 0
	check(run.level is DraftLevelOutpost, "le chapitre 4 se joue sur l'Avant-poste des Glaces")
	check(run.level.spawn_points().size() >= 60, "points d'apparition sur le pourtour (%d)" % run.level.spawn_points().size())
	for spot: Vector3 in [Vector3(-44, 0, 30), Vector3(44, 0, 30), Vector3(-44, 0, -30), Vector3(44, 0, -30),
			DraftLevelOutpost.BOSS_SPOT, Vector3(0, 0, 3), Vector3(6, DraftLevelOutpost.PLATEAU_HEIGHT, -26)]:
		var route: PackedVector3Array = run.level.path(DraftLevelOutpost.START, spot)
		check(route.size() >= 2 and route[route.size() - 1].distance_to(spot) < 1.5, "quartier relié : %s" % spot)
	var hunter: DraftHunter = run.hunter
	hunter.automating = true
	hunter.global_position = Vector3(0, 0.2, -14)
	hunter.reset_motion()
	hunter.auto_direction = Vector3(0, 0, -1)
	await _frames(110)
	check(hunter.global_position.y > 1.8, "montée du plateau : y = %.2f" % hunter.global_position.y)
	hunter.global_position = Vector3(18, 0.2, 24)
	hunter.reset_motion()
	hunter.auto_direction = Vector3(1, 0, 1)
	await _frames(400)
	var pos: Vector3 = hunter.global_position
	check(pos.x < DraftLevelOutpost.MAX.x + 0.6 and pos.z < DraftLevelOutpost.MAX.y + 0.6 and pos.y > -0.5,
		"limites tenues : %s" % pos)
	hunter.auto_direction = Vector3.ZERO
	check(not run.sight_clear(Vector3(-10, 0.8, -12), Vector3(-10, 0.8, 4)), "un module de la base coupe la vue")
	check(not run.sight_clear(Vector3(0, 0.8, -9), Vector3(0, 0.8, 1)), "le tunnel coupe la vue")
	check(run.sight_clear(Vector3(-3, 0.8, 22), Vector3(3, 0.8, 22)), "l'aire d'atterrissage est dégagée")


func test_fifth_level_city() -> void:
	DraftRun.chosen_chapter = 5
	await _start()
	DraftRun.chosen_chapter = 0
	check(run.level is DraftLevelCity, "le chapitre 5 se joue sur la Cité Effondrée")
	check(run.level.spawn_points().size() >= 60, "points d'apparition sur le pourtour (%d)" % run.level.spawn_points().size())
	for spot: Vector3 in [Vector3(-44, 0, 30), Vector3(44, 0, 30), Vector3(-44, 0, -30), Vector3(44, 0, -30),
			DraftLevelCity.BOSS_SPOT, Vector3(-40, 0, -8), Vector3(-24, 0, 20), Vector3(40, 0, 8), Vector3(20, 0, -14),
			Vector3(35, 0, -14), Vector3(6, DraftLevelCity.TERRACE_HEIGHT, -26)]:
		var route: PackedVector3Array = run.level.path(DraftLevelCity.START, spot)
		check(route.size() >= 2 and route[route.size() - 1].distance_to(spot) < 1.5, "quartier relié : %s" % spot)
	var hunter: DraftHunter = run.hunter
	hunter.automating = true
	hunter.global_position = Vector3(0, 0.2, -14)
	hunter.reset_motion()
	hunter.auto_direction = Vector3(0, 0, -1)
	await _frames(110)
	check(hunter.global_position.y > 1.8, "montée de l'acropole : y = %.2f" % hunter.global_position.y)
	hunter.global_position = Vector3(18, 0.2, 24)
	hunter.reset_motion()
	hunter.auto_direction = Vector3(1, 0, 1)
	await _frames(400)
	var pos: Vector3 = hunter.global_position
	check(pos.x < DraftLevelCity.MAX.x + 0.6 and pos.z < DraftLevelCity.MAX.y + 0.6 and pos.y > -0.5,
		"limites tenues : %s" % pos)
	hunter.auto_direction = Vector3.ZERO
	check(not run.sight_clear(Vector3(-26, 0.8, -26), Vector3(-26, 0.8, -22)), "un mur de maison coupe la vue")
	check(not run.sight_clear(Vector3(-9, 0.8, -8), Vector3(-5, 0.8, -8)), "une colonne du forum abrite")
	check(run.sight_clear(Vector3(-4, 0.8, -6), Vector3(4, 0.8, -6)), "le forum est dégagé")
	check(run.sight_clear(Vector3(-3, 0.8, 22), Vector3(3, 0.8, 22)), "l'avenue est dégagée")


func test_sixth_level_ring() -> void:
	DraftRun.chosen_chapter = 6
	await _start()
	DraftRun.chosen_chapter = 0
	# L'Anneau est le sommet de la tour : on y monte directement (changement d'étage de la partie).
	run.tower.floor_index = DraftLevelRing.TOP_FLOOR
	await run.change_level(DraftTower.floor_level(DraftLevelRing.TOP_FLOOR))
	check(run.level is DraftLevelRing and (run.level as DraftLevelRing).summit(), "sommet de la tour : l'Anneau")
	check(run.level.spawn_points().size() >= 40, "points d'apparition sur l'anneau (%d)" % run.level.spawn_points().size())
	for spot: Vector3 in [DraftLevelRing.BOSS_SPOT, DraftLevelRing.polar(180.0, 37.0), DraftLevelRing.polar(0.0, 37.0),
			DraftLevelRing.polar(270.0, 40.0), DraftLevelRing.polar(120.0, 15.0)]:
		var route: PackedVector3Array = run.level.path(DraftLevelRing.START, spot)
		check(route.size() >= 2 and route[route.size() - 1].distance_to(spot) < 1.5, "secteur relié : %s" % spot)
	# Pas de raccourci par le vide : de la Porte à l'îlot, on passe par une brèche puis une passerelle.
	var route: PackedVector3Array = run.level.path(DraftLevelRing.START, DraftLevelRing.BOSS_SPOT)
	var length: float = 0.0
	for index: int in range(1, route.size()):
		length += route[index - 1].distance_to(route[index])
	check(length > 45.0, "on fait le tour pour atteindre l'îlot (%.0f m)" % length)
	var hunter: DraftHunter = run.hunter
	hunter.automating = true
	hunter.global_position = Vector3(0, 0.2, 31)
	hunter.reset_motion()
	hunter.auto_direction = Vector3(0, 0, -1)
	await _frames(240)
	check(hunter.global_position.z > DraftLevelRing.RING_INNER - 0.8 and hunter.global_position.y > -0.5,
		"le bord du gouffre arrête la marche : %s" % hunter.global_position)
	hunter.auto_direction = Vector3.ZERO
	check(run.sight_clear(Vector3(0, 0.8, 29), Vector3(0, 0.8, 18)), "on tire par-dessus le gouffre")
	check(not run.sight_clear(DraftLevelRing.polar(25.0, 30.0, 0.8), DraftLevelRing.polar(35.0, 30.0, 0.8)),
		"un mur radial coupe la vue")


func test_tower_floors_climb_to_the_summit() -> void:
	DraftRun.chosen_chapter = 6
	await _start()
	DraftRun.chosen_chapter = 0
	check(run.tower != null and run.level is DraftLevelRing, "le chapitre 6 est une tour")
	check((run.level as DraftLevelRing).floor_index == 0 and run.level.exit_point != Vector3.INF, "rez-de-chaussée")
	run.tuning.tower_floor_time = INF
	run.tuning.tower_guardian_delay = 0.0
	var hunter: DraftHunter = run.hunter
	hunter.automating = true
	# Herse fermée : on ne monte pas par la rampe.
	var ramp: Vector2 = DraftLevelRing.FLOORS[0]["ramp"]
	hunter.global_position = DraftLevelRing.polar(ramp.x - 6.0, 44.0, 0.2)
	hunter.reset_motion()
	for frame: int in 150:
		var ahead: Vector3 = DraftLevelRing.polar(ramp.x + 8.0, 44.0) - hunter.global_position
		hunter.auto_direction = Vector3(ahead.x, 0, ahead.z).normalized()
		await host.get_tree().physics_frame
	check(hunter.global_position.y < 0.6 and not run.tower.opened, "la herse arrête le Chasseur : %s" % hunter.global_position)
	var level_before: int = hunter.level
	# Fin de l'étage : la herse se lève, le bot suit la rampe jusqu'au palier.
	run.tuning.tower_floor_time = 0.0
	run._bot = true
	for frame: int in 900:
		if run.tower.floor_index == 1 and run.state == DraftRun.State.PLAYING:
			break
		await host.get_tree().physics_frame
	check(run.tower.floor_index == 1, "montée au premier étage (bot à %s)" % hunter.global_position)
	check((run.level as DraftLevelRing).floor_index == 1, "l'étage des Cellules est chargé")
	check(hunter.level >= level_before, "le Chasseur garde son niveau")
	check(hunter.global_position.distance_to(run.level.start) < 3.0, "arrivée par la porte de l'étage")
	# Étage du gardien : la rampe attend sa défaite.
	await _frames(5)
	check(run._guardian_spawned and run.enemies.boss != null, "le gardien apparaît à son étage")
	check(not run.tower.opened, "la rampe reste fermée tant que le gardien vit")
	if run.enemies.boss != null:
		run.enemies.hit(run.enemies.boss, 1e9)
	for frame: int in 3000:
		if run.tower.summit() and run.state == DraftRun.State.PLAYING:
			break
		await host.get_tree().physics_frame
	check(run.tower.summit() and (run.level as DraftLevelRing).summit(), "arrivée au sommet")
	check(run.enemies.boss == null and not run._boss_spawned, "pas de Dévoreur avant l'heure")
	run.boss_time = 0.0
	run.tuning.tower_boss_delay = 0.0
	await _frames(3)
	check(run._boss_spawned and run.enemies.boss != null and run.enemies.boss.final, "le Dévoreur apparaît au sommet")
	run._bot = false
	hunter.auto_direction = Vector3.ZERO


func test_seventh_level_pass() -> void:
	DraftRun.chosen_chapter = 7
	await _start()
	DraftRun.chosen_chapter = 0
	check(run.level is DraftLevelPass, "le chapitre 7 se joue dans le Défilé Hurlant")
	check(run.level.spawn_points().size() >= 40, "points d'apparition le long de la gorge (%d)" % run.level.spawn_points().size())
	# Chaque passage de chaque goulet est ouvert, et l'arène du boss se gagne d'un bout à l'autre de la gorge.
	for neck: Dictionary in DraftLevelPass.NECKS:
		for gap: Vector2 in neck["open"]:
			var spot := Vector3(float(neck["x"]), 0.2, (gap.x + gap.y) * 0.5)
			var route: PackedVector3Array = run.level.path(DraftLevelPass.START, spot)
			check(route.size() >= 2 and route[route.size() - 1].distance_to(spot) < 1.0, "goulet ouvert : %s" % spot)
	var route: PackedVector3Array = run.level.path(DraftLevelPass.START, DraftLevelPass.BOSS_SPOT)
	check(route.size() >= 2 and route[route.size() - 1].distance_to(DraftLevelPass.BOSS_SPOT) < 1.0, "arène atteinte")
	# Un goulet arrête la vue hors de ses passages ; on tire droit le long d'une clairière.
	check(not run.sight_clear(Vector3(-32, 0.8, -6), Vector3(-24, 0.8, -6)), "la roche du goulet coupe la vue")
	check(run.sight_clear(Vector3(-24, 0.8, 4.5), Vector3(-32, 0.8, 4.5)), "on tire par le passage du goulet")
	var hunter: DraftHunter = run.hunter
	hunter.automating = true
	hunter.global_position = Vector3(-20, 0.2, 0)
	hunter.reset_motion()
	hunter.auto_direction = Vector3(0, 0, -1)
	await _frames(240)
	check(hunter.global_position.z > DraftLevelPass.MIN.y - 0.5, "la falaise tient le Chasseur : %s" % hunter.global_position)
	hunter.auto_direction = Vector3.ZERO


func test_eighth_level_marsh_tide() -> void:
	DraftRun.chosen_chapter = 8
	await _start()
	DraftRun.chosen_chapter = 0
	var marsh := run.level as DraftLevelMarsh
	check(marsh != null, "le chapitre 8 se joue dans le Marais des Marées")
	marsh.set_tide(false)
	var low_route: float = _route_length(DraftLevelMarsh.START, DraftLevelMarsh.BOSS_SPOT)
	check(low_route < 48.0, "marée basse : la levée sud mène tout droit au sanctuaire (%.0f m)" % low_route)
	marsh.set_tide(true)
	await _frames(3)
	var high_route: float = _route_length(DraftLevelMarsh.START, DraftLevelMarsh.BOSS_SPOT)
	check(high_route > low_route + 40.0, "marée haute : on fait le tour par le nord (%.0f m)" % high_route)
	var audit: DraftLevelAudit = DraftLevelAudit.check(marsh)
	check(audit.issues.is_empty(), "marée haute : tout reste atteignable\n%s" % "\n".join(audit.lines()))
	check(run.sight_clear(Vector3(0, 0.8, 27), Vector3(0, 0.8, 7)), "on tire par-dessus l'eau")
	# Levée noyée : le Chasseur n'y entre pas ; à marée basse, il la traverse.
	var hunter: DraftHunter = run.hunter
	hunter.automating = true
	hunter.global_position = Vector3(0, 0.45, 31)
	hunter.reset_motion()
	hunter.auto_direction = Vector3(0, 0, -1)
	await _frames(120)
	check(hunter.global_position.z > 26.0, "la levée noyée est fermée : %s" % hunter.global_position)
	marsh.set_tide(false)
	hunter.global_position = Vector3(0, 0.45, 31)
	hunter.reset_motion()
	await _frames(150)
	check(hunter.global_position.z < 24.0, "à marée basse, la levée se traverse : %s" % hunter.global_position)
	# Éclaboussures : un pas sur une levée basse noyée en fait une, pas à marée basse.
	check(marsh.find_children("Splash", "AnimatedSprite3D", false, false).is_empty(), "pas d'éclaboussure à sec")
	check(marsh.in_water(Vector3(0, 0.0, 16)) == false, "levée sèche à marée basse")
	marsh.set_tide(true)
	check(marsh.in_water(Vector3(0, 0.0, 16)), "levée noyée à marée haute")
	hunter.global_position = Vector3(0, 0.45, 20)
	hunter.reset_motion()
	hunter.auto_direction = Vector3(0, 0, -1)
	var splashed: bool = false
	for frame: int in 90:
		await host.get_tree().physics_frame
		splashed = splashed or not marsh.find_children("Splash", "AnimatedSprite3D", false, false).is_empty()
	check(splashed, "le Chasseur éclabousse en marchant dans l'eau")
	marsh.set_tide(false)
	hunter.auto_direction = Vector3.ZERO
	check(is_equal_approx(DraftLevelMarsh.water_level(0.0), DraftLevelMarsh.WATER_LOW), "cycle : marée basse au départ")
	var peak: float = DraftLevelMarsh.TIDE_LOW + DraftLevelMarsh.TIDE_RISE + 1.0
	check(is_equal_approx(DraftLevelMarsh.water_level(peak), DraftLevelMarsh.WATER_HIGH), "cycle : marée haute")
	# Carte des rives : à jour avec le plan (tools/marsh_shore.tscn), terre à 0, eau lointaine à 1, levées basses en B.
	var fresh: Image = marsh.shore_image()
	var saved := Image.load_from_file(ProjectSettings.globalize_path(DraftLevelMarsh.SHORE_MAP))
	check(saved != null and saved.get_data() == fresh.get_data(), "carte des rives à jour (tools/marsh_shore.tscn)")
	var pixel := func(world: Vector2) -> Color:
		var at: Vector2 = (world - DraftLevelMarsh.SHORE_RECT.position) * DraftLevelMarsh.SHORE_PIXELS_PER_METER
		return fresh.get_pixel(int(at.x), int(at.y))
	check(pixel.call(Vector2(0, -6)).r < 0.01, "rives : le sanctuaire est de la terre sèche")
	check(pixel.call(Vector2(-40, 40)).r > 0.99, "rives : eau loin de toute terre")
	var dike: Color = pixel.call(Vector2(0, 16))
	check(dike.b > 0.99 and dike.g < 0.01 and dike.r > 0.1, "rives : levée basse (terre à marée basse seulement)")
	# Eau peinte (draft3d/marsh/marsh_water.gd) : shader suivant la hauteur d'eau, vase mouillée après le retrait.
	var fx: DraftMarshWater = marsh.water_fx
	var water := marsh.find_child("Water", false, false) as MeshInstance3D
	check(water.material_override == fx.water_material, "l'eau porte le shader du marais")
	var ripples: Texture2DArray = fx.water_material.get_shader_parameter("ripple_tex")
	check(ripples != null and ripples.get_layers() == DraftMarshWater.RIPPLE_FRAMES, "rides : 8 images")
	marsh.set_tide(true)
	await _frames(2)
	check(is_equal_approx(float(fx.water_material.get_shader_parameter("water_level")), DraftLevelMarsh.WATER_HIGH)
		and fx.wetness > 0.99, "marée haute : le shader suit l'eau, levées détrempées")
	marsh.set_tide(false)
	await _frames(10)
	check(fx.wetness > 0.5 and fx.wetness < 1.0, "marée basse : la vase sèche peu à peu (%.2f)" % fx.wetness)
	for file: String in DirAccess.get_files_at("res://draft3d/marsh"):
		if file.ends_with(".png.import"):
			var text: String = FileAccess.get_file_as_string("res://draft3d/marsh/" + file)
			check(text.contains("detect_3d/compress_to=0"), "%s : pas de recompression avec perte en 3D" % file)


func _route_length(from: Vector3, to: Vector3) -> float:
	var route: PackedVector3Array = run.level.path(run.level.closest(from), run.level.closest(to))
	if route.size() < 2 or route[route.size() - 1].distance_to(run.level.closest(to)) > 1.0:
		return INF
	var length: float = 0.0
	for index: int in range(1, route.size()):
		length += route[index - 1].distance_to(route[index])
	return length


func test_ninth_level_cliffs() -> void:
	DraftRun.chosen_chapter = 9
	await _start()
	DraftRun.chosen_chapter = 0
	check(run.level is DraftLevelCliffs, "le chapitre 9 se joue sur les Corniches")
	# Chaque corniche et chaque perchoir est atteignable, à sa hauteur.
	for spot: Vector3 in [Vector3(0, 3, 20), Vector3(0, 6, -8), DraftLevelCliffs.BOSS_SPOT, Vector3(20, 1.5, 44),
			Vector3(-26, 4.5, 17.5), Vector3(18, 7.5, -12)]:
		var target: Vector3 = run.level.closest(spot)
		var route: PackedVector3Array = run.level.path(run.level.closest(DraftLevelCliffs.START), target)
		check(absf(target.y - spot.y) < 0.4 and route.size() >= 2 and route[route.size() - 1].distance_to(target) < 1.0,
			"niveau atteint : %s" % spot)
	check(run.level.inclines.size() >= 10, "rampes, éboulis et pentes des perchoirs (%d)" % run.level.inclines.size())
	# Le Chasseur gravit la première rampe en lacet (ouest) jusqu'au Guet.
	var hunter: DraftHunter = run.hunter
	hunter.automating = true
	hunter.global_position = Vector3(-31, 0.4, 30.5)
	hunter.reset_motion()
	hunter.auto_direction = Vector3(1, 0, 0)
	# Hauteur la plus haute atteinte : plus rapide (réglage de vitesse), le Chasseur peut dépasser le Guet.
	var top: float = hunter.global_position.y
	for frame: int in 240:
		await host.get_tree().physics_frame
		top = maxf(top, hunter.global_position.y)
	check(top > 2.6, "montée par la rampe : %.2f m (arrivée %s)" % [top, hunter.global_position])
	hunter.auto_direction = Vector3.ZERO
	# Les rochers du front de falaise coupent la vue entre deux corniches ; le parvis du sommet est dégagé.
	check(run.sight_clear(Vector3(-6, 9.8, -40), Vector3(6, 9.8, -40)), "le parvis du sommet est dégagé")


func test_level_composition_audit() -> void:
	for chapter: int in KNOWN_ISSUES:
		var level: DraftLevel = DraftLevel.create(chapter)
		host.add_child(level)
		level.build()
		await level.bake()
		var audit: DraftLevelAudit = DraftLevelAudit.check(level)
		var allowed: int = KNOWN_ISSUES[chapter]
		check(audit.issues.size() <= allowed, "carte %d : %d incohérence(s) pour %d connue(s)\n%s" % [
			chapter, audit.issues.size(), allowed, "\n".join(audit.lines())])
		# L'Anneau (carte 6) n'a ni étage ni escalier : son relief est le gouffre.
		check(chapter in [6, 7, 8] or not audit.stairs.is_empty(), "carte %d : escaliers trouvés" % chapter)
		level.queue_free()
		await _frames(3)
	for index: int in TOWER_FLOORS:
		var floor_level: DraftLevelRing = DraftTower.floor_level(index)
		host.add_child(floor_level)
		floor_level.build()
		await floor_level.bake()
		var floor_audit: DraftLevelAudit = DraftLevelAudit.check(floor_level)
		check(floor_audit.issues.is_empty(), "tour, étage %d : %s" % [index, "\n".join(floor_audit.lines())])
		check(floor_level.exit_point != Vector3.INF, "tour, étage %d : palier de sortie" % index)
		floor_level.queue_free()
		await _frames(3)
