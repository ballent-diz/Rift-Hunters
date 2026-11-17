class_name DraftSave
extends RefCounted
## Profil de sauvegarde de la v2 (user://draft3d_save.json), distinct du profil de la v1 (jamais lu ni écrit ici).
## Écriture sûre de la v1 (`SafeJsonStore` : fichier temporaire vérifié puis renommé, copie .bak, fichier corrompu mis
## en quarantaine puis repli sur la copie). Sections :
## - `unlocks` : Fragments de faille, sorts et mutations débloqués, 2 sorts de départ, dernier gain (DraftUnlocks) ;
## - `chapters` : chapitres vaincus (DraftProgress) ;
## - `stats` : parties, victoires, éliminations, meilleur temps et niveau, Fragments gagnés, combos déclenchés ;
## - `settings` : réglages propres à la v2 (les réglages généraux restent dans Settings).
## Les anciens fichiers séparés (user://draft3d_unlocks.json, user://draft3d_progress.json) sont repris une fois puis
## renommés en .migrated (jamais supprimés). Un profil d'une version future est lu mais jamais réécrit.
## Les essais automatiques, le bot et les parties de test (options de lancement) n'écrivent rien : `path` vide.

signal changed

const PATH := "user://draft3d_save.json"
const FORMAT := 1
const LEGACY_UNLOCKS := "user://draft3d_unlocks.json"
const LEGACY_PROGRESS := "user://draft3d_progress.json"

## Chemin du profil ; vide : rien n'est lu ni écrit.
static var path: String = PATH
static var _instance: DraftSave

var data: Dictionary = {}
## Profil d'une version future : gardé intact sur le disque.
var read_only: bool = false
## État du dernier chargement (SafeJsonStore.LoadStatus) et anciens fichiers repris.
var status: SafeJsonStore.LoadStatus = SafeJsonStore.LoadStatus.MISSING
var migrated: Array[String] = []


## Profil partagé (chargé une fois) : menu, écran des déblocages et partie lisent le même objet.
static func load() -> DraftSave:
	if _instance == null:
		_instance = DraftSave.new()
		_instance._read()
	return _instance


## Oublie le profil en mémoire (essais, réinitialisation) : il est relu au prochain `load`.
static func reset() -> void:
	_instance = null
	DraftUnlocks.reset()


static func default_data() -> Dictionary:
	return {"format_version": FORMAT,
		"unlocks": {"fragments": 0, "unlocked": [], "starting": [], "last_gain": -1},
		"chapters": {"cleared": []},
		"stats": {"runs": 0, "victories": 0, "kills": 0, "best_time": 0.0, "best_level": 0, "fragments_earned": 0,
			"combos": {}},
		"settings": {}}


func section(name: String) -> Dictionary:
	if not data.get(name) is Dictionary:
		data[name] = (default_data()[name] as Dictionary).duplicate(true)
	return data[name]


## Enregistre le profil ; faux sans chemin, en lecture seule ou si l'écriture échoue.
func save() -> bool:
	changed.emit()
	if path == "" or read_only:
		return false
	return SafeJsonStore.new(path).save_data(data) == OK


## Fin de partie : statistiques cumulées.
func record_run(victory: bool, seconds: float, level: int, kills: int, combos: Dictionary) -> void:
	var stats: Dictionary = section("stats")
	stats["runs"] = int(stats.get("runs", 0)) + 1
	stats["victories"] = int(stats.get("victories", 0)) + (1 if victory else 0)
	stats["kills"] = int(stats.get("kills", 0)) + kills
	stats["best_time"] = maxf(float(stats.get("best_time", 0.0)), seconds)
	stats["best_level"] = maxi(int(stats.get("best_level", 0)), level)
	if not stats.get("combos") is Dictionary:
		stats["combos"] = {}
	var total: Dictionary = stats["combos"]
	for combo: Variant in combos:
		total[str(combo)] = int(total.get(str(combo), 0)) + int(combos[combo])
	save()


## Réinitialiser la progression : profil vierge (l'ancien reste dans la copie .bak).
func erase() -> bool:
	data = default_data()
	read_only = false
	var done: bool = save()
	DraftUnlocks.reset()
	return done


func _read() -> void:
	data = default_data()
	if path == "":
		return
	var store := SafeJsonStore.new(path)
	var loaded: Dictionary = store.load_data(_validate)
	status = store.last_status
	if loaded.is_empty():
		if status == SafeJsonStore.LoadStatus.MISSING:
			_migrate_legacy()
		return
	if int(loaded.get("format_version", 0)) > FORMAT:
		read_only = true
		push_warning("Profil v2 d'une version future (%s) : lu sans être réécrit." % path)
	for key: Variant in loaded:
		data[key] = loaded[key]


static func _validate(candidate: Dictionary) -> String:
	if not candidate.has("format_version"):
		return "format_version manquant"
	for name: String in ["unlocks", "chapters", "stats"]:
		if candidate.has(name) and not candidate[name] is Dictionary:
			return "section %s invalide" % name
	return ""


## Reprise des fichiers séparés d'avant ce profil (déblocages, chapitres vaincus).
func _migrate_legacy() -> void:
	var unlocks: Dictionary = _legacy(LEGACY_UNLOCKS)
	if not unlocks.is_empty():
		var target: Dictionary = section("unlocks")
		for key: String in ["fragments", "unlocked", "starting", "last_gain"]:
			if unlocks.has(key):
				target[key] = unlocks[key]
	var progress: Dictionary = _legacy(LEGACY_PROGRESS)
	if progress.has("cleared"):
		section("chapters")["cleared"] = progress["cleared"]
	if migrated.is_empty() or not save():
		return
	for legacy: String in migrated:
		DirAccess.rename_absolute(legacy, legacy + ".migrated")


func _legacy(file: String) -> Dictionary:
	var legacy: String = path.get_base_dir().path_join(file.get_file())
	if not FileAccess.file_exists(legacy):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(legacy))
	if not parsed is Dictionary:
		push_warning("Ancien fichier illisible, laissé en place : " + legacy)
		return {}
	migrated.append(legacy)
	return parsed
