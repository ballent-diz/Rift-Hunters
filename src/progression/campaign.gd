class_name Campaign
extends RefCounted
## Campagne (docs/design/CAMPAGNE.md) : chapitres de cartes dans l'ordre, déblocage en avançant, objectifs de carte
## Normal et Cauchemar, récompenses dégressives, Cauchemar débloqué en finissant la campagne.
## Fonctions pures sur ProfileData ; état sauvegardé dans profile.data["campaign"] :
## {"maps": {arène: {"normal": {"wins", "objectives"}, "nightmare": {...}, "best_pact"}}, "nightmare_unlocked"}.

const NORMAL := &"normal"
const NIGHTMARE := &"nightmare"
## Pistes (ChapterData.track) : campagne principale et épreuves de survie.
const MAIN := &"main"
const SURVIVAL := &"survival"


# --- Structure

static func maps_in_order(track: StringName = MAIN) -> Array[CampaignMapData]:
	var maps: Array[CampaignMapData] = []
	for chapter: ChapterData in chapters_of(track):
		maps.append_array(chapter.maps)
	return maps


static func chapters_of(track: StringName) -> Array[ChapterData]:
	var list: Array[ChapterData] = []
	for chapter: ChapterData in GameDB.chapters_in_order():
		if chapter.track == track:
			list.append(chapter)
	return list


## Piste de la carte (MAIN si elle n'est dans aucun chapitre).
static func track_of(arena_id: StringName) -> StringName:
	var chapter: ChapterData = chapter_of(arena_id)
	return chapter.track if chapter else MAIN


static func map_data(arena_id: StringName) -> CampaignMapData:
	for chapter: ChapterData in GameDB.chapters_in_order():
		for map: CampaignMapData in chapter.maps:
			if map.arena_id == arena_id:
				return map
	return null


static func chapter_of(arena_id: StringName) -> ChapterData:
	for chapter: ChapterData in GameDB.chapters_in_order():
		for map: CampaignMapData in chapter.maps:
			if map.arena_id == arena_id:
				return chapter
	return null


static func is_campaign_map(arena_id: StringName) -> bool:
	return map_data(arena_id) != null


## Dernière carte du dernier chapitre de la campagne principale : la gagner, c'est finir le jeu.
static func final_map() -> CampaignMapData:
	var maps: Array[CampaignMapData] = maps_in_order()
	return maps.back() if not maps.is_empty() else null


static func mode_of(difficulty_id: StringName) -> StringName:
	return NIGHTMARE if difficulty_id == NIGHTMARE else NORMAL


static func objectives_of(map: CampaignMapData, mode: StringName) -> Array[MapObjectiveData]:
	var list: Array[MapObjectiveData] = []
	list.assign(map.nightmare_objectives if mode == NIGHTMARE else map.objectives)
	return list


# --- État sauvegardé

static func _map_entry(profile: ProfileData, arena_id: StringName) -> Dictionary:
	var maps: Dictionary = profile.data["campaign"]["maps"]
	var key: String = String(arena_id)
	if not (maps.get(key) is Dictionary):
		maps[key] = {}
	var entry: Dictionary = maps[key]
	for mode: String in [String(NORMAL), String(NIGHTMARE)]:
		if not (entry.get(mode) is Dictionary):
			entry[mode] = {"wins": 0, "objectives": []}
	if not entry.has("best_pact"):
		entry["best_pact"] = 0
	return entry


static func _mode_entry(profile: ProfileData, arena_id: StringName, mode: StringName) -> Dictionary:
	return _map_entry(profile, arena_id)[String(mode)]


static func wins(profile: ProfileData, arena_id: StringName, mode: StringName = NORMAL) -> int:
	return int(_mode_entry(profile, arena_id, mode).get("wins", 0))


static func objective_done(profile: ProfileData, arena_id: StringName, mode: StringName, objective_id: StringName) -> bool:
	return (_mode_entry(profile, arena_id, mode).get("objectives", []) as Array).has(String(objective_id))


## Nombre d'objectifs de carte obtenus (toutes cartes et difficultés) : ils comptent pour les Points de Chasseur.
static func objectives_completed(profile: ProfileData) -> int:
	var count: int = 0
	for map: CampaignMapData in maps_in_order():
		for mode: StringName in [NORMAL, NIGHTMARE]:
			for objective: MapObjectiveData in objectives_of(map, mode):
				if objective_done(profile, map.arena_id, mode, objective.id):
					count += 1
	return count


static func best_pact(profile: ProfileData, arena_id: StringName) -> int:
	return int(_map_entry(profile, arena_id).get("best_pact", 0))


# --- Déblocages

## Hors campagne : réglage de l'arène. En campagne : la première carte, puis chaque carte dont la précédente a été
## gagnée (en Normal). Une arène déjà débloquée dans une ancienne sauvegarde le reste.
static func is_map_unlocked(profile: ProfileData, arena: ArenaData) -> bool:
	if profile.has_unlock("arenas", arena.id):
		return true
	var maps: Array[CampaignMapData] = maps_in_order(track_of(arena.id))
	for i: int in maps.size():
		if maps[i].arena_id == arena.id:
			return i == 0 or wins(profile, maps[i - 1].arena_id) > 0
	return arena.unlocked_by_default


static func is_nightmare_unlocked(profile: ProfileData) -> bool:
	if bool(profile.data["campaign"].get("nightmare_unlocked", false)):
		return true
	var last: CampaignMapData = final_map()
	return last != null and wins(profile, last.arena_id) > 0


# --- Fin de partie

## Multiplicateur des récompenses d'une partie : dégressif avec les victoires déjà obtenues sur la carte dans cette
## difficulté, sauf en Cauchemar quand le score de Pacte dépasse le meilleur de la carte. Hors campagne : 1.
static func reward_mult(profile: ProfileData, arena_id: StringName, mode: StringName, pact_score: int) -> float:
	if not is_campaign_map(arena_id):
		return 1.0
	if mode == NIGHTMARE and pact_score > best_pact(profile, arena_id):
		return 1.0
	var balance: BalanceConfig = GameDB.balance
	return maxf(balance.map_repeat_floor, pow(balance.map_repeat_decay, wins(profile, arena_id, mode)))


static func is_objective_met(objective: MapObjectiveData, result: Dictionary) -> bool:
	if not result.get("victory", false):
		return false
	var counters: Dictionary = result.get("stats", {}).get("counters", {})
	var value: float = float(counters.get(String(objective.stat_key), 0.0))
	if objective.compare == MapObjectiveData.Compare.AT_MOST:
		return value <= objective.threshold
	return value >= objective.threshold


static func objective_text(objective: MapObjectiveData) -> String:
	var text: String = TranslationServer.translate(objective.desc_key)
	if not text.contains("%"):
		return text
	if objective.duration:
		return text % ("%d:%02d" % [int(objective.threshold) / 60, int(objective.threshold) % 60])
	return text % int(objective.threshold)


## Victoire sur une carte de campagne : compte la victoire, prime de première victoire, objectifs, cartes et
## chapitres débloqués, Cauchemar. Retourne {shards, lines} ; les Éclats sont déjà crédités au profil.
static func apply_result(profile: ProfileData, result: Dictionary) -> Dictionary:
	var arena_id := StringName(str(result.get("arena", "")))
	var map: CampaignMapData = map_data(arena_id)
	if map == null or not result.get("victory", false):
		return {"shards": 0, "lines": PackedStringArray()}
	var mode: StringName = mode_of(StringName(str(result.get("difficulty", ""))))
	var unlocked_before: Array[StringName] = _unlocked_maps(profile)
	var nightmare_before: bool = is_nightmare_unlocked(profile)
	var entry: Dictionary = _mode_entry(profile, arena_id, mode)
	var lines: PackedStringArray = []
	var shards: int = 0
	entry["wins"] = int(entry.get("wins", 0)) + 1
	if int(entry["wins"]) == 1:
		shards += map.nightmare_first_victory_shards if mode == NIGHTMARE else map.first_victory_shards
		lines.append(TranslationServer.translate("REPORT_MAP_FIRST_VICTORY") % shards)
	for objective: MapObjectiveData in objectives_of(map, mode):
		if objective_done(profile, arena_id, mode, objective.id) or not is_objective_met(objective, result):
			continue
		(entry["objectives"] as Array).append(String(objective.id))
		shards += objective.reward_shards
		lines.append(TranslationServer.translate("REPORT_MAP_OBJECTIVE") % [objective_text(objective), objective.reward_shards])
	if mode == NIGHTMARE:
		# Score de Pacte provisoire : nombre de pactes choisis (le lot D3 donnera des points par malus).
		var map_entry: Dictionary = _map_entry(profile, arena_id)
		map_entry["best_pact"] = maxi(int(map_entry["best_pact"]), (result.get("modifiers", []) as Array).size())
	lines.append_array(_unlock_lines(profile, unlocked_before))
	if not nightmare_before and is_nightmare_unlocked(profile):
		profile.data["campaign"]["nightmare_unlocked"] = true
		lines.append(TranslationServer.translate("REPORT_NIGHTMARE_UNLOCKED"))
	profile.add_currency("shards", shards)
	return {"shards": shards, "lines": lines}


static func _unlocked_maps(profile: ProfileData) -> Array[StringName]:
	var ids: Array[StringName] = []
	for map: CampaignMapData in maps_in_order(MAIN) + maps_in_order(SURVIVAL):
		var arena: ArenaData = GameDB.arena(map.arena_id)
		if arena and is_map_unlocked(profile, arena):
			ids.append(map.arena_id)
	return ids


static func _unlock_lines(profile: ProfileData, before: Array[StringName]) -> PackedStringArray:
	var lines: PackedStringArray = []
	for id: StringName in _unlocked_maps(profile):
		if before.has(id):
			continue
		var chapter: ChapterData = chapter_of(id)
		if chapter and chapter.maps[0].arena_id == id:
			lines.append(TranslationServer.translate("REPORT_CHAPTER_UNLOCKED") % TranslationServer.translate(chapter.name_key))
		lines.append(TranslationServer.translate("REPORT_MAP_UNLOCKED") % TranslationServer.translate(GameDB.arena(id).name_key))
	return lines


## Mode test du propriétaire : toutes les cartes (campagne et hors campagne) et le Cauchemar.
static func unlock_all_for_testing(profile: ProfileData) -> void:
	for id: StringName in GameDB.arenas:
		profile.unlock("arena:" + String(id))
	profile.data["campaign"]["nightmare_unlocked"] = true
