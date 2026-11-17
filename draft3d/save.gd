class_name DraftSave
extends RefCounted
## Profil de la version 3D (docs/design/SAUVEGARDE_V2.md) : un seul fichier, user://draft3d_profile.json, séparé du
## profil v1 (user://profile.json, jamais écrit ici). Reprend la base v1 (SafeJsonStore) : écriture atomique
## (temporaire, relecture, renommage), copie de secours .bak, fichier corrompu mis en quarantaine puis restauré depuis
## la copie, version future lue sans jamais être écrasée. Les anciens fichiers v2 (draft3d_unlocks.json et
## draft3d_progress.json) sont repris automatiquement et laissés en place.
## Contenu : Fragments de faille, sorts et mutations débloqués, 2 sorts de départ, dernier gain, chapitres atteints et
## vaincus, statistiques, réglages propres à la v2 (les réglages généraux restent dans Settings).
## Les façades `DraftUnlocks` (déblocages) et `DraftProgress` (chapitres) lisent et écrivent ce profil.

enum LoadState { NEW, OK, MIGRATED, RESTORED_FROM_BACKUP, CORRUPTED_RESET, NEWER_VERSION, DISABLED }

const PATH := "user://draft3d_profile.json"
const LEGACY_UNLOCKS := "user://draft3d_unlocks.json"
const LEGACY_PROGRESS := "user://draft3d_progress.json"
const FORMAT := 1
const STAT_KEYS: Array[String] = ["runs", "victories", "defeats", "kills", "best_kills", "guardians", "devourers",
	"fragments_earned", "best_level"]
const STAT_FLOAT_KEYS: Array[String] = ["play_seconds", "best_seconds"]

## Chemin du profil ; vide : rien n'est lu ni écrit (essais automatiques, bot, partie headless).
static var path: String = PATH
## Anciens fichiers repris à la première lecture (remplaçables par les essais).
static var legacy_unlocks_path: String = LEGACY_UNLOCKS
static var legacy_progress_path: String = LEGACY_PROGRESS
## Partie d'essai (raccourci de test du boss, options de débogage) : le profil se lit mais n'est jamais écrit.
static var read_only: bool = false
static var load_state: LoadState = LoadState.NEW
static var _data: Dictionary = {}
static var _loaded: bool = false


static func default_data() -> Dictionary:
	var stats: Dictionary = {}
	for key: String in STAT_KEYS:
		stats[key] = 0
	for key: String in STAT_FLOAT_KEYS:
		stats[key] = 0.0
	stats["combos"] = {}
	return {"version": FORMAT, "fragments": 0, "unlocked": [], "starting": [], "last_gain": -1,
		"chapters": {"reached": [], "cleared": []}, "stats": stats, "settings": {}}


## Profil en mémoire (lu une fois). Les façades modifient ce dictionnaire puis appellent `save`.
static func data() -> Dictionary:
	if not _loaded:
		_load()
	return _data


## Oublie l'état en mémoire : le profil est relu au prochain accès (essais, changement de chemin).
static func reset() -> void:
	_loaded = false
	_data = {}
	load_state = LoadState.NEW


static func can_write() -> bool:
	return path != "" and not read_only and load_state != LoadState.NEWER_VERSION


static func store() -> SafeJsonStore:
	return SafeJsonStore.new(path)


## Écrit le profil (atomique + copie de secours) ; ne fait rien en essai, en lecture seule ou sur une version future.
static func save() -> Error:
	if not can_write():
		return OK
	return store().save_data(data())


## « Réinitialiser la progression » : l'ancien profil est gardé à côté (.reset-<date>), puis tout repart de zéro.
## Les anciens fichiers v2 ne sont pas repris une seconde fois.
static func wipe() -> void:
	if can_write() and FileAccess.file_exists(path):
		var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
		DirAccess.copy_absolute(path, "%s.reset-%s" % [path, stamp])
	_data = default_data()
	_loaded = true
	if load_state != LoadState.NEWER_VERSION:
		load_state = LoadState.NEW
	save()


## Chapitre atteint (ouvert au joueur) ; vrai s'il ne l'était pas encore. Sans écriture : l'appelant enregistre.
static func mark_reached(order: int) -> bool:
	var reached: Array = data()["chapters"]["reached"]
	if order < 1 or reached.has(order):
		return false
	reached.append(order)
	reached.sort()
	return true


## Début de partie : bot et headless sans sauvegarde (`path` vide) ; parties d'essai (boss avancé, invincibilité,
## sorts ou chapitre imposés) en lecture seule, jamais récompensées.
static func begin_run(options: Dictionary, automated: bool) -> void:
	if automated:
		path = ""
	read_only = options.has("boss-at") or options.has("god") or options.has("spells") or options.has("chapter")


## Fin de partie : chapitre vaincu et statistiques ; faux en lecture seule (rien n'est enregistré ni gagné).
static func record_end(victory: bool, chapter: int, kills: int, seconds: float, level: int, guardians: int,
		devourers: int, combos: Dictionary = {}) -> bool:
	if read_only:
		return false
	if victory:
		DraftProgress.record_victory(chapter)
	record_stats(victory, kills, seconds, level, guardians, devourers)
	var total: Dictionary = data()["stats"]["combos"]
	for combo: Variant in combos:
		total[str(combo)] = int(total.get(str(combo), 0)) + maxi(int(combos[combo]), 0)
	return true


static func stat(key: String) -> float:
	return float((data()["stats"] as Dictionary).get(key, 0))


## Statistiques d'une partie terminée (défaite comme victoire).
static func record_stats(victory: bool, kills: int, seconds: float, level: int, guardians: int, devourers: int) -> void:
	var stats: Dictionary = data()["stats"]
	stats["runs"] = int(stats["runs"]) + 1
	stats["victories" if victory else "defeats"] = int(stats["victories" if victory else "defeats"]) + 1
	stats["kills"] = int(stats["kills"]) + maxi(kills, 0)
	stats["best_kills"] = maxi(int(stats["best_kills"]), kills)
	stats["guardians"] = int(stats["guardians"]) + maxi(guardians, 0)
	stats["devourers"] = int(stats["devourers"]) + maxi(devourers, 0)
	stats["best_level"] = maxi(int(stats["best_level"]), level)
	stats["play_seconds"] = float(stats["play_seconds"]) + maxf(seconds, 0.0)
	stats["best_seconds"] = maxf(float(stats["best_seconds"]), seconds)


static func setting(key: String, fallback: Variant = null) -> Variant:
	return (data()["settings"] as Dictionary).get(key, fallback)


static func set_setting(key: String, value: Variant) -> void:
	(data()["settings"] as Dictionary)[key] = value
	save()


## Fichier → profil : {data, error}. Fonction pure ; les clés inconnues sont conservées.
static func migrate(raw: Dictionary) -> Dictionary:
	var version: int = int(raw.get("version", 0))
	if version > FORMAT:
		return {"data": sanitize(raw), "error": "newer_version"}
	# Format 0 : contenu d'un ancien draft3d_unlocks.json (même champs, sans chapitres ni statistiques).
	var result: Dictionary = sanitize(raw)
	result["version"] = FORMAT
	return {"data": result, "error": ""}


## Complète et corrige les types (les nombres JSON arrivent en flottants) ; garde tout le reste tel quel.
static func sanitize(raw: Dictionary) -> Dictionary:
	var result: Dictionary = raw.duplicate(true)
	result["version"] = _int(raw.get("version"), 0)
	result["fragments"] = maxi(_int(raw.get("fragments"), 0), 0)
	result["last_gain"] = _int(raw.get("last_gain"), -1)
	result["unlocked"] = _strings(raw.get("unlocked"))
	result["starting"] = _strings(raw.get("starting"))
	var chapters: Dictionary = _section(raw, "chapters")
	for key: String in ["reached", "cleared"]:
		chapters[key] = _orders(chapters.get(key))
	result["chapters"] = chapters
	var stats: Dictionary = _section(raw, "stats")
	for key: String in STAT_KEYS:
		stats[key] = maxi(_int(stats.get(key), 0), 0)
	for key: String in STAT_FLOAT_KEYS:
		stats[key] = maxf(float(stats.get(key)) if _is_number(stats.get(key)) else 0.0, 0.0)
	stats["combos"] = _section(stats, "combos")
	result["stats"] = stats
	result["settings"] = _section(raw, "settings")
	return result


## Contrôle avant usage (fichier principal puis copie de secours) : texte vide si valide.
static func validate(raw: Dictionary) -> String:
	if not (raw.get("version") is int or raw.get("version") is float):
		return "version manquante"
	if raw.has("unlocked") and not raw["unlocked"] is Array:
		return "déblocages illisibles"
	if raw.has("chapters") and not raw["chapters"] is Dictionary:
		return "chapitres illisibles"
	if raw.has("stats") and not raw["stats"] is Dictionary:
		return "statistiques illisibles"
	return ""


static func _load() -> void:
	_loaded = true
	_data = default_data()
	if path == "":
		load_state = LoadState.DISABLED
		return
	var file: SafeJsonStore = store()
	var raw: Dictionary = file.load_data(validate)
	match file.last_status:
		SafeJsonStore.LoadStatus.MISSING:
			load_state = LoadState.NEW
			_import_legacy()
			return
		SafeJsonStore.LoadStatus.CORRUPTED_NO_BACKUP:
			push_warning("Profil v2 illisible, copie gardée dans %s : nouveau profil" % file.quarantined_path)
			load_state = LoadState.CORRUPTED_RESET
			return
		SafeJsonStore.LoadStatus.RESTORED_FROM_BACKUP:
			load_state = LoadState.RESTORED_FROM_BACKUP
		_:
			load_state = LoadState.OK
	var migration: Dictionary = migrate(raw)
	_data = migration["data"]
	if migration["error"] == "newer_version":
		push_warning("Profil v2 d'une version plus récente : lu sans être écrasé")
		load_state = LoadState.NEWER_VERSION
		return
	if int(raw.get("version", 0)) < FORMAT and load_state == LoadState.OK:
		load_state = LoadState.MIGRATED
	if load_state != LoadState.OK:
		save()


## Première lecture sans profil : reprise de draft3d_unlocks.json et draft3d_progress.json (laissés en place).
static func _import_legacy() -> void:
	var found: bool = false
	var unlocks: Variant = _read_json(legacy_unlocks_path)
	if unlocks is Dictionary:
		var migrated: Dictionary = migrate(unlocks)
		if migrated["error"] == "":
			_data = migrated["data"]
			found = true
	var progress: Variant = _read_json(legacy_progress_path)
	if progress is Dictionary and (progress as Dictionary).get("cleared") is Array:
		var cleared: Array = _data["chapters"]["cleared"]
		cleared.append_array(_orders((progress as Dictionary)["cleared"]))
		_data = sanitize(_data)
		found = true
	if found:
		for order: int in _data["chapters"]["cleared"]:
			mark_reached(order)
			mark_reached(order + 1)
		load_state = LoadState.MIGRATED
		save()


static func _read_json(file_path: String) -> Variant:
	if file_path == "" or not FileAccess.file_exists(file_path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(file_path))


static func _section(raw: Dictionary, key: String) -> Dictionary:
	return (raw[key] as Dictionary).duplicate(true) if raw.get(key) is Dictionary else {}


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _int(value: Variant, fallback: int) -> int:
	return int(value) if _is_number(value) else fallback


static func _orders(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item: Variant in value:
			if _is_number(item) and int(item) >= 1 and not result.has(int(item)):
				result.append(int(item))
	result.sort()
	return result


static func _strings(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item: Variant in value:
			if (item is String or item is StringName) and not result.has(str(item)):
				result.append(str(item))
	return result
