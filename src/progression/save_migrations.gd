class_name SaveMigrations
extends RefCounted
## Migrations de format de sauvegarde. Chaque étape transforme la version N en N+1 (fonction pure).
## Règle : ne jamais supprimer une donnée inconnue, seulement la déplacer ou la renommer.

const CURRENT_VERSION := 1


## Retourne {data, from, to, error}. error non vide si la migration est impossible.
static func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("format_version", data.get("version", 0)))
	var result := {"data": data, "from": version, "to": version, "error": ""}
	if version > CURRENT_VERSION:
		result["error"] = "newer_version"
		return result
	var current: Dictionary = data.duplicate(true)
	while version < CURRENT_VERSION:
		match version:
			0:
				current = _v0_to_v1(current)
			_:
				result["error"] = "no_migration_from_%d" % version
				return result
		version += 1
	result["data"] = current
	result["to"] = version
	return result


## v0 (format du prototype interne, à plat) → v1 (sections).
static func _v0_to_v1(old: Dictionary) -> Dictionary:
	var data: Dictionary = ProfileData.default_data()
	var currencies: Dictionary = data["currencies"]
	currencies["shards"] = int(old.get("shards", 0))
	currencies["essence"] = int(old.get("essence", 0))
	var unlocks: Dictionary = data["unlocks"]
	unlocks["monsters"] = Array(old.get("unlocked_monsters", []))
	data["tree"] = old.get("skills", {})
	# Les clés inconnues sont conservées dans une section dédiée plutôt que perdues.
	var legacy: Dictionary = {}
	for key: String in old:
		if not ["version", "shards", "essence", "unlocked_monsters", "skills"].has(key):
			legacy[key] = old[key]
	if not legacy.is_empty():
		data["legacy_v0"] = legacy
	data["format_version"] = 1
	return data
