extends TestCase
## Arsenal de la v2 (docs/design/GAMEPLAY_V2_ARCHITECTURE.md, lot 2) : acquisition avec cases pleines, réserve,
## échanges sans remise à zéro des recharges ni doublon, 5e case, déblocages permanents (DraftUnlocks) et départ.

const SINGULARITY_CARD := "res://draft3d/spells/learn_singularity.tres"

var run: DraftRun
var _profile: ProfileData


func before_each() -> void:
	_profile = Profile.profile
	Profile.profile = ProfileData.new()
	DraftUnlocks.path = ""
	DraftUnlocks.reset()


func after_each() -> void:
	Profile.profile = _profile
	DraftUnlocks.reset()
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


func test_reserve_and_swaps_keep_cooldowns() -> void:
	await _start()
	var spells: DraftSpells = run.spells
	for id: StringName in [&"rupture", &"rift_leap", &"singularity", &"parry"]:
		check(spells.learn(id), "%s acquis" % id)
	check_eq(spells.free_slots(), 0, "quatre cases pleines")
	check_eq(spells.reserve(), [&"singularity", &"parry"] as Array[StringName], "les suivants vont en réserve")
	spells.cooldowns[0] = 3.0
	check(spells.equip(&"singularity", 0), "la Singularité remplace la Taille")
	check_eq(spells.slots[0].id, &"singularity", "case 1 : Singularité")
	check(spells.reserve().has(&"cleaving_slash"), "la Taille part en réserve")
	check_near(spells.cooldown_left(&"cleaving_slash"), 3.0, 0.001, "sa recharge la suit")
	await _frames(30)
	check(spells.cooldown_left(&"cleaving_slash") < 3.0, "la recharge continue en réserve")
	var left: float = spells.cooldown_left(&"cleaving_slash")
	spells.equip(&"cleaving_slash", 3)
	check_near(spells.cooldowns[3], left, 0.05, "rééquipée : aucune remise à zéro")
	check(spells.reserve().has(&"rift_leap"), "le Bond est passé en réserve")
	var before: Array[StringName] = spells.owned.duplicate()
	spells.equip(&"cleaving_slash", 1)
	check_eq(spells.slots[1].id, &"cleaving_slash", "échange entre deux cases")
	check_eq(spells.slots[3].id, &"prismatic_lance", "la Lance prend l'autre case")
	var equipped: int = 0
	for data: SpellData in spells.slots:
		if data != null and data.id == &"cleaving_slash":
			equipped += 1
	check_eq(equipped, 1, "jamais de doublon")
	check_eq(spells.owned, before, "rien n'est perdu ni dupliqué")
	check(not spells.equip(&"aegis", 0), "un sort non possédé ne s'équipe pas")
	check(spells.stash(2) and spells.slots[2] == null, "ranger un sort libère sa case")
	check(spells.add_slot() and spells.slots.size() == 5, "5e case")
	check(not spells.add_slot(), "jamais de 6e case")
	check(InputMap.has_action(&"spell_5"), "action du 5e sort créée")


func test_new_spell_with_full_slots_asks_where() -> void:
	await _start()
	for id: StringName in [&"rupture", &"rift_leap"]:
		run.spells.learn(id)
	var card: UpgradeData = load(SINGULARITY_CARD)
	run._offers = [card] as Array[UpgradeData]
	run.state = DraftRun.State.CHOOSING
	host.get_tree().paused = true
	run.choose(0)
	await host.get_tree().process_frame
	check(run.hud.arsenal_open(), "le choix de la case s'ouvre")
	var slot_button: Button = run.hud.find_child("Slot3", true, false)
	check(slot_button != null, "une ligne par case")
	slot_button.pressed.emit()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	check_eq(run.spells.slots[2].id, &"singularity", "la Singularité est équipée en case 3")
	check(run.spells.reserve().has(&"rupture"), "la Rupture remplacée part en réserve")
	check(run.state == DraftRun.State.PLAYING and not host.get_tree().paused, "le combat reprend")
	run.toggle_pause()
	var arsenal: Button = run.hud.find_child("Arsenal", true, false)
	check(arsenal != null, "Pause → Arsenal")
	arsenal.pressed.emit()
	await host.get_tree().process_frame
	check(run.hud.find_child("Reserve_rupture", true, false) != null, "la réserve est consultable en pause")


func test_unlocks_currency_and_starting_spells() -> void:
	var unlocks: DraftUnlocks = DraftUnlocks.load()
	check(unlocks.is_unlocked(&"cleaving_slash") and unlocks.is_unlocked(&"prismatic_lance"), "sorts offerts")
	check_eq(unlocks.starting_spells(), [&"cleaving_slash", &"prismatic_lance"] as Array[StringName], "départ par défaut")
	check(not unlocks.unlock(&"rupture"), "pas assez de Fragments")
	unlocks.record_run(unlocks.run_gain(500, 600.0, 2, 0))
	check_eq(unlocks.last_gain(), 50 + 60 + 50, "gain : éliminations, minutes, gardiens")
	check(not unlocks.unlock(&"rupture_blaze"), "une mutation demande son sort")
	check(unlocks.unlock(&"rupture"), "Rupture débloquée")
	check_eq(unlocks.currency(), 10, "coût déduit")
	check(not unlocks.set_starting_spells([&"rupture", &"rupture"] as Array[StringName]), "deux sorts différents")
	check(not unlocks.set_starting_spells([&"rupture", &"singularity"] as Array[StringName]), "seulement débloqués")
	check(unlocks.set_starting_spells([&"rupture", &"prismatic_lance"] as Array[StringName]), "départ choisi")
	var kinds: Dictionary = {}
	for entry: Dictionary in unlocks.entries():
		kinds[entry["kind"]] = true
		for key: String in ["id", "kind", "spell_id", "name_key", "desc_key", "cost", "unlocked", "available"]:
			check(entry.has(key), "entrée %s : %s" % [entry["id"], key])
	check(kinds.has("spell") and kinds.has("variant"), "sorts et mutations")
	var upgrades := DraftUpgrades.new()
	upgrades.unlocks = unlocks
	await _start()
	upgrades.spells = run.spells
	check(not upgrades.can_offer(load(SINGULARITY_CARD)), "sort verrouillé : jamais tiré")
	check(upgrades.can_offer(load("res://draft3d/spells/learn_rupture.tres")), "sort débloqué : tiré")
	check(not upgrades.can_offer(load("res://draft3d/spells/lance_fan.tres")), "mutation verrouillée : jamais tirée")
