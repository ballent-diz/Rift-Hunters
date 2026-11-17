extends TestCase
## Profil v2 (draft3d/save.gd, docs/design/SAUVEGARDE_V2.md) : écriture sûre, copie de secours, fichier corrompu,
## version future, reprise des anciens fichiers v2, lecture seule des parties d'essai, réinitialisation.

const DIR := "user://test_draft3d_save/"

var _saved: Array = []


func before_each() -> void:
	_saved = [DraftSave.path, DraftSave.legacy_unlocks_path, DraftSave.legacy_progress_path, DraftSave.read_only]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_clean()
	DraftSave.path = DIR + "profile.json"
	DraftSave.legacy_unlocks_path = DIR + "unlocks.json"
	DraftSave.legacy_progress_path = DIR + "progress.json"
	DraftSave.read_only = false
	DraftUnlocks.reset()


func after_each() -> void:
	_clean()
	DraftSave.path = _saved[0]
	DraftSave.legacy_unlocks_path = _saved[1]
	DraftSave.legacy_progress_path = _saved[2]
	DraftSave.read_only = _saved[3]
	DraftUnlocks.reset()


func _clean() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for file: String in dir.get_files():
		dir.remove(file)


func _write(file: String, text: String) -> void:
	var handle := FileAccess.open(DIR + file, FileAccess.WRITE)
	handle.store_string(text)
	handle.close()


func _reload() -> DraftUnlocks:
	DraftUnlocks.reset()
	return DraftUnlocks.load()


func test_round_trip_and_backup() -> void:
	var unlocks: DraftUnlocks = DraftUnlocks.load()
	check_eq(DraftSave.load_state, DraftSave.LoadState.NEW, "aucun fichier : profil neuf")
	check(not FileAccess.file_exists(DraftSave.path), "rien n'est écrit sans raison")
	DraftSave.record_stats(true, 120, 300.0, 9, 1, 0)
	DraftProgress.record_start(1)
	DraftProgress.record_victory(1)
	unlocks.record_run(400)
	check(unlocks.unlock(&"rift_leap"), "déblocage enregistré")
	check(unlocks.set_starting_spells([&"rift_leap", &"cleaving_slash"] as Array[StringName]), "départ enregistré")
	check(FileAccess.file_exists(DraftSave.path + ".bak"), "copie de secours après la 2e écriture")
	check(not FileAccess.file_exists(DraftSave.path + ".tmp"), "pas de fichier temporaire restant")
	var cost: int = 400 - unlocks.currency()
	unlocks = _reload()
	check_eq(DraftSave.load_state, DraftSave.LoadState.OK, "relu")
	check_eq(unlocks.currency(), 400 - cost, "Fragments")
	check(unlocks.is_unlocked(&"rift_leap"), "sort débloqué")
	check_eq(unlocks.starting_spells(), [&"rift_leap", &"cleaving_slash"] as Array[StringName], "sorts de départ")
	check_eq(unlocks.last_gain(), 400, "dernier gain")
	check_eq(DraftProgress.cleared(), [1] as Array[int], "chapitre vaincu")
	check_eq(DraftProgress.reached(), [1, 2] as Array[int], "chapitres atteints")
	check_eq(int(DraftSave.stat("runs")), 1, "parties")
	check_eq(int(DraftSave.stat("victories")), 1, "victoires")
	check_eq(int(DraftSave.stat("kills")), 120, "éliminations")
	check_eq(int(DraftSave.stat("fragments_earned")), 400, "Fragments gagnés au total")
	check_near(DraftSave.stat("best_seconds"), 300.0, 0.01, "meilleur temps")
	DraftSave.set_setting("aim_hint", true)
	DraftSave.reset()
	check_eq(DraftSave.setting("aim_hint", false), true, "réglage propre à la v2")


func test_combo_totals_keep_existing_profile_and_ignore_test_runs() -> void:
	DraftUnlocks.load().record_run(80)
	DraftSave.record_end(false, 1, 10, 20.0, 2, 0, 0, {&"rift_counter": 2})
	DraftSave.record_end(true, 1, 20, 30.0, 3, 0, 0, {&"rift_counter": 1, &"still_storm": 4})
	DraftSave.save()
	DraftSave.reset()
	check_eq(int(DraftSave.data()["fragments"]), 80, "profil existant conservé")
	check_eq(int(DraftSave.data()["stats"]["combos"]["rift_counter"]), 3, "combos cumulés et relus")
	check_eq(int(DraftSave.data()["stats"]["combos"]["still_storm"]), 4, "autre combo conservé")
	DraftSave.read_only = true
	check(not DraftSave.record_end(false, 1, 10, 20.0, 2, 0, 0, {&"rift_counter": 10}), "essai ignoré")
	check_eq(int(DraftSave.data()["stats"]["combos"]["rift_counter"]), 3, "essai non comptabilisé")


func test_corrupted_file_restored_from_backup() -> void:
	var unlocks: DraftUnlocks = DraftUnlocks.load()
	unlocks.record_run(50)
	unlocks.record_run(70)
	_write("profile.json", "{ pas du json")
	unlocks = _reload()
	check_eq(DraftSave.load_state, DraftSave.LoadState.RESTORED_FROM_BACKUP, "restauré depuis la copie")
	check_eq(unlocks.currency(), 50, "état de la copie de secours")
	var quarantined: bool = false
	for file: String in DirAccess.get_files_at(DIR):
		quarantined = quarantined or file.begins_with("profile.json.corrupted-")
	check(quarantined, "fichier corrompu conservé à part")
	_write("profile.json", "[]")
	_write("profile.json.bak", "")
	unlocks = _reload()
	check_eq(DraftSave.load_state, DraftSave.LoadState.CORRUPTED_RESET, "sans copie valide : profil neuf")
	check_eq(unlocks.currency(), 0, "rien d'inventé")


func test_newer_version_is_never_overwritten() -> void:
	var text: String = JSON.stringify({"version": DraftSave.FORMAT + 1, "fragments": 999, "unlocked": ["rupture"],
		"future": {"x": 1}})
	_write("profile.json", text)
	var unlocks: DraftUnlocks = DraftUnlocks.load()
	check_eq(DraftSave.load_state, DraftSave.LoadState.NEWER_VERSION, "version future détectée")
	check_eq(unlocks.currency(), 999, "lue au mieux")
	unlocks.record_run(10)
	check_eq(FileAccess.get_file_as_string(DraftSave.path), text, "jamais écrasée")


func test_legacy_files_migrated() -> void:
	_write("unlocks.json", JSON.stringify({"version": 1, "fragments": 230, "last_gain": 42,
		"unlocked": ["cleaving_slash", "prismatic_lance", "rupture", "rupture_blaze"],
		"starting": ["rupture", "prismatic_lance"]}))
	_write("progress.json", JSON.stringify({"version": 1, "cleared": [1, 2]}))
	var unlocks: DraftUnlocks = DraftUnlocks.load()
	check_eq(DraftSave.load_state, DraftSave.LoadState.MIGRATED, "anciens fichiers repris")
	check_eq(unlocks.currency(), 230, "Fragments repris")
	check(unlocks.is_unlocked(&"rupture") and unlocks.is_unlocked(&"rupture_blaze"), "sort et mutation repris")
	check_eq(unlocks.starting_spells(), [&"rupture", &"prismatic_lance"] as Array[StringName], "départ repris")
	check_eq(unlocks.last_gain(), 42, "dernier gain repris")
	check_eq(DraftProgress.cleared(), [1, 2] as Array[int], "chapitres repris")
	check_eq(DraftProgress.reached(), [1, 2, 3] as Array[int], "chapitres atteints déduits")
	check(FileAccess.file_exists(DraftSave.path), "profil v2 écrit")
	check(FileAccess.file_exists(DIR + "unlocks.json") and FileAccess.file_exists(DIR + "progress.json"),
		"anciens fichiers laissés en place")
	_write("unlocks.json", JSON.stringify({"version": 1, "fragments": 5}))
	unlocks = _reload()
	check_eq(DraftSave.load_state, DraftSave.LoadState.OK, "reprise faite une seule fois")
	check_eq(unlocks.currency(), 230, "le profil v2 fait foi")


func test_read_only_and_disabled_never_write() -> void:
	DraftSave.read_only = true
	var unlocks: DraftUnlocks = DraftUnlocks.load()
	unlocks.record_run(100)
	DraftProgress.record_victory(1)
	check(not FileAccess.file_exists(DraftSave.path), "partie d'essai : rien d'écrit")
	DraftSave.read_only = false
	DraftSave.path = ""
	unlocks = _reload()
	unlocks.record_run(100)
	check_eq(DirAccess.get_files_at(DIR).size(), 0, "bot : rien d'écrit")


func test_wipe_keeps_old_profile_aside() -> void:
	var unlocks: DraftUnlocks = DraftUnlocks.load()
	unlocks.record_run(400)
	check(unlocks.unlock(&"rift_leap"), "déblocage")
	DraftProgress.record_victory(1)
	DraftUnlocks.wipe()
	check_eq(unlocks.currency(), 0, "Fragments remis à zéro (même objet)")
	check(not unlocks.is_unlocked(&"rift_leap") and unlocks.is_unlocked(&"rupture"), "seuls les sorts offerts")
	check_eq(DraftProgress.cleared(), [] as Array[int], "chapitres remis à zéro")
	unlocks = _reload()
	check_eq(unlocks.currency(), 0, "réinitialisation enregistrée")
	var kept: bool = false
	for file: String in DirAccess.get_files_at(DIR):
		kept = kept or file.begins_with("profile.json.reset-")
	check(kept, "ancien profil gardé à côté")


func test_sanitize_repairs_types() -> void:
	var data: Dictionary = DraftSave.sanitize({"version": 1.0, "fragments": -5.0, "unlocked": ["a", 3, "a"],
		"chapters": {"cleared": [2.0, "x", 0, 2]}, "stats": "?", "extra": 1})
	check_eq(data["fragments"], 0, "Fragments jamais négatifs")
	check_eq(data["unlocked"], ["a"], "identifiants seulement, sans doublon")
	check_eq(data["chapters"]["cleared"], [2], "chapitres entiers")
	check_eq(data["stats"]["runs"], 0, "statistiques recréées")
	check_eq(data["extra"], 1, "clé inconnue conservée")
	check(DraftSave.validate({"fragments": 1}) != "", "version obligatoire")
