extends TestCase
## Sorts actifs du Chasseur dans la base 3D (draft3d/spells.gd, docs/design/SORTS_ACTIFS_V2.md) : emplacements et
## apprentissage, recharges, visée au clavier seul, effets de Taille, Lance, Rupture et Bond, cartes de sort du choix
## de niveau, lancement par le bot, barre de sorts et fenêtre des touches.

var run: DraftRun
var _profile: ProfileData


func before_each() -> void:
	_profile = Profile.profile
	Profile.profile = ProfileData.new()


func after_each() -> void:
	Profile.profile = _profile
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
	run.boss_time = INF
	run.tuning = run.tuning.duplicate()
	run.tuning.waves.assign([{"at": 0.0, "rate": 0.0, "cap": 0, "mix": {"skitterling": 1.0}}])
	run.tuning.swarm_every = INF
	run._swarm_at = INF
	run.hunter.attack_timer = 100000.0
	run.hunter.god_mode = true


func _frames(count: int) -> void:
	for frame: int in count:
		await host.get_tree().physics_frame


func _foe(offset: Vector3) -> DraftEnemies.Foe:
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"husk"), run.hunter.global_position + offset)
	foe.speed = 0.0
	return foe


func _hurt(foe: DraftEnemies.Foe) -> bool:
	return not foe.alive or foe.hp < foe.max_hp


func test_slots_learning_and_cooldowns() -> void:
	await _start()
	var spells: DraftSpells = run.spells
	check_eq(spells.slots.size(), DraftSpells.SLOTS, "quatre emplacements")
	check_eq(spells.slots[0].id, &"cleaving_slash", "Taille sur le premier emplacement")
	check_eq(spells.slots[1].id, &"prismatic_lance", "Lance sur le deuxième")
	check_eq(spells.free_slots(), 2, "deux emplacements libres")
	check(not spells.learn(&"cleaving_slash"), "un sort connu ne s'apprend pas deux fois")
	check(not spells.learn(&"pack_call"), "un sort des Échos est refusé")
	check(spells.learn(&"rupture") and spells.slot_of(&"rupture") == 2, "Rupture prend la première place libre")
	check(spells.learn(&"rift_leap"), "Bond appris")
	check_eq(spells.free_slots(), 0, "barre pleine")
	check(not spells.learn(&"rupture"), "plus de place")
	spells.cooldowns[0] = 0.0
	check(spells.cast(0, run.hunter.global_position + Vector3(3, 0, 0)), "le sort prêt part")
	check(is_equal_approx(spells.cooldowns[0], spells.cooldown_of(spells.slots[0])), "recharge complète")
	check(not spells.cast(0, run.hunter.global_position), "en recharge : rien ne part")
	check(spells.ready_ratio(0) < 0.05, "barre de recharge vide juste après")
	check(not spells.cast(3 + 1, Vector3.ZERO), "emplacement hors limites refusé")


func test_slash_hits_the_arc_in_front_only() -> void:
	await _start()
	var front: DraftEnemies.Foe = _foe(Vector3(2.5, 0, 0))
	var behind: DraftEnemies.Foe = _foe(Vector3(-3.0, 0, 0))
	await _frames(2)
	run.spells.cooldowns[0] = 0.0
	run.spells.cast(0, run.hunter.global_position + Vector3(4, 0, 0))
	check(_hurt(front), "l'ennemi dans l'arc est touché")
	check(not _hurt(behind), "l'ennemi derrière ne l'est pas")


## Bug du slash violet tourné vers le sol : la Taille simple ne joue plus la feuille heavy_cleave.
func test_slash_plays_no_ground_cleave() -> void:
	await _start()
	_foe(Vector3(2.5, 0, 0))
	await _frames(2)
	run.spells.cooldowns[0] = 0.0
	check(run.spells.cast(0, run.hunter.global_position + Vector3(4, 0, 0)), "la Taille part")
	var cleaves: int = 0
	for child: Node in run.get_children():
		if child is DraftPixelFx and (child as DraftPixelFx).texture != null \
				and (child as DraftPixelFx).texture.resource_path.contains("heavy_cleave"):
			cleaves += 1
	check_eq(cleaves, 0, "aucun slash violet heavy_cleave")
	check_eq(run.hunter.view.animation, &"attack", "le Chasseur joue son attaque (arc de lame)")


func test_lance_pierces_the_line() -> void:
	await _start()
	var first: DraftEnemies.Foe = _foe(Vector3(3, 0, 0))
	var second: DraftEnemies.Foe = _foe(Vector3(6, 0, 0))
	var side: DraftEnemies.Foe = _foe(Vector3(0, 0, 4))
	run.spells.cooldowns[1] = 0.0
	check(run.spells.cast(1, run.hunter.global_position + Vector3(8, 0, 0)), "la Lance part")
	await _frames(40)
	check(_hurt(first) and _hurt(second), "la Lance traverse les deux ennemis alignés")
	check(not _hurt(side), "l'ennemi hors de la ligne est épargné")


func test_rupture_hits_the_area_at_the_aim() -> void:
	await _start()
	run.spells.learn(&"rupture")
	var slot: int = run.spells.slot_of(&"rupture")
	var center: DraftEnemies.Foe = _foe(Vector3(6, 0, 0))
	var near: DraftEnemies.Foe = _foe(Vector3(6, 0, 1.2))
	var far: DraftEnemies.Foe = _foe(Vector3(-5, 0, 0))
	await _frames(2)
	run.spells.cooldowns[slot] = 0.0
	check(run.spells.cast(slot, center.pos), "Rupture part")
	check(_hurt(center) and _hurt(near), "les ennemis de la zone sont touchés")
	check(not _hurt(far), "un ennemi loin de la zone est épargné")


func test_leap_moves_protects_and_strikes_on_landing() -> void:
	await _start()
	run.spells.learn(&"rift_leap")
	var slot: int = run.spells.slot_of(&"rift_leap")
	var hunter: DraftHunter = run.hunter
	var start: Vector3 = hunter.global_position
	var waiting: DraftEnemies.Foe = _foe(Vector3(5.5, 0, 0))
	await _frames(2)
	run.spells.cooldowns[slot] = 0.0
	check(run.spells.cast(slot, start + Vector3(5, 0, 0)), "le Bond part")
	check(hunter.is_leaping() and hunter.invulnerable > 0.0, "invulnérable pendant le saut")
	check(not run.spells.cast(0, start), "aucun autre sort pendant le saut")
	await _frames(30)
	check(not hunter.is_leaping(), "le saut est fini")
	var moved: float = hunter.global_position.distance_to(start)
	check(moved > 3.0, "le Chasseur a bondi (%.1f m)" % moved)
	check(_hurt(waiting), "l'onde d'arrivée frappe")
	check(hunter.global_position.distance_to(start) <= run.spells.reach_of(GameDB.spells[&"rift_leap"]) + 0.5,
		"portée du Bond respectée")


func test_keyboard_aim_picks_the_foe_in_front() -> void:
	await _start()
	var front: DraftEnemies.Foe = _foe(Vector3(5, 0, 0.5))
	var behind: DraftEnemies.Foe = _foe(Vector3(-3, 0, 0))
	await _frames(2)
	var here: Vector3 = run.hunter.global_position
	check(run.spells.facing_aim(Vector3.RIGHT).distance_to(front.pos) < 0.01, "vise l'ennemi devant")
	var empty: Vector3 = run.spells.facing_aim(Vector3(0, 0, 1))
	check(empty.distance_to(here + Vector3(0, 0, run.tuning.aim_distance)) < 0.01, "sans cible : droit devant")
	check(behind.pos.distance_to(run.spells.facing_aim(Vector3.RIGHT)) > 1.0, "jamais l'ennemi derrière")


func test_spell_cards_in_level_up_choice() -> void:
	await _start()
	var upgrades: DraftUpgrades = run.upgrades
	var learn_rupture: UpgradeData = load("res://draft3d/spells/learn_rupture.tres")
	var learn_slash: UpgradeData = load("res://draft3d/spells/learn_cleaving_slash.tres")
	check(upgrades.available().has(learn_rupture), "Rupture s'offre : place libre et sort inconnu")
	check(not upgrades.available().has(learn_slash), "Taille déjà connue : jamais offerte")
	check(upgrades.apply(learn_rupture, run.hunter.stats) and run.spells.has_spell(&"rupture"), "la carte apprend le sort")
	run.spells.learn(&"rift_leap")
	for data: UpgradeData in upgrades.available():
		check(not String(data.id).begins_with("learn_"), "barre pleine : plus aucune carte d'apprentissage (%s)" % data.id)
	var detached := DraftUpgrades.new()
	check(not detached.available().has(learn_rupture), "sans sorts branchés, aucune carte de sort")


func test_bot_casts_and_hud_shows_slots() -> void:
	await _start()
	run.spells.auto_cast = true
	var foe: DraftEnemies.Foe = _foe(Vector3(2, 0, 0))
	await _frames(240)
	check(run.spells.casts >= 1 and _hurt(foe), "le bot lance ses sorts (%d)" % run.spells.casts)
	var bar: DraftSpellBar = run.hud.find_child("SpellBar", true, false)
	check(bar != null and bar.spells == run.spells, "barre de sorts branchée")
	check(not run.spells.reticle.visible, "aucun anneau de visée pour le bot")
	run.spells.auto_cast = false
	await _frames(2)
	check(run.spells.reticle.visible, "anneau de visée au sol pour le joueur")


func test_controls_window_rebinds_spells() -> void:
	var options := DraftOptions.new()
	host.add_child(options)
	await host.get_tree().process_frame
	var keys: Button = options.find_child("Keys", true, false)
	check(keys != null, "bouton Touches et visée dans les options")
	keys.pressed.emit()
	await host.get_tree().process_frame
	var window: DraftControls = options.get_node_or_null("ControlsWindow")
	check(window != null, "fenêtre des touches ouverte")
	for action: StringName in [&"spell_1", &"spell_2", &"spell_3", &"spell_4", &"dash"]:
		check(window.find_child(String(action), true, false) is KeyBindButton, "touche reconfigurable : %s" % action)
	options.queue_free()


func _card(id: String) -> UpgradeData:
	return load("res://draft3d/spells/%s.tres" % id)


func test_rank_and_variant_cards_follow_the_rules() -> void:
	await _start()
	var upgrades: DraftUpgrades = run.upgrades
	var slash: SpellData = GameDB.spells[&"cleaving_slash"]
	check_eq(upgrades.spell_cards.size(), 64, "64 cartes : 15 sorts, 30 variantes, 19 rangs")
	for data: UpgradeData in upgrades.spell_cards:
		check(tr(data.name_key) != data.name_key and tr(data.desc_key) != data.desc_key, "%s : textes traduits" % data.id)
	check(not upgrades.available().has(_card("rupture_wide")), "aucun rang pour un sort inconnu")
	check(not upgrades.available().has(_card("leap_impact")), "aucune variante pour un sort inconnu")
	var base_damage: float = run.spells.damage_of(slash)
	var base_cooldown: float = run.spells.cooldown_of(GameDB.spells[&"prismatic_lance"])
	check(upgrades.apply(_card("slash_edge"), run.hunter.stats), "rang de dégâts pris")
	check_near(run.spells.damage_of(slash), base_damage * 1.2, 0.01, "dégâts de la Taille +20 %")
	upgrades.apply(_card("lance_tempo"), run.hunter.stats)
	check_near(run.spells.cooldown_of(GameDB.spells[&"prismatic_lance"]), base_cooldown * 0.85, 0.01, "recharge −15 %")
	check(upgrades.apply(_card("slash_whirlwind"), run.hunter.stats), "variante prise")
	check_eq(run.spells.variant_of(slash), &"whirlwind", "Tourbillon actif")
	check(not upgrades.can_offer(_card("slash_thrust")), "une seule variante par sort")
	check(not upgrades.apply(_card("slash_thrust"), run.hunter.stats), "l'autre variante est refusée")


func test_slash_variants() -> void:
	await _start()
	run.upgrades.apply(_card("slash_whirlwind"), run.hunter.stats)
	var behind: DraftEnemies.Foe = _foe(Vector3(-2.5, 0, 0))
	await _frames(2)
	run.spells.cooldowns[0] = 0.0
	run.spells.cast(0, run.hunter.global_position + Vector3(4, 0, 0))
	check(_hurt(behind), "Tourbillon : l'ennemi derrière est touché")
	run.queue_free()
	run = null
	await _start()
	run.upgrades.apply(_card("slash_thrust"), run.hunter.stats)
	var far: DraftEnemies.Foe = _foe(Vector3(8, 0, 0))
	var aside: DraftEnemies.Foe = _foe(Vector3(3, 0, 2.5))
	await _frames(2)
	run.spells.cooldowns[0] = 0.0
	run.spells.cast(0, run.hunter.global_position + Vector3(4, 0, 0))
	check(_hurt(far), "Estoc : la ligne longue atteint l'ennemi à 8 m")
	check(not _hurt(aside), "Estoc : étroit, l'ennemi à côté est épargné")


func test_lance_variants() -> void:
	await _start()
	run.upgrades.apply(_card("lance_fan"), run.hunter.stats)
	var before: int = run.bolts.size()
	run.spells.cooldowns[1] = 0.0
	run.spells.cast(1, run.hunter.global_position + Vector3(5, 0, 0))
	check_eq(run.bolts.size() - before, 3, "Éventail : trois lances")
	var fan_damage: float = float(run.bolts[run.bolts.size() - 1]["damage"])
	check_near(fan_damage, run.spells.damage_of(GameDB.spells[&"prismatic_lance"]) * 0.8, 0.01, "80 % des dégâts")
	run.queue_free()
	run = null
	await _start()
	run.upgrades.apply(_card("lance_overcharge"), run.hunter.stats)
	var lance: SpellData = GameDB.spells[&"prismatic_lance"]
	run.spells.charge_time = 0.0
	check_near(run.spells.charge_power(lance), 1.0, 0.01, "Surcharge à vide : ×1")
	run.spells.charge_time = 5.0
	check_near(run.spells.charge_power(lance), 2.5, 0.01, "Surcharge pleine : ×2,5")
	run.spells.cooldowns[1] = 0.0
	run.spells.cast(1, run.hunter.global_position + Vector3(5, 0, 0), 2.5)
	check_near(float(run.bolts[run.bolts.size() - 1]["damage"]), run.spells.damage_of(lance) * 2.5, 0.01, "lance chargée")


func test_rupture_variants() -> void:
	await _start()
	run.spells.learn(&"rupture")
	var slot: int = run.spells.slot_of(&"rupture")
	run.upgrades.apply(_card("rupture_reaction"), run.hunter.stats)
	var center: DraftEnemies.Foe = _foe(Vector3(5, 0, 0))
	var chained: DraftEnemies.Foe = _foe(Vector3(9, 0, 0))
	await _frames(2)
	run.spells.cooldowns[slot] = 0.0
	run.spells.cast(slot, center.pos)
	check(_hurt(chained), "Réaction : la détonation rebondit sur l'ennemi voisin")
	run.queue_free()
	run = null
	await _start()
	run.spells.learn(&"rupture")
	slot = run.spells.slot_of(&"rupture")
	run.upgrades.apply(_card("rupture_blaze"), run.hunter.stats)
	run.spells.cooldowns[slot] = 0.0
	var spot: Vector3 = run.hunter.global_position + Vector3(5, 0, 0)
	run.spells.cast(slot, spot)
	var walker: DraftEnemies.Foe = _foe(Vector3(5, 0, 0))
	await _frames(45)
	check(_hurt(walker), "Brasier : le sol brûle encore après la détonation")
	await _frames(200)
	check(run.spells._zones.is_empty(), "le Brasier s'éteint")


func test_leap_variants() -> void:
	await _start()
	run.spells.learn(&"rift_leap")
	var slot: int = run.spells.slot_of(&"rift_leap")
	run.upgrades.apply(_card("leap_return"), run.hunter.stats)
	var start: Vector3 = run.hunter.global_position
	run.spells.cooldowns[slot] = 0.0
	run.spells.cast(slot, start + Vector3(5, 0, 0))
	await _frames(30)
	check(run.hunter.global_position.distance_to(start) > 3.0, "le Bond est parti")
	check(run.spells.leap_back(), "Retour : la touche ramène au départ")
	await _frames(30)
	check(run.hunter.global_position.distance_to(start) < 1.0, "revenu au point de départ")
	check(not run.spells.leap_back(), "un seul retour")
	run.queue_free()
	run = null
	await _start()
	run.spells.learn(&"rift_leap")
	slot = run.spells.slot_of(&"rift_leap")
	run.upgrades.apply(_card("leap_impact"), run.hunter.stats)
	var leap: SpellData = GameDB.spells[&"rift_leap"]
	check_near(run.spells.area_of(leap), leap.width * DraftHunter.UNIT * 2.0, 0.01, "Impact : onde 2× plus large")
	var tough: DraftEnemies.Foe = _foe(Vector3(6, 0, 0))
	tough.hp = 100000.0
	tough.max_hp = 100000.0
	await _frames(2)
	run.spells.cooldowns[slot] = 0.0
	run.spells.cast(slot, run.hunter.global_position + Vector3(5, 0, 0))
	await _frames(30)
	check(tough.slow_left > 0.0 and is_equal_approx(tough.slow_factor, 0.5), "Impact : l'ennemi est ralenti")


func _learn(id: StringName) -> int:
	run.spells.learn(id)
	var slot: int = run.spells.slot_of(id)
	run.spells.cooldowns[slot] = 0.0
	return slot


func test_v1_pool_is_wired_but_echo_spells_are_not() -> void:
	for id: StringName in [&"parry", &"singularity", &"rift_wall", &"aegis", &"refracting_crystal"]:
		check(DraftSpells.supported(id), "sort v1 raccordé : %s" % id)
	for id: StringName in [&"pack_call", &"swap", &"twin_rifts"]:
		check(not DraftSpells.supported(id), "non repris : %s" % id)


func test_parry_counters_and_recharges() -> void:
	await _start()
	run.hunter.god_mode = false
	var slot: int = _learn(&"parry")
	var foe: DraftEnemies.Foe = _foe(Vector3(1.2, 0, 0))
	await _frames(2)
	check(run.spells.cast(slot, run.hunter.global_position), "la garde part")
	var hp: float = run.hunter.hp
	check_eq(run.hunter.take_damage(30.0), 0.0, "le coup paré n'inflige rien")
	check_eq(run.hunter.hp, hp, "PV intacts")
	check(_hurt(foe), "contre-attaque")
	check(not foe.alive or foe.slow_left > 0.0, "étourdissement")
	check_eq(run.spells.cooldowns[slot], 0.0, "parade réussie : recharge remise à zéro")
	run.hunter.invulnerable = 0.0
	check(run.hunter.take_damage(5.0) > 0.0, "hors garde, le coup porte")


func test_singularity_pulls_then_implodes() -> void:
	await _start()
	var slot: int = _learn(&"singularity")
	var foe: DraftEnemies.Foe = _foe(Vector3(6, 0, 2))
	await _frames(2)
	var center: Vector3 = run.hunter.global_position + Vector3(6, 0, 0)
	var before: float = DraftSpells._flat(foe.pos - center).length()
	run.spells.cast(slot, center)
	await _frames(60)
	check(DraftSpells._flat(foe.pos - center).length() < before - 0.3, "l'ennemi est attiré")
	check(not _hurt(foe), "pas de dégâts avant l'implosion")
	await _frames(150)
	check(_hurt(foe), "l'implosion blesse")
	check(run.spells.world.wells.is_empty(), "le puits disparaît")


func test_wall_blocks_enemies_and_shots() -> void:
	await _start()
	var slot: int = _learn(&"rift_wall")
	var here: Vector3 = run.hunter.global_position
	run.spells.cast(slot, here + Vector3(3, 0, 0))
	check_eq(run.spells.world.walls.size(), 1, "un mur posé")
	check(run.barrier_blocks(here + Vector3(5, 0, 0), here + Vector3(1, 0, 0)), "le mur coupe le passage")
	check(not run.barrier_blocks(here + Vector3(1, 0, 0), here + Vector3(1, 0, 3)), "à côté, le passage est libre")
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"husk"), here + Vector3(5, 0, 0))
	await _frames(90)
	check(DraftSpells._flat(foe.pos - here).x > 2.5, "l'ennemi reste derrière le mur")
	await _frames(240)
	check(run.spells.world.walls.is_empty(), "le mur s'efface")


func test_aegis_absorbs_and_riposte() -> void:
	await _start()
	run.hunter.god_mode = false
	run.upgrades.apply(_card("learn_aegis"), run.hunter.stats)
	run.upgrades.apply(_card("aegis_riposte"), run.hunter.stats)
	var slot: int = run.spells.slot_of(&"aegis")
	run.spells.cooldowns[slot] = 0.0
	var foe: DraftEnemies.Foe = _foe(Vector3(1.5, 0, 0))
	foe.damage = 0.0
	await _frames(2)
	run.spells.cast(slot, run.hunter.global_position)
	var shield: float = run.hunter.shield
	check_near(shield, run.hunter.max_hp() * 0.25, 0.01, "bouclier de 25 % des PV max")
	var hp: float = run.hunter.hp
	run.hunter.take_damage(shield * 0.5)
	check_eq(run.hunter.hp, hp, "le bouclier absorbe")
	run.hunter.invulnerable = 0.0
	run.hunter.take_damage(shield)
	check(run.hunter.hp < hp and run.hunter.shield <= 0.0, "le bouclier cède, le reste porte")
	check(_hurt(foe), "Riposte : l'onde blesse l'ennemi proche")


func test_crystal_splits_bolts() -> void:
	await _start()
	var slot: int = _learn(&"refracting_crystal")
	var here: Vector3 = run.hunter.global_position
	run.spells.cast(slot, here + Vector3(3, 0, 0))
	check_eq(run.spells.world.crystals.size(), 1, "un cristal posé")
	var before: int = run.bolts.size()
	run.fire_bolt(run.hunter.chest(), Vector3.RIGHT, 10.0, 10.0, 0, 0)
	await _frames(20)
	check(run.bolts.size() - before >= 1 + run.tuning.crystal_split or run.bolts.size() >= before + 2,
		"le trait se divise en traversant le cristal (%d traits)" % (run.bolts.size() - before))


func _cast_new(id: StringName, aim: Vector3, variant: String = "") -> int:
	run.upgrades.apply(_card("learn_" + String(id)), run.hunter.stats)
	if variant != "":
		check(run.upgrades.apply(_card(variant), run.hunter.stats), "variante %s prise" % variant)
	var slot: int = run.spells.slot_of(id)
	run.spells.cooldowns[slot] = 0.0
	check(run.spells.cast(slot, aim), "%s part" % id)
	return slot


func test_new_spells_are_wired_with_texts() -> void:
	for id: StringName in [&"hunter_mark", &"void_rend", &"rift_step", &"stasis_wave", &"shard_rain", &"ash_veil"]:
		var data: SpellData = DraftSpells.spell(id)
		check(data != null and DraftSpells.supported(id), "sort v2 raccordé : %s" % id)
		check(tr(data.name_key) != data.name_key and tr(data.desc_key) != data.desc_key, "%s : textes traduits" % id)
		check(DraftSpellBar._fx_icon(data) != null, "%s : icône tirée de son effet" % id)
		check(not GameDB.spells.has(id), "%s : propre à la v2, hors des données de la campagne" % id)


func test_tracker_mark_exposes_and_draws_the_bolt() -> void:
	await _start()
	var near: DraftEnemies.Foe = _foe(Vector3(3, 0, 0))
	var tough: DraftEnemies.Foe = _foe(Vector3(7, 0, 0))
	tough.max_hp = 500.0
	tough.hp = 500.0
	await _frames(2)
	_cast_new(&"hunter_mark", tough.pos)
	check(run.spells.rift.marked == tough, "la marque prend l'ennemi visé")
	check_eq(run.target(), tough, "le Trait vise la cible marquée avant la plus proche")
	run.enemies.hit(tough, 100.0)
	check_near(tough.max_hp - tough.hp, 100.0 * 1.3 * CombatSystem.defense_multiplier(tough.defense), 0.01, "+30 % de dégâts")
	check(near.alive, "l'autre ennemi n'est pas concerné")


func test_mark_variants() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _foe(Vector3(5, 0, 0))
	foe.max_hp = 1000.0
	foe.hp = 1000.0
	foe.defense = 0.0
	await _frames(2)
	_cast_new(&"hunter_mark", foe.pos, "mark_execute")
	run.enemies.hit(foe, 300.0)
	await _frames(2)
	check(foe.alive, "au-dessus du seuil : la cible tient")
	run.enemies.hit(foe, 350.0)
	check(foe.alive and foe.hp < foe.max_hp * 0.2, "sous le seuil, encore debout (%.0f PV)" % foe.hp)
	await _frames(2)
	check(not foe.alive, "Exécution : sous 20 %, la cible est achevée")
	run.queue_free()
	run = null
	await _start()
	var first: DraftEnemies.Foe = _foe(Vector3(5, 0, 0))
	var second: DraftEnemies.Foe = _foe(Vector3(7, 0, 1))
	await _frames(2)
	_cast_new(&"hunter_mark", first.pos, "mark_hunt")
	run.enemies.hit(first, 100000.0)
	await _frames(2)
	check(run.spells.rift.marked == second, "Traque : la marque saute sur l'ennemi voisin")


func test_void_rend_strikes_the_first_foe_and_moves() -> void:
	await _start()
	var start: Vector3 = run.hunter.global_position
	var first: DraftEnemies.Foe = _foe(Vector3(2, 0, 0))
	var second: DraftEnemies.Foe = _foe(Vector3(4, 0, 0))
	await _frames(2)
	_cast_new(&"void_rend", start + Vector3(6, 0, 0))
	check(run.hunter.is_leaping() and run.hunter.invulnerable > 0.0, "fente invulnérable")
	check(_hurt(first) and not _hurt(second), "seul le premier ennemi est frappé")
	await _frames(20)
	check(run.hunter.global_position.distance_to(start) > 3.0, "le Chasseur a traversé")
	run.queue_free()
	run = null
	await _start()
	start = run.hunter.global_position
	first = _foe(Vector3(2, 0, 0))
	second = _foe(Vector3(4, 0, 0))
	await _frames(2)
	var slot: int = _cast_new(&"void_rend", start + Vector3(6, 0, 0), "rend_pierce")
	check(_hurt(first) and _hurt(second), "Fente perçante : toute la ligne")
	run.queue_free()
	run = null
	await _start()
	slot = _cast_new(&"void_rend", run.hunter.global_position + Vector3(4, 0, 0), "rend_double")
	await _frames(20)
	check(run.spells.ready(slot), "Double fente : la seconde est prête")
	check(run.spells.cast(slot, run.hunter.global_position + Vector3(-4, 0, 0)), "seconde fente")
	check(run.spells.cooldowns[slot] > 0.0, "puis la recharge complète")


func test_rift_step_teleports_and_shadow_bursts() -> void:
	await _start()
	var start: Vector3 = run.hunter.global_position
	var waiting: DraftEnemies.Foe = _foe(Vector3(0, 0, 0.8))
	await _frames(2)
	_cast_new(&"rift_step", start + Vector3(5, 0, 0), "step_trap")
	check(run.hunter.global_position.distance_to(start) > 3.0, "téléporté aussitôt")
	check(not _hurt(waiting), "l'ombre n'a pas encore éclaté")
	await _frames(75)
	check(_hurt(waiting) and (not waiting.alive or waiting.slow_left > 0.0), "l'ombre éclate et ralentit")
	run.queue_free()
	run = null
	await _start()
	var slot: int = _cast_new(&"rift_step", run.hunter.global_position + Vector3(3, 0, 0), "step_charges")
	check(run.spells.ready(slot), "Deux charges : une charge reste")
	check(run.spells.cast(slot, run.hunter.global_position + Vector3(-3, 0, 0)), "second pas")
	check(not run.spells.ready(slot), "plus de charge")


func test_stasis_freezes_the_cone() -> void:
	await _start()
	var front: DraftEnemies.Foe = _foe(Vector3(3, 0, 0))
	front.hp = 1000.0
	front.max_hp = 1000.0
	var behind: DraftEnemies.Foe = _foe(Vector3(-3, 0, 0))
	await _frames(2)
	_cast_new(&"stasis_wave", run.hunter.global_position + Vector3(4, 0, 0), "stasis_shards")
	check(front.slow_left > 0.0 and is_zero_approx(front.slow_factor), "l'ennemi du cône est figé")
	check(front.exposed_left > 0.0, "Éclats de stase : il subit plus de dégâts")
	check(behind.slow_left <= 0.0 and not _hurt(behind), "l'ennemi derrière est épargné")


func test_shard_rain_and_storm() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _foe(Vector3(6, 0, 0))
	await _frames(2)
	_cast_new(&"shard_rain", foe.pos)
	await _frames(40)
	check(_hurt(foe), "les éclats frappent la zone")
	await _frames(200)
	check(run.spells._zones.is_empty(), "la pluie s'arrête")
	run.queue_free()
	run = null
	await _start()
	_cast_new(&"shard_rain", run.hunter.global_position, "rain_storm")
	run.hunter.global_position += Vector3(4, 0, 0)
	await _frames(2)
	check((run.spells._zones[0]["at"] as Vector3).distance_to(run.hunter.global_position) < 0.5, "Orage : suit le Chasseur")


func test_ash_veil_destroys_shots_and_heals() -> void:
	await _start()
	run.hunter.hp = run.hunter.max_hp() * 0.5
	_cast_new(&"ash_veil", run.hunter.global_position, "veil_recoil")
	var visual: Sprite3D = run.fx(&"arcane_orb", DraftPixelFx.DEFAULT_FAMILY, run.hunter.chest(), 0.5, true)
	run.hostile.append({"at": run.hunter.chest() + Vector3(2, 0, 0), "dir": Vector3.LEFT, "speed": 0.0, "left": 4.0,
		"damage": 10.0, "visual": visual, "family": DraftPixelFx.DEFAULT_FAMILY})
	var hp: float = run.hunter.hp
	await _frames(2)
	check(run.hostile.is_empty() and run.spells.rift.shots_blocked == 1, "le tir est détruit")
	check(run.hunter.hp > hp, "Contrecoup : PV rendus")


func test_bot_casts_the_new_spells() -> void:
	await _start()
	run.spells.slots.fill(null)
	for id: StringName in [&"rift_step", &"shard_rain", &"ash_veil", &"stasis_wave"]:
		run.spells.learn(id)
	run.spells.cooldowns.fill(0.0)
	run.spells.auto_cast = true
	for offset: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0.3), Vector3(0, 0, 1), Vector3(0.6, 0, -0.8),
			Vector3(4, 0, 0), Vector3(4.5, 0, 0.5)]:
		var foe: DraftEnemies.Foe = _foe(offset)
		foe.hp = 100000.0
		foe.max_hp = 100000.0
	await _frames(30)
	check(run.spells.casts >= 3, "le bot lance les nouveaux sorts (%d)" % run.spells.casts)


func test_cooldowns_under_the_hunter() -> void:
	await _start()
	var pips: DraftSpellPips = run.hud.find_child("SpellPips", true, false)
	check(pips != null and pips.run == run, "recharges sous le Chasseur branchées")
	var feet: Vector3 = run.hunter.global_position
	var point: Vector2 = run.screen_point(feet)
	var size: Vector2 = run.get_viewport().get_visible_rect().size
	check(Rect2(Vector2.ZERO, size).has_point(point), "le Chasseur est à l'écran (%s)" % point)
	if run.camera.get_viewport() == run.get_viewport():
		check(point.distance_to(run.camera.unproject_position(feet)) < 2.0, "même position que la caméra")


func test_spell_icons_everywhere() -> void:
	for data: UpgradeData in DraftUpgrades.new().spell_cards:
		var spell: SpellData = DraftHud.spell_of(data)
		check(spell != null and DraftSpellBar.icon_for(spell) != null, "%s : icône du sort" % data.id)
	await _start()
	run.hud.show_offers(2, [_card("learn_rupture"), _card("slash_edge")] as Array[UpgradeData], run.upgrades)
	var icons: int = 0
	for node: Node in run.hud.find_children("SpellIcon", "TextureRect", true, false):
		icons += 1
	check_eq(icons, 2, "les cartes de sort montrent l'icône du sort")
	run.hud.hide_offers()


func test_v1_animations_play_on_the_ground() -> void:
	await _start()
	for id: String in ["cleaving_slash", "prismatic_lance", "rift_leap", "parry", "rupture", "refractor_crystal",
			"singularity", "rift_wall", "rift_aegis"]:
		check(DraftSpellVfx.scene(id) != null, "animation v1 présente : %s" % id)
	run.spells.cooldowns[0] = 0.0
	run.spells.cast(0, run.hunter.global_position + Vector3(4, 0, 0))
	check_eq(run.spells.vfx.playing.size(), 1, "la Taille joue son animation peinte")
	var before: int = run.bolts.size()
	run.spells.cooldowns[1] = 0.0
	run.spells.cast(1, run.hunter.global_position + Vector3(4, 0, 0))
	check_eq(run.spells.vfx.playing.size(), 2, "la Lance joue son animation prismatique")
	check((run.bolts[before]["visual"] as Sprite3D).texture == null, "le trait de jeu de la Lance est invisible")
	await _frames(90)
	check(run.spells.vfx.playing.is_empty(), "les animations finies sont retirées")


func test_upgrade_cards_show_v1_art() -> void:
	await _start()
	var shared: Array[UpgradeData] = []
	for id: StringName in DraftUpgrades.SHARED:
		check(ItemArt.texture("upgrade", id) != null, "%s : illustration de la v1" % id)
		shared.append(GameDB.upgrades[id])
	run.hud.show_offers(2, [shared[0], shared[1], _card("learn_rupture")] as Array[UpgradeData], run.upgrades)
	check_eq(run.hud.find_children("UpgradeArt", "TextureRect", true, false).size(), 2, "illustrations sur les cartes")
	check_eq(run.hud.find_children("SpellIcon", "TextureRect", true, false).size(), 1, "icône sur la carte de sort")
	run.hud.hide_offers()
