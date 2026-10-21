class_name SaveMigrations
extends RefCounted
## Migrations de format de sauvegarde. Chaque étape transforme la version N en N+1 (fonction pure).
## Règle : ne jamais supprimer une donnée inconnue, seulement la déplacer ou la renommer.

const CURRENT_VERSION := 4


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
			1:
				current = _v1_to_v2(current)
			2:
				current = _v2_to_v3(current)
			3:
				current = _v3_to_v4(current)
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


## v1 → v2 : arbre du Chasseur v2 (docs/design/ARBRE_DU_CHASSEUR.md). Les rangs appris sont conservés (les nœuds
## repris gardent leur identifiant ; Exploration et Recherche deviennent des améliorations du refuge, toujours
## actives). La liste de builds vide est complétée au premier accès (HunterTree.builds) : le premier build active
## alors les passifs déjà appris, dans la limite des points.
static func _v1_to_v2(old: Dictionary) -> Dictionary:
	var data: Dictionary = old.duplicate(true)
	if not (data.get("hunter") is Dictionary):
		data["hunter"] = {"active_build": 0, "builds": [], "maps_won": []}
	data["format_version"] = 2
	return data


## v3 → v4 : collection d'Échos étalée sur trois chapitres (docs/design/COLLECTION_ECHOS.md). Mousseroc, offert au départ
## jusqu'ici, reste acquis aux joueurs existants ; les autres Échos déjà débloqués le restent aussi.
static func _v3_to_v4(old: Dictionary) -> Dictionary:
	var data: Dictionary = old.duplicate(true)
	var unlocks: Dictionary = data.get("unlocks") if data.get("unlocks") is Dictionary else {}
	var monsters: Array = unlocks.get("monsters") if unlocks.get("monsters") is Array else []
	if not monsters.has("mossback"):
		monsters.append("mossback")
	unlocks["monsters"] = monsters
	data["unlocks"] = unlocks
	return data


## v2 → v3 : campagne en chapitres et fin de la Tension (docs/design/CAMPAGNE.md). Les cartes déjà gagnées comptent
## une victoire en Normal ; elles et la dernière arène choisie restent débloquées. La préférence de Tension devient
## Normal ; les anciens déblocages de Tension et le record « highest_tension_won » sont conservés tels quels.
static func _v2_to_v3(old: Dictionary) -> Dictionary:
	var data: Dictionary = old.duplicate(true)
	var campaign: Dictionary = data.get("campaign") if data.get("campaign") is Dictionary else {}
	if not (campaign.get("maps") is Dictionary):
		campaign["maps"] = {}
	if not campaign.has("nightmare_unlocked"):
		campaign["nightmare_unlocked"] = false
	data["campaign"] = campaign
	var hunter: Dictionary = data.get("hunter") if data.get("hunter") is Dictionary else {}
	var won: Array = hunter.get("maps_won") if hunter.get("maps_won") is Array else []
	var unlocks: Dictionary = data.get("unlocks") if data.get("unlocks") is Dictionary else {}
	var arenas: Array = unlocks.get("arenas") if unlocks.get("arenas") is Array else []
	var preferences: Dictionary = data.get("preferences") if data.get("preferences") is Dictionary else {}
	for raw: Variant in won:
		var id: String = str(raw)
		campaign["maps"][id] = {"normal": {"wins": 1, "objectives": []}, "nightmare": {"wins": 0, "objectives": []},
			"best_pact": 0}
		if not arenas.has(id):
			arenas.append(id)
	var last_arena: String = str(preferences.get("arena", ""))
	if last_arena != "" and not arenas.has(last_arena):
		arenas.append(last_arena)
	unlocks["arenas"] = arenas
	data["unlocks"] = unlocks
	if str(preferences.get("difficulty", "")).begins_with("tension_"):
		preferences["difficulty"] = "normal"
	data["preferences"] = preferences
	data["format_version"] = 3
	return data
