extends TestCase
## Collection d'Échos étalée sur trois chapitres (docs/design/COLLECTION_ECHOS.md).

var profile: ProfileData
var run: RunController


func before_each() -> void:
	profile = ProfileData.new()


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _win(arena: StringName) -> PackedStringArray:
	var result := {"victory": true, "time": 500.0, "level": 10, "kills": 300, "arena": String(arena),
		"difficulty": "normal", "difficulty_level": 0, "reward_mult": 1.0, "shard_gain": 1.0, "boss_shards": 0,
		"boss_essence": 0, "team": [], "evolutions": [], "relics": [], "synergies": [], "modifiers": [],
		"stats": {"counters": {"victories": 1.0}}}
	return MetaProgression.apply_run_result(profile, result)["lines"]


func _of(source: StringName) -> Array[MonsterData]:
	var list: Array[MonsterData] = []
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		if GameDB.monsters[id].discovery == source:
			list.append(GameDB.monsters[id])
	return list


func test_only_ashblade_at_start_and_every_echo_has_a_source() -> void:
	check_eq(GameDB.monsters.size(), 16, "16 Échos")
	check_eq(EchoCollection.owned_count(profile), 1, "un seul Écho au départ")
	check(profile.is_monster_unlocked(GameDB.monster(&"ashblade")), "Cendrelame au départ")
	var sources: Array[StringName] = [EchoCollection.START, EchoCollection.CAPTURE, EchoCollection.VICTORY,
		EchoCollection.STARS, EchoCollection.SHOP]
	var arenas: Array[StringName] = []
	for monster: MonsterData in GameDB.monsters.values():
		check(sources.has(monster.discovery), "%s : source connue" % monster.id)
		check_eq(monster.unlocked_by_default, monster.discovery == EchoCollection.START, "%s : départ" % monster.id)
		check(EchoCollection.source_text(monster) != "", "%s : source affichée" % monster.id)
		if monster.discovery == EchoCollection.CAPTURE:
			check(not arenas.has(monster.discovery_arena), "%s : un seul Écho par carte" % monster.id)
			arenas.append(monster.discovery_arena)
		if monster.discovery == EchoCollection.SHOP:
			check(monster.shop_price > 0, "%s : prix" % monster.id)
	check(not _of(EchoCollection.SHOP).is_empty() and not _of(EchoCollection.VICTORY).is_empty(),
		"boutique et récompenses")


func test_map_echo_is_a_guaranteed_capture_then_owned_for_good() -> void:
	var target: MonsterData = null
	for monster: MonsterData in _of(EchoCollection.CAPTURE):
		if monster.discovery_arena == &"three_rifts":
			target = monster
	check(target != null, "un Écho à découvrir sur la première carte")
	var setup := RunSetup.new()
	setup.arena_id = &"three_rifts"
	setup.starter_id = &"ashblade"
	setup.autopilot = true
	setup.run_seed = 3
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	var ctx: RunContext = run.ctx
	check_eq(EchoCollection.capture_target(ctx), target.id, "Écho de la carte à découvrir")
	ctx.enemies._maybe_spawn_capture(ctx.player.global_position + Vector2(200, 0))
	check(ctx.pickups.has_capture(target.id), "son Écho errant apparaît à coup sûr")
	ctx.pickups._complete_capture(target.id)
	check(ctx.build.captures.has(target.id), "capturé")
	var result: Dictionary = run.build_result()
	result["stats"] = {"counters": {}}
	MetaProgression.apply_run_result(profile, result)
	check(profile.is_monster_unlocked(target), "débloqué pour toujours")


func test_wandering_echoes_are_only_owned_ones_elsewhere() -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"fractured_plain"
	setup.starter_id = &"ashblade"
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	check_eq(EchoCollection.capture_target(run.ctx), &"", "pas de découverte en survie")


func test_rewards_stars_and_shop() -> void:
	for monster: MonsterData in _of(EchoCollection.VICTORY):
		if GameDB.arena(monster.discovery_arena) == null:
			continue
		_win(monster.discovery_arena)
		check(profile.is_monster_unlocked(monster), "%s : gagné par la victoire" % monster.id)
	for monster: MonsterData in _of(EchoCollection.SHOP):
		check(not EchoCollection.is_for_sale(profile, monster) or monster.discovery_arena == &""
			or Campaign.wins(profile, monster.discovery_arena) > 0, "%s : en vente après sa carte" % monster.id)
		if GameDB.arena(monster.discovery_arena):
			profile = ProfileData.new()
			check(not EchoCollection.is_for_sale(profile, monster), "%s : pas encore en vente" % monster.id)
			_win(monster.discovery_arena)
			check(EchoCollection.is_for_sale(profile, monster), "%s : en vente" % monster.id)


func test_save_v4_keeps_mossback_for_existing_players() -> void:
	var old := {"format_version": 3, "unlocks": {"monsters": ["voltwisp"]}}
	var migrated: Dictionary = SaveMigrations.migrate(old)["data"]
	check((migrated["unlocks"]["monsters"] as Array).has("mossback"), "Mousseroc conservé")
	check((migrated["unlocks"]["monsters"] as Array).has("voltwisp"), "Échos déjà débloqués conservés")
