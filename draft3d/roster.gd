class_name DraftRoster
extends RefCounted
## Bestiaire d'un chapitre pour la base 3D, lu dans les données de la campagne (data/chapters, data/arenas) :
## monstres dans l'ordre où la campagne les présente, gardiens des cartes et Dévoreur de fin de chapitre.
## Rien n'est copié : ajouter un monstre à une carte de la campagne l'ajoute ici.

## Monstres communs gardés par chapitre (le chapitre 5 rappelle ceux des précédents : on garde les siens).
const MAX_ENEMIES := 10
## Boss supprimés de la base 3D (décision du propriétaire, 13 novembre 2026, confirmée le 17 novembre : Nébulorax
## définitivement retiré de la v2 ; ses données restent pour l'archive v1).
const EXCLUDED_BOSSES: Array[StringName] = [&"nebulorax"]

## Chapitres propres à la version 3D (6 à 9, après les cinq de la campagne) : pas de données de campagne, leur
## bestiaire mêle des cartes existantes (monstres, gardiens ; la dernière donne le Dévoreur). Les PV du Dévoreur
## croissent avec le rang du chapitre (`DraftTuning.boss_chapter_growth`). Un chapitre doté de sa propre famille
## (placement validé le 20 novembre 2026, docs/design/BOSS_V2.md) la donne en `enemies` (ordre d'apparition : les
## premiers dominent, les élites en dernier) et son Dévoreur en `boss` ; ses gardiens restent ceux des cartes.
const V2_CHAPTERS: Array[Dictionary] = [
	{"id": &"rift_tower", "color": Color(0.82, 0.36, 0.62),
		"arenas": [&"shattered_outskirts", &"rune_sanctum", &"shattered_pantheon", &"soot_dens", &"caldera_arena"],
		"enemies": [&"biting_bobbin", &"patch_mender", &"veil_moth", &"split_puppet", &"war_shuttle",
			&"shroud_spinner", &"tapestry_ram"], "boss": &"loom_devourer"},
	{"id": &"howling_pass", "color": Color(0.9, 0.62, 0.36),
		"arenas": [&"scorched_verge", &"ash_vents", &"glacier_entry", &"brazier_pass", &"silent_heart"]},
	{"id": &"tide_marsh", "color": Color(0.36, 0.74, 0.78),
		"arenas": [&"mist_ford", &"root_mangrove", &"tide_temple", &"reflection_wells", &"marsh_heart"],
		"enemies": [&"salt_scuttler", &"rope_drowned", &"brine_skate", &"salt_siphon", &"floodgate_keeper",
			&"brine_choir", &"salt_dredger"], "boss": &"saumor"},
	{"id": &"high_cliffs", "color": Color(0.66, 0.78, 0.98),
		"arenas": [&"three_rifts", &"storm_highlands", &"firefly_woods", &"cascade_source", &"suspended_quarters"],
		"enemies": [&"hopping_shard", &"faience_pilgrim", &"floating_rosette", &"cracked_pourer", &"glaze_judge",
			&"hollow_potter", &"mosaic_crawler"], "boss": &"fairon"},
]

var chapter: ChapterData
var enemies: Array[EnemyData] = []
var guardians: Array[BossData] = []
var boss: BossData


static func chapters() -> Array[ChapterData]:
	var result: Array[ChapterData] = []
	for data: ChapterData in GameDB.chapters_in_order():
		if data.track == &"main":
			result.append(data)
	for entry: Dictionary in V2_CHAPTERS:
		var data := ChapterData.new()
		data.id = entry["id"]
		data.order = result.size() + 1
		data.color = entry["color"]
		for arena_id: StringName in entry["arenas"]:
			var map := CampaignMapData.new()
			map.arena_id = arena_id
			data.maps.append(map)
		result.append(data)
	return result


## Nom du chapitre dans la version 3D (décor de sa carte), distinct du nom de la campagne 2D (clés gardées pour
## l'archive) : CHAPTER3D_<ID>_NAME / _DESC dans i18n/strings.csv.
static func name_key(data: ChapterData) -> String:
	return "CHAPTER3D_%s_NAME" % String(data.id).to_upper()


static func desc_key(data: ChapterData) -> String:
	return "CHAPTER3D_%s_DESC" % String(data.id).to_upper()


static func for_chapter(order: int) -> DraftRoster:
	var roster := DraftRoster.new()
	var list: Array[ChapterData] = chapters()
	roster.chapter = list[clampi(order, 1, list.size()) - 1]
	var own: Dictionary = v2_entry(roster.chapter.id)
	for id: StringName in own.get("enemies", []):
		var data: EnemyData = GameDB.enemy(id)
		if usable(data):
			roster.enemies.append(data)
	var explicit: bool = not roster.enemies.is_empty()
	for map: CampaignMapData in roster.chapter.maps:
		var arena: ArenaData = GameDB.arena(map.arena_id)
		if arena == null:
			continue
		var ids: Array[StringName] = []
		for phase: WavePhaseData in arena.waves:
			ids.append_array(phase.enemies)
		for zone: LevelZoneData in arena.zones:
			for wave: ZoneWaveData in zone.waves:
				ids.append_array(wave.enemies)
		for id: StringName in ids:
			var data: EnemyData = GameDB.enemy(id)
			if not explicit and usable(data) and not roster.enemies.has(data) and roster.enemies.size() < MAX_ENEMIES:
				roster.enemies.append(data)
		var guardian: BossData = GameDB.boss(arena.boss_id)
		if guardian != null and not roster.guardians.has(guardian) and not EXCLUDED_BOSSES.has(guardian.id):
			roster.guardians.append(guardian)
	if not roster.guardians.is_empty():
		roster.boss = roster.guardians.pop_back()
	if own.has("boss"):
		# Dévoreur propre au chapitre : le dernier gardien des cartes redevient un gardien.
		if roster.boss != null and not roster.guardians.has(roster.boss) and roster.boss.guardian:
			roster.guardians.append(roster.boss)
		roster.boss = GameDB.boss(own["boss"])
	return roster


## Entrée de `V2_CHAPTERS` d'un chapitre propre à la 3D ({} pour un chapitre de la campagne).
static func v2_entry(id: StringName) -> Dictionary:
	for entry: Dictionary in V2_CHAPTERS:
		if entry["id"] == id:
			return entry
	return {}


## Dévoreur propre à la v2 (aucune carte de la campagne 2D ne l'appelle) : ses techniques ne sont jouées qu'en 3D.
static func v2_only_boss(id: StringName) -> bool:
	for entry: Dictionary in V2_CHAPTERS:
		if entry.get("boss", &"") == id:
			return true
	return false


## Monstre jouable dans la base 3D : mobile, avec une feuille de sprites (ni structure, ni nid, ni objet).
static func usable(data: EnemyData) -> bool:
	return data != null and not data.structure and not data.pod and data.brain != EnemyData.Brain.STATIC \
		and data.visual != null and Assets.has_sheet(data.visual.visual_id)


## Mélange d'une vague : `stage` (0 à 1) ouvre peu à peu le bestiaire ; les premiers monstres restent majoritaires.
func mix(stage: float) -> Dictionary:
	var result: Dictionary = {}
	var count: int = clampi(1 + int(stage * enemies.size()), 1, enemies.size())
	for i: int in count:
		result[String(enemies[i].id)] = 3.0 if i == 0 else maxf(1.4 - 0.1 * i, 0.5)
	return result
