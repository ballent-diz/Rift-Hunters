extends TestCase
## Profil de sauvegarde de la v2 (draft3d/save.gd) : aller-retour, reprise des anciens fichiers, écriture sûre,
## récupération d'un fichier corrompu, version future, aucune écriture sans chemin, réinitialisation.

const DIR := "user://test_draft3d_save"
const FILE := DIR + "/draft3d_save.json"

var _path: String


func before_each() -> void:
	_path = DraftSave.path
	_clean()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	DraftSave.path = FILE
	DraftSave.reset()


func after_each() -> void:
	_clean()
	DraftSave.path = _path
	DraftSave.reset()


func _clean() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for file: String in dir.get_files():
		dir.remove(file)


func _write_json(file: String, data: Variant) -> void:
	FileAccess.open(file, FileAccess.WRITE).store_string(JSON.stringify(data))


func _json(file: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(file))


func test_round_trip_through_unlocks_progress_and_stats() -> void:
	var unlocks: DraftUnlocks = DraftUnlocks.load()
	unlocks.record_run(200)
	check(unlocks.unlock(&"rupture"), "Rupture débloquée")
	check(unlocks.set_starting_spells([&"rupture", &"cleaving_slash"] as Array[StringName]), "départ choisi")
	DraftProgress.record_victory(1)
	DraftSave.load().record_run(true, 754.0, 12, 340, {&"gravity_blade": 2})
	check(FileAccess.file_exists(FILE), "profil écrit")
	check(not FileAccess.file_exists(FILE + ".tmp"), "aucun fichier temporaire laissé")
	DraftSave.reset()
	var again: DraftUnlocks = DraftUnlocks.load()
	check_eq(again.currency(), 200 - run_cost(), "Fragments relus")
	check(again.is_unlocked(&"rupture"), "déblocage relu")
	check_eq(again.starting_spells(), [&"rupture", &"cleaving_slash"] as Array[StringName], "départ relu")
	check_eq(again.last_gain(), 200, "dernier gain relu")
	check_eq(DraftProgress.cleared(), [1] as Array[int], "chapitre vaincu relu")
	var stats: Dictionary = DraftSave.load().section("stats")
	check_eq(int(stats["runs"]), 1, "parties")
	check_eq(int(stats["victories"]), 1, "victoires")
	check_eq(int(stats["kills"]), 340, "éliminations")
	check_near(float(stats["best_time"]), 754.0, 0.01, "meilleur temps")
	check_eq(int(stats["best_level"]), 12, "meilleur niveau")
	check_eq(int((stats["combos"] as Dictionary)["gravity_blade"]), 2, "combos")
	check(FileAccess.file_exists(FILE + ".bak"), "copie de secours")


func run_cost() -> int:
	return DraftUnlocks.load().tuning.spell_unlock_cost


func test_legacy_files_are_migrated_once() -> void:
	_write_json(DIR + "/draft3d_unlocks.json", {"version": 1, "fragments": 75, "unlocked": ["cleaving_slash",
		"prismatic_lance", "rupture"], "starting": ["rupture", "prismatic_lance"], "last_gain": 30})
	_write_json(DIR + "/draft3d_progress.json", {"version": 1, "cleared": [1, 2]})
	var unlocks: DraftUnlocks = DraftUnlocks.load()
	check_eq(unlocks.currency(), 75, "Fragments repris")
	check(unlocks.is_unlocked(&"rupture"), "déblocages repris")
	check_eq(unlocks.starting_spells(), [&"rupture", &"prismatic_lance"] as Array[StringName], "départ repris")
	check_eq(DraftProgress.cleared(), [1, 2] as Array[int], "chapitres repris")
	check(FileAccess.file_exists(FILE), "nouveau profil écrit")
	check(not FileAccess.file_exists(DIR + "/draft3d_unlocks.json"), "ancien fichier mis de côté")
	check(FileAccess.file_exists(DIR + "/draft3d_unlocks.json.migrated"), "jamais supprimé")
	check(FileAccess.file_exists(DIR + "/draft3d_progress.json.migrated"), "progression mise de côté")
	DraftSave.reset()
	check_eq(DraftUnlocks.load().currency(), 75, "relu depuis le nouveau profil")


func test_corrupted_profile_falls_back_to_backup_or_defaults() -> void:
	DraftUnlocks.load().record_run(40)
	DraftUnlocks.load().record_run(10)
	FileAccess.open(FILE, FileAccess.WRITE).store_string("{ cassé")
	DraftSave.reset()
	var profile: DraftSave = DraftSave.load()
	check_eq(profile.status, SafeJsonStore.LoadStatus.RESTORED_FROM_BACKUP, "copie de secours utilisée")
	check_eq(DraftUnlocks.load().currency(), 40, "état d'avant la dernière écriture")
	var quarantined: bool = false
	for file: String in DirAccess.get_files_at(DIR):
		quarantined = quarantined or file.contains(".corrupted-")
	check(quarantined, "fichier corrompu conservé à part")
	FileAccess.open(FILE, FileAccess.WRITE).store_string("[]")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE + ".bak"))
	DraftSave.reset()
	check_eq(DraftSave.load().status, SafeJsonStore.LoadStatus.CORRUPTED_NO_BACKUP, "sans copie")
	check_eq(DraftUnlocks.load().currency(), 0, "profil vierge, la partie démarre")


func test_future_version_is_never_overwritten() -> void:
	_write_json(FILE, {"format_version": DraftSave.FORMAT + 1, "unlocks": {"fragments": 9}, "future": {"x": 1}})
	var before: String = FileAccess.get_file_as_string(FILE)
	var profile: DraftSave = DraftSave.load()
	check(profile.read_only, "lecture seule")
	check_eq(DraftUnlocks.load().currency(), 9, "données comprises lues")
	DraftUnlocks.load().record_run(5)
	check(not profile.save(), "aucune écriture")
	check_eq(FileAccess.get_file_as_string(FILE), before, "fichier intact")


func test_no_path_writes_nothing_and_erase_resets() -> void:
	DraftSave.path = ""
	DraftSave.reset()
	DraftUnlocks.load().record_run(30)
	DraftProgress.record_victory(1)
	check(not FileAccess.file_exists(FILE), "bot et essais : rien d'écrit")
	DraftSave.path = FILE
	DraftSave.reset()
	DraftUnlocks.load().record_run(30)
	DraftProgress.record_victory(1)
	check(DraftSave.load().erase(), "réinitialisation enregistrée")
	check_eq(DraftUnlocks.load().currency(), 0, "Fragments remis à zéro")
	check(DraftProgress.cleared().is_empty(), "chapitres remis à zéro")
	check_eq(int(_json(FILE + ".bak")["unlocks"]["fragments"]), 30, "ancien profil dans la copie de secours")


func test_reset_button_in_main_menu_options() -> void:
	DraftUnlocks.load().record_run(30)
	var options := DraftOptions.new()
	options.allow_reset = true
	host.add_child(options)
	var button: Button = options.find_child("ResetProgress", true, false)
	check(button != null, "bouton présent au menu principal")
	button.pressed.emit()
	check_eq(DraftUnlocks.load().currency(), 30, "premier appui : confirmation seulement")
	button.pressed.emit()
	check_eq(DraftUnlocks.load().currency(), 0, "second appui : progression effacée")
	options.queue_free()
	var pause := DraftOptions.new()
	host.add_child(pause)
	check(pause.find_child("ResetProgress", true, false) == null, "absent en pause")
	pause.queue_free()
