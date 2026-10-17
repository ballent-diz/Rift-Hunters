class_name ProfileData
extends RefCounted
## Progression persistante du joueur (dictionnaire JSON + accès typés). Format : SaveMigrations.CURRENT_VERSION.

var data: Dictionary


func _init(p_data: Dictionary = {}) -> void:
	data = sanitize(p_data) if not p_data.is_empty() else default_data()


static func default_data() -> Dictionary:
	return {
		"format_version": SaveMigrations.CURRENT_VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		"saved_at": 0,
		"currencies": {"shards": 0, "essence": 0},
		"tree": {},
		"tree_resets": 0,
		"unlocks": {"monsters": [], "relics": [], "upgrades": [], "difficulties": [], "arenas": [], "titles": [], "info": []},
		"research": [],
		"discovered": {"monsters": [], "evolutions": [], "enemies": [], "relics": [], "synergies": []},
		"mastery": {},
		"objectives": {"completed": [], "best": {}},
		"lifetime": {},
		"records": {"best_time": 0.0, "best_level": 0, "best_kills": 0, "highest_tension_won": -1},
		"runs": {"played": 0, "won": 0},
		"preferences": {"starter": "mossback", "arena": "three_rifts", "difficulty": "normal"},
		"flags": {},
		# Arbre du Chasseur v2 : builds enregistrés et cartes gagnées (Points de Chasseur).
		"hunter": {"active_build": 0, "builds": [HunterTree.default_build(), HunterTree.default_build(),
			HunterTree.default_build()], "maps_won": []},
		# Campagne (Campaign) : victoires et objectifs par carte et par difficulté, Cauchemar débloqué.
		"campaign": {"maps": {}, "nightmare_unlocked": false},
	}


## Complète les sections manquantes et corrige les types sans perdre les clés inconnues.
static func sanitize(raw: Dictionary) -> Dictionary:
	var result: Dictionary = raw.duplicate(true)
	var defaults: Dictionary = default_data()
	for key: String in defaults:
		if not result.has(key) or not _same_kind(result[key], defaults[key]):
			result[key] = defaults[key]
		elif defaults[key] is Dictionary:
			for sub: String in defaults[key]:
				if not (result[key] as Dictionary).has(sub) or not _same_kind(result[key][sub], defaults[key][sub]):
					result[key][sub] = defaults[key][sub]
	return result


## JSON relit les entiers comme des flottants : les deux types numériques sont compatibles.
static func _same_kind(value: Variant, reference: Variant) -> bool:
	var numeric: Array[int] = [TYPE_INT, TYPE_FLOAT]
	if numeric.has(typeof(value)) and numeric.has(typeof(reference)):
		return true
	return typeof(value) == typeof(reference)


## Message d'erreur si la structure est inexploitable (fichier corrompu), vide sinon.
static func validate(raw: Dictionary) -> String:
	if not raw.has("format_version") and not raw.has("version"):
		return "format_version absent"
	for section: String in ["currencies", "unlocks", "mastery"]:
		if raw.has(section) and not (raw[section] is Dictionary):
			return "section %s invalide" % section
	return ""


# --- Monnaies
func shards() -> int:
	return int(data["currencies"]["shards"])


func essence() -> int:
	return int(data["currencies"]["essence"])


func add_currency(kind: String, amount: int) -> void:
	data["currencies"][kind] = maxi(int(data["currencies"].get(kind, 0)) + amount, 0)


func can_afford(kind: String, amount: int) -> bool:
	return int(data["currencies"].get(kind, 0)) >= amount


# --- Déblocages (« type:id »)
func has_unlock(kind: String, id: StringName) -> bool:
	return (data["unlocks"].get(kind, []) as Array).has(String(id))


func unlock(entry: String) -> bool:
	var kind: String = entry.get_slice(":", 0)
	var id: String = entry.get_slice(":", 1)
	var key: String = kind + "s" if kind in ["monster", "relic", "upgrade", "difficulty", "arena", "title"] else kind
	if kind == "difficulty":
		key = "difficulties"
	if not data["unlocks"].has(key):
		data["unlocks"][key] = []
	var list: Array = data["unlocks"][key]
	if list.has(id):
		return false
	list.append(id)
	return true


func is_monster_unlocked(monster: MonsterData) -> bool:
	return monster.unlocked_by_default or has_unlock("monsters", monster.id)


func is_relic_unlocked(relic: RelicData) -> bool:
	return relic.unlocked_by_default or has_unlock("relics", relic.id)


func is_upgrade_unlocked(upgrade: UpgradeData) -> bool:
	return upgrade.unlocked_by_default or has_unlock("upgrades", upgrade.id)


## Le Cauchemar (niveau 1 et plus) s'obtient en finissant la campagne.
func is_difficulty_unlocked(difficulty: DifficultyData) -> bool:
	if difficulty.unlocked_by_default or has_unlock("difficulties", difficulty.id):
		return true
	return difficulty.level >= 1 and Campaign.is_nightmare_unlocked(self)


func is_arena_unlocked(arena: ArenaData) -> bool:
	return Campaign.is_map_unlocked(self, arena)


# --- Découvertes
func discover(kind: String, id: String) -> bool:
	var list: Array = data["discovered"].get(kind, [])
	if list.has(id):
		return false
	list.append(id)
	data["discovered"][kind] = list
	return true


func is_discovered(kind: String, id: StringName) -> bool:
	return (data["discovered"].get(kind, []) as Array).has(String(id))


# --- Arbre
func tree_rank(node_id: StringName) -> int:
	return int(data["tree"].get(String(node_id), 0))


func set_tree_rank(node_id: StringName, rank: int) -> void:
	if rank <= 0:
		data["tree"].erase(String(node_id))
	else:
		data["tree"][String(node_id)] = rank


# --- Maîtrise
func mastery_entry(monster_id: StringName) -> Dictionary:
	var key: String = String(monster_id)
	if not data["mastery"].has(key):
		data["mastery"][key] = {"xp": 0, "challenges": [], "use_variant": false, "use_palette": false}
	return data["mastery"][key]


# --- Statistiques
func lifetime(key: String) -> float:
	return float(data["lifetime"].get(key, 0.0))


func preference(key: String, fallback: String) -> String:
	return str(data["preferences"].get(key, fallback))


func set_preference(key: String, value: String) -> void:
	data["preferences"][key] = value
