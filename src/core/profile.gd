extends Node
## Progression du joueur (autoload « Profile ») : chargement sûr, migrations, sauvegarde atomique,
## construction des paramètres de partie à partir des déblocages, de l'arbre et de la maîtrise.

signal changed

enum LoadState { OK, NEW_PROFILE, RESTORED_FROM_BACKUP, CORRUPTED_RESET, NEWER_VERSION, MIGRATED }

var path: String = "user://profile.json"
var profile := ProfileData.new()
var load_state: LoadState = LoadState.NEW_PROFILE
## Mode lecture seule : sauvegarde d'une version plus récente du jeu (jamais écrasée).
var read_only: bool = false
var last_report: Dictionary = {}


func _ready() -> void:
	load_profile()


func load_profile(custom_path: String = "") -> void:
	if custom_path != "":
		path = custom_path
	read_only = false
	var store := SafeJsonStore.new(path)
	var raw: Dictionary = store.load_data(ProfileData.validate)
	match store.last_status:
		SafeJsonStore.LoadStatus.MISSING:
			load_state = LoadState.NEW_PROFILE
			profile = ProfileData.new()
			return
		SafeJsonStore.LoadStatus.CORRUPTED_NO_BACKUP:
			# Le fichier corrompu est conservé en quarantaine ; on repart d'un profil neuf, et le joueur est averti.
			load_state = LoadState.CORRUPTED_RESET
			profile = ProfileData.new()
			return
		SafeJsonStore.LoadStatus.RESTORED_FROM_BACKUP:
			load_state = LoadState.RESTORED_FROM_BACKUP
		_:
			load_state = LoadState.OK
	var migration: Dictionary = SaveMigrations.migrate(raw)
	if migration["error"] == "newer_version":
		load_state = LoadState.NEWER_VERSION
		read_only = true
		profile = ProfileData.new(raw)
		return
	if migration["error"] != "":
		push_error("Migration impossible : %s" % migration["error"])
		read_only = true
	profile = ProfileData.new(migration["data"])
	if int(migration["from"]) < int(migration["to"]) and load_state == LoadState.OK:
		load_state = LoadState.MIGRATED
		save()


func save() -> Error:
	if read_only:
		return ERR_UNAVAILABLE
	profile.data["format_version"] = SaveMigrations.CURRENT_VERSION
	profile.data["game_version"] = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	profile.data["saved_at"] = int(Time.get_unix_time_from_system())
	var error: Error = SafeJsonStore.new(path).save_data(profile.data)
	if error != OK:
		push_error("Sauvegarde impossible : %s" % error_string(error))
	changed.emit()
	return error


## Nouvelle partie : profil vierge sauvegardé (les réglages, à part, sont conservés).
func reset_profile() -> Error:
	profile = ProfileData.new()
	last_report = {}
	return save()


## Message d'état de la sauvegarde à afficher au joueur (vide si tout va bien).
func status_message() -> String:
	match load_state:
		LoadState.RESTORED_FROM_BACKUP:
			return tr("SAVE_RESTORED_BACKUP")
		LoadState.CORRUPTED_RESET:
			return tr("SAVE_CORRUPTED")
		LoadState.NEWER_VERSION:
			return tr("SAVE_NEWER_VERSION")
	return ""


func unlocked_monsters() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		if profile.is_monster_unlocked(GameDB.monsters[id]):
			ids.append(id)
	return ids


func unlocked_difficulties() -> Array[DifficultyData]:
	var list: Array[DifficultyData] = []
	for difficulty: DifficultyData in GameDB.difficulties_by_level():
		if profile.is_difficulty_unlocked(difficulty):
			list.append(difficulty)
	return list


func unlocked_arenas() -> Array[ArenaData]:
	var list: Array[ArenaData] = []
	for id: StringName in GameDB.sorted_ids(GameDB.arenas):
		var arena: ArenaData = GameDB.arenas[id]
		if profile.is_arena_unlocked(arena):
			list.append(arena)
	return list


func make_run_setup(starter_id: StringName, previous: RunSetup = null) -> RunSetup:
	var setup := RunSetup.new()
	var unlocked: Array[StringName] = unlocked_monsters()
	setup.starter_id = starter_id if starter_id != &"" else (team()[0] if not team().is_empty() else &"")
	if not unlocked.has(setup.starter_id) and not unlocked.is_empty():
		setup.starter_id = unlocked[0]
	setup.arena_id = previous.arena_id if previous else StringName(profile.preference("arena", "three_rifts"))
	if previous:
		setup.modifier_ids = previous.modifier_ids.duplicate()
	setup.difficulty_id = previous.difficulty_id if previous else StringName(profile.preference("difficulty", "normal"))
	var arena: ArenaData = GameDB.arena(setup.arena_id)
	if arena == null or not profile.is_arena_unlocked(arena):
		setup.arena_id = unlocked_arenas()[0].id
	var difficulty: DifficultyData = GameDB.difficulty(setup.difficulty_id)
	if difficulty == null or not profile.is_difficulty_unlocked(difficulty):
		setup.difficulty_id = Campaign.NORMAL
	setup.unlocked_monsters = unlocked
	var level: int = GameDB.difficulty(setup.difficulty_id).level
	if previous == null:
		for raw: String in profile.preference("modifiers", "").split(",", false):
			var modifier: RunModifierData = GameDB.modifier(StringName(raw))
			if modifier and level >= modifier.min_difficulty:
				setup.modifier_ids.append(modifier.id)
	for id: StringName in GameDB.sorted_ids(GameDB.relics):
		if profile.is_relic_unlocked(GameDB.relics[id]):
			setup.unlocked_relics.append(id)
	for id: StringName in GameDB.sorted_ids(GameDB.upgrades):
		if profile.is_upgrade_unlocked(GameDB.upgrades[id]):
			setup.unlocked_upgrades.append(id)
	for info: Variant in profile.data["unlocks"].get("info", []):
		setup.info_unlocks.append(str(info))
	setup.show_tutorial = not bool(profile.data["flags"].get("tutorial_done", false))
	setup.meta_effects = HunterTree.effects_for(profile)
	# Boutique : consommables emportés (une unité consommée par départ) et objets de survie acquis.
	var shop: Dictionary = Shop.prepare_run(profile, GameDB.arena(setup.arena_id))
	setup.meta_effects.append_array(shop["effects"])
	setup.start_levels = int(shop["start_levels"])
	setup.shop_items.assign(shop["items"])
	var loadout: Dictionary = HunterTree.loadout(profile)
	setup.spell_ids = loadout["spells"]
	setup.spell_variants = loadout["variants"]
	for id: StringName in unlocked:
		var monster: MonsterData = GameDB.monster(id)
		var effects: Array[GameplayEffect] = Mastery.effects_for(profile, monster)
		effects.append_array(EchoTree.effects_for(profile, monster.id))
		setup.monster_meta_effects[id] = effects
		var technique: TechniqueData = EchoTree.chosen_technique(profile, monster.id)
		if technique:
			setup.echo_techniques[id] = technique
		var entry: Dictionary = profile.mastery_entry(id)
		var palette: Array = Mastery.palette(profile, monster)
		if bool(entry.get("use_palette", false)) and palette.size() == 2:
			setup.palettes[id] = palette
	var starter: MonsterData = GameDB.monster(setup.starter_id)
	if starter:
		setup.starter_rank = Mastery.start_rank(profile, starter)
		setup.starter_variant = _uses_variant(starter)
	for id: StringName in team():
		if id == setup.starter_id or setup.companion_ids.size() + 1 >= GameDB.balance.max_team_slots:
			continue
		setup.companion_ids.append(id)
		setup.companion_ranks[id] = Mastery.start_rank(profile, GameDB.monster(id))
		setup.companion_variants[id] = _uses_variant(GameDB.monster(id))
	return setup


func _uses_variant(monster: MonsterData) -> bool:
	return Mastery.variant_unlocked(profile, monster) and bool(profile.mastery_entry(monster.id).get("use_variant", false))


## Équipe choisie au refuge (préférence « team »), Échos débloqués seulement, l'Écho de tête en premier.
func team() -> Array[StringName]:
	var unlocked: Array[StringName] = unlocked_monsters()
	var ids: Array[StringName] = []
	for raw: String in str(profile.preference("team", profile.preference("starter", ""))).split(",", false):
		var id := StringName(raw)
		if unlocked.has(id) and not ids.has(id) and ids.size() < GameDB.balance.max_team_slots:
			ids.append(id)
	if ids.is_empty() and not unlocked.is_empty():
		ids.append(unlocked[0])
	return ids


func set_team(ids: Array[StringName]) -> void:
	var parts: PackedStringArray = []
	for id: StringName in ids:
		parts.append(String(id))
	profile.set_preference("team", ",".join(parts))
	if not ids.is_empty():
		profile.set_preference("starter", String(ids[0]))


func apply_run_result(result: Dictionary) -> Dictionary:
	last_report = MetaProgression.apply_run_result(profile, result)
	save()
	return last_report
