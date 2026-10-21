extends TestCase
## Sauvegarde : écriture atomique, copie de secours, corruption, migrations, version plus récente.

const DIR := "user://test_saves"
var path: String


func before_each() -> void:
	path = DIR.path_join("profile_%d.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(DIR)


func after_each() -> void:
	var dir := DirAccess.open(DIR)
	if dir:
		for file: String in dir.get_files():
			dir.remove(file)


func _write_raw(file_path: String, text: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _quarantined_files() -> PackedStringArray:
	var result: PackedStringArray = []
	for file: String in DirAccess.open(DIR).get_files():
		if file.contains(path.get_file() + ".corrupted-"):
			result.append(file)
	return result


func test_save_and_reload() -> void:
	var store := SafeJsonStore.new(path)
	check_eq(store.save_data({"format_version": 1, "value": 42}), OK, "écriture")
	var data: Dictionary = SafeJsonStore.new(path).load_data()
	check_eq(int(data.get("value", 0)), 42, "relecture")
	check(not FileAccess.file_exists(path + ".tmp"), "pas de fichier temporaire résiduel")


func test_second_save_creates_backup() -> void:
	var store := SafeJsonStore.new(path)
	store.save_data({"format_version": 1, "value": 1})
	store.save_data({"format_version": 1, "value": 2})
	var backup: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ".bak"))
	check(backup is Dictionary and int(backup["value"]) == 1, "la copie de secours contient la version précédente")


func test_corrupted_file_restores_backup() -> void:
	var store := SafeJsonStore.new(path)
	store.save_data({"format_version": 1, "value": 1})
	store.save_data({"format_version": 1, "value": 2})
	_write_raw(path, "{ceci n'est pas du JSON")
	var loader := SafeJsonStore.new(path)
	var data: Dictionary = loader.load_data(ProfileData.validate)
	check_eq(loader.last_status, SafeJsonStore.LoadStatus.RESTORED_FROM_BACKUP, "restauration depuis .bak")
	check_eq(int(data.get("value", 0)), 1, "données de la copie de secours")
	check_eq(_quarantined_files().size(), 1, "le fichier corrompu est conservé en quarantaine")


func test_corrupted_without_backup_is_never_deleted() -> void:
	_write_raw(path, "garbage")
	var loader := SafeJsonStore.new(path)
	var data: Dictionary = loader.load_data(ProfileData.validate)
	check(data.is_empty(), "aucune donnée exploitable")
	check_eq(loader.last_status, SafeJsonStore.LoadStatus.CORRUPTED_NO_BACKUP, "corruption signalée")
	check_eq(FileAccess.get_file_as_string(path), "garbage", "le fichier d'origine n'est pas supprimé")
	check_eq(_quarantined_files().size(), 1, "copie en quarantaine")


func test_invalid_structure_is_treated_as_corrupted() -> void:
	_write_raw(path, JSON.stringify({"currencies": "pas un dictionnaire"}))
	var loader := SafeJsonStore.new(path)
	loader.load_data(ProfileData.validate)
	check_eq(loader.last_status, SafeJsonStore.LoadStatus.CORRUPTED_NO_BACKUP, "structure invalide détectée")


func test_missing_file() -> void:
	var loader := SafeJsonStore.new(path)
	check(loader.load_data().is_empty() and loader.last_status == SafeJsonStore.LoadStatus.MISSING, "fichier absent")


func test_migration_v0_to_v1() -> void:
	var old := {"version": 0, "shards": 120, "essence": 4, "unlocked_monsters": ["glimmerwing"], "custom_flag": true}
	var migrated: Dictionary = SaveMigrations.migrate(old)
	check_eq(migrated["error"], "", "migration réussie")
	check_eq(int(migrated["to"]), SaveMigrations.CURRENT_VERSION, "version cible")
	var profile := ProfileData.new(migrated["data"])
	check_eq(profile.shards(), 120, "Éclats conservés")
	check(profile.has_unlock("monsters", &"glimmerwing"), "déblocages conservés")
	check(bool(migrated["data"]["legacy_v0"]["custom_flag"]), "clé inconnue conservée (jamais perdue)")


func test_migration_v2_to_v3_campaign() -> void:
	var old := {"format_version": 2, "currencies": {"shards": 10, "essence": 0},
		"unlocks": {"arenas": [], "difficulties": ["tension_1"]},
		"preferences": {"arena": "storm_highlands", "difficulty": "tension_2"},
		"hunter": {"active_build": 0, "builds": [], "maps_won": ["three_rifts"]}}
	var migrated: Dictionary = SaveMigrations.migrate(old)
	check_eq(migrated["error"], "", "migration réussie")
	check_eq(int(migrated["to"]), SaveMigrations.CURRENT_VERSION, "version actuelle")
	var profile := ProfileData.new(migrated["data"])
	check_eq(Campaign.wins(profile, &"three_rifts"), 1, "carte gagnée comptée en Normal")
	check(profile.is_arena_unlocked(GameDB.arena(&"storm_highlands")), "arène déjà choisie : reste débloquée")
	check_eq(profile.preference("difficulty", ""), "normal", "préférence de Tension remplacée par Normal")
	check(profile.has_unlock("difficulties", &"tension_1"), "anciens déblocages conservés")
	check(not profile.is_difficulty_unlocked(GameDB.difficulty(&"nightmare")) or Campaign.final_map().arena_id == &"three_rifts",
		"le Cauchemar attend la fin de la campagne")


func test_newer_version_is_refused() -> void:
	check_eq(SaveMigrations.migrate({"format_version": 99})["error"], "newer_version", "version future détectée")


func test_sanitize_keeps_unknown_keys() -> void:
	var profile := ProfileData.new({"format_version": 1, "currencies": {"shards": 5}, "future_feature": {"x": 1}})
	check_eq(profile.shards(), 5, "valeur existante conservée")
	check_eq(profile.essence(), 0, "section complétée")
	check(profile.data.has("future_feature"), "clé inconnue conservée")


func test_profile_autoload_roundtrip_and_read_only() -> void:
	var original_path: String = Profile.path
	var original: ProfileData = Profile.profile
	Profile.load_profile(path)
	check_eq(Profile.load_state, Profile.LoadState.NEW_PROFILE, "nouveau profil")
	Profile.profile.add_currency("shards", 777)
	Profile.profile.unlock("monster:glimmerwing")
	check_eq(Profile.save(), OK, "sauvegarde")
	Profile.load_profile(path)
	check_eq(Profile.profile.shards(), 777, "Éclats relus")
	check(Profile.profile.has_unlock("monsters", &"glimmerwing"), "déblocage relu")
	_write_raw(path, JSON.stringify({"format_version": 99, "currencies": {"shards": 1, "essence": 0}}))
	Profile.load_profile(path)
	check(Profile.read_only, "version plus récente : lecture seule")
	check_eq(Profile.save(), ERR_UNAVAILABLE, "aucune écriture en lecture seule")
	check(FileAccess.get_file_as_string(path).contains("99"), "fichier plus récent intact")
	Profile.path = original_path
	Profile.profile = original
	Profile.read_only = false


func test_numbers_survive_json_roundtrip() -> void:
	var profile := ProfileData.new()
	profile.add_currency("shards", 321)
	profile.data["tree_resets"] = 2
	SafeJsonStore.new(path).save_data(profile.data)
	var reloaded := ProfileData.new(SafeJsonStore.new(path).load_data(ProfileData.validate))
	check_eq(reloaded.shards(), 321, "les entiers relus en flottants restent valides")
	check_eq(int(reloaded.data["tree_resets"]), 2, "compteur de réinitialisations conservé")
