class_name DraftRoster
extends RefCounted
## Bestiaire d'un chapitre pour la base 3D, lu dans les données de la campagne (data/chapters, data/arenas) :
## monstres dans l'ordre où la campagne les présente, gardiens des cartes et Dévoreur de fin de chapitre.
## Rien n'est copié : ajouter un monstre à une carte de la campagne l'ajoute ici.

## Monstres communs gardés par chapitre (le chapitre 5 rappelle ceux des précédents : on garde les siens).
const MAX_ENEMIES := 10
## Boss écartés de la base 3D (décision du propriétaire, 13 novembre 2026).
const EXCLUDED_BOSSES: Array[StringName] = [&"nebulorax"]

var chapter: ChapterData
var enemies: Array[EnemyData] = []
var guardians: Array[BossData] = []
var boss: BossData


static func chapters() -> Array[ChapterData]:
	var result: Array[ChapterData] = []
	for data: ChapterData in GameDB.chapters_in_order():
		if data.track == &"main":
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
			if usable(data) and not roster.enemies.has(data) and roster.enemies.size() < MAX_ENEMIES:
				roster.enemies.append(data)
		var guardian: BossData = GameDB.boss(arena.boss_id)
		if guardian != null and not roster.guardians.has(guardian) and not EXCLUDED_BOSSES.has(guardian.id):
			roster.guardians.append(guardian)
	if not roster.guardians.is_empty():
		roster.boss = roster.guardians.pop_back()
	return roster


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
