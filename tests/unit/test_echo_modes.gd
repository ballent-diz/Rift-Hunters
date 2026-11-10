extends TestCase
## Modes des Échos à l'essai (EchoMode) : Actuel (défaut), Relais (un Écho sur le terrain) et Solo (aucun Écho).

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _team(mode: StringName) -> AllyManager:
	run = RunFixture.create(host, &"mossback", 7, false, mode)
	run.ctx.allies.add_monster(&"ashblade")
	run.ctx.allies.add_monster(&"glimmerwing")
	return run.ctx.allies


func test_current_mode_is_default_and_unchanged() -> void:
	check_eq(RunSetup.new().echo_mode, EchoMode.CURRENT, "mode actuel par défaut")
	var allies: AllyManager = _team(EchoMode.CURRENT)
	check_eq(allies.team.size(), 3, "les trois Échos sur le terrain")
	check_eq(allies.roster.size(), 3, "équipe complète")
	check_eq(allies.field_damage_mult(), 1.0, "aucun multiplicateur de dégâts")
	check_eq(EchoMode.altar_hp_mult(run.ctx), 1.0, "autel inchangé")
	check(not allies.relay(run.ctx.player.global_position), "pas de relais en mode actuel")
	for ally: Ally in allies.roster:
		check(not ally.benched and ally.visible, "aucun Écho en réserve")


func test_relay_fields_one_echo() -> void:
	var allies: AllyManager = _team(EchoMode.RELAY)
	check_eq(allies.team.size(), 1, "un seul Écho sur le terrain")
	check_eq(allies.roster.size(), 3, "l'équipe de trois est conservée")
	check_eq(allies.active().data.id, &"mossback", "l'Écho de tête commence")
	check(allies.get_ally(&"ashblade").benched and not allies.get_ally(&"ashblade").visible, "réserve cachée")
	check_eq(allies.team_ids().size(), 3, "les identifiants couvrent l'équipe entière")
	check(run.ctx.build.active_synergies.has(&"breach_and_blade"), "affinités et synergies de l'équipe équipée")
	check_near(allies.active().damage_mult() / allies.get_ally(&"ashblade").damage_mult(), 1.0, 0.001,
		"même multiplicateur pour tous")
	check_near(allies.field_damage_mult(), run.ctx.balance.relay_damage_mult, 0.001, "compensation de BalanceConfig")


func test_relay_cycles_with_cooldown_and_entry_attack() -> void:
	var allies: AllyManager = _team(EchoMode.RELAY)
	var husk: Enemy = RunFixture.spawn(run, &"husk", Vector2(40, 0))
	husk.hp = 100000.0
	husk.max_hp = 100000.0
	var ashblade: Ally = allies.get_ally(&"ashblade")
	ashblade.technique_cd = 3.0
	check(allies.relay(husk.global_position), "relais accepté")
	run.ctx.combat.flush_queue()
	check_eq(allies.active(), ashblade, "Cendrelame entre")
	check(allies.get_ally(&"mossback").benched, "Mousseroc passe en réserve")
	check_near(ashblade.technique_cd, 3.0, 0.001, "attaque d'entrée gratuite : recharge de la Technique intacte")
	check(husk.hp < 100000.0, "l'attaque d'entrée frappe")
	check_near(allies.relay_cd, run.ctx.balance.relay_cooldown, 0.001, "recharge du relais")
	check(not allies.relay(husk.global_position), "relais bloqué pendant la recharge")
	allies.relay_cd = 0.0
	check(allies.relay(husk.global_position), "deuxième relais")
	check_eq(allies.active().data.id, &"glimmerwing", "cycle dans l'ordre de l'équipe")
	allies.relay_cd = 0.0
	allies.relay(husk.global_position)
	check_eq(allies.active().data.id, &"mossback", "retour à l'Écho de tête")
	check_eq(allies.team.size(), 1, "toujours un seul Écho sur le terrain")
	check_eq(int(run.ctx.stats.get_value(&"echo_relays")), 3, "relais comptés")


func test_relay_reserve_follows_and_recharges() -> void:
	var allies: AllyManager = _team(EchoMode.RELAY)
	var reserve: Ally = allies.get_ally(&"glimmerwing")
	reserve.technique_cd = 1.0
	for i: int in 30:
		run._physics_process(1.0 / 60.0)
	check(reserve.technique_cd < 1.0, "la Technique d'un Écho en réserve se recharge")
	check(reserve.global_position.distance_to(run.ctx.player.global_position) < 1.0, "la réserve suit le Chasseur")


func test_relay_offers_cover_whole_team() -> void:
	var allies: AllyManager = _team(EchoMode.RELAY)
	var offers: Array[UpgradeOffer] = UpgradeOffers.candidates(run.ctx)
	var empowered: Array[StringName] = []
	for offer: UpgradeOffer in offers:
		if offer.kind == UpgradeOffer.Kind.EMPOWER:
			empowered.append(offer.monster_id)
	check_eq(empowered.size(), allies.roster.size(), "renforcement proposé pour chaque Écho équipé")


func test_solo_has_no_echo_on_field() -> void:
	var base := RunFixture.create(host, &"mossback")
	var base_damage: float = base.ctx.player.stats.get_value(StatKeys.DAMAGE)
	var base_hp: float = base.ctx.player.max_hp
	RunFixture.dispose(base)
	var allies: AllyManager = _team(EchoMode.SOLO)
	check(allies.team.is_empty(), "aucun Écho sur le terrain")
	check_eq(allies.roster.size(), 3, "Échos équipés conservés (bonus passifs, affinités)")
	check(run.ctx.build.active_synergies.has(&"breach_and_blade"), "synergie de l'équipe équipée active")
	var b: BalanceConfig = run.ctx.balance
	check_near(run.ctx.player.stats.get_value(StatKeys.DAMAGE), base_damage * (1.0 + b.solo_damage_pct), 0.01,
		"dégâts du Chasseur renforcés")
	check_near(run.ctx.player.max_hp, base_hp * (1.0 + b.solo_max_hp_pct), 0.5, "PV max renforcés")
	check_near(run.ctx.player.hp, run.ctx.player.max_hp, 0.5, "départ à PV pleins")
	check_near(EchoMode.altar_hp_mult(run.ctx), b.solo_altar_hp_mult, 0.001, "autel renforcé en Solo")
	for i: int in 30:
		run._physics_process(1.0 / 60.0)
	check(allies.team.is_empty(), "toujours aucun Écho sur le terrain")


func test_echo_mode_setting_saved_and_sanitized() -> void:
	var path: String = Settings.path
	var saved: String = Settings.echo_mode
	Settings.path = "user://test_settings_echo_mode.json"
	Settings.echo_mode = "current"
	Settings.cycle_echo_mode()
	check_eq(Settings.echo_mode, "relay", "Actuel → Relais")
	Settings.load_settings()
	check_eq(Settings.echo_mode, "relay", "réglage relu depuis settings.json")
	Settings.cycle_echo_mode()
	Settings.cycle_echo_mode()
	check_eq(Settings.echo_mode, "current", "Solo → Actuel")
	check_eq(EchoMode.sanitize("bogus"), EchoMode.CURRENT, "valeur inconnue : mode actuel")
	check_eq(Profile.make_run_setup(&"").echo_mode, EchoMode.CURRENT, "la partie reprend le réglage")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.path = path
	Settings.echo_mode = saved
