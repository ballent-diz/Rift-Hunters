class_name EchoCollection
extends RefCounted
## Collection d'Échos étalée sur trois chapitres (docs/design/COLLECTION_ECHOS.md) : chaque Écho a une source de découverte
## (MonsterData.discovery) — départ, capture garantie sur une carte, victoire sur une carte, étoiles d'un chapitre,
## boutique. Fonctions pures sur ProfileData et RunContext.

const START := &"start"
const CAPTURE := &"capture"
const VICTORY := &"victory"
const STARS := &"stars"
const SHOP := &"shop"


static func owned_count(profile: ProfileData) -> int:
	var count: int = 0
	for id: StringName in GameDB.monsters:
		count += 1 if profile.is_monster_unlocked(GameDB.monsters[id]) else 0
	return count


## Écho à découvrir pendant cette partie (capture garantie à la mort d'une élite), ou &"" s'il n'y en a pas.
static func capture_target(ctx: RunContext) -> StringName:
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		var monster: MonsterData = GameDB.monsters[id]
		if monster.discovery != CAPTURE or monster.discovery_arena != ctx.arena.id:
			continue
		if UpgradeOffers.is_monster_unlocked(ctx, monster) or ctx.build.captures.has(id) or ctx.has_monster(id):
			continue
		return id
	return &""


## Fin de partie : Échos gagnés par une victoire ou par les étoiles d'un chapitre. Retourne les lignes de rapport.
static func apply_result(profile: ProfileData, result: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var arena_id := StringName(str(result.get("arena", "")))
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		var monster: MonsterData = GameDB.monsters[id]
		if profile.is_monster_unlocked(monster):
			continue
		var earned: bool = false
		match monster.discovery:
			VICTORY:
				earned = result.get("victory", false) and monster.discovery_arena == arena_id
			STARS:
				earned = chapter_stars_complete(profile, monster.discovery_chapter)
		if earned:
			profile.unlock("monster:" + String(id))
			profile.discover("monsters", String(id))
			lines.append(TranslationServer.translate("REPORT_ECHO_EARNED") % TranslationServer.translate(monster.name_key))
	return lines


## Tous les objectifs Normal des cartes du chapitre obtenus (faux si le chapitre n'existe pas encore).
static func chapter_stars_complete(profile: ProfileData, chapter_id: StringName) -> bool:
	var chapter: ChapterData = GameDB.chapters.get(chapter_id)
	if chapter == null:
		return false
	for map: CampaignMapData in chapter.maps:
		for objective: MapObjectiveData in map.objectives:
			if not Campaign.objective_done(profile, map.arena_id, Campaign.NORMAL, objective.id):
				return false
	return true


## Boutique : l'Écho est en vente une fois la carte discovery_arena gagnée (ou dès le départ sans carte).
static func is_for_sale(profile: ProfileData, monster: MonsterData) -> bool:
	if monster.discovery != SHOP or profile.is_monster_unlocked(monster):
		return false
	return monster.discovery_arena == &"" or Campaign.wins(profile, monster.discovery_arena) > 0


## Où trouver cet Écho (refuge, bestiaire). « À venir » si sa carte ou son chapitre n'existe pas encore.
static func source_text(monster: MonsterData) -> String:
	var place: String = _place_name(monster)
	match monster.discovery:
		START:
			return TranslationServer.translate("ECHO_SOURCE_START")
		CAPTURE:
			return TranslationServer.translate("ECHO_SOURCE_CAPTURE") % place
		VICTORY:
			return TranslationServer.translate("ECHO_SOURCE_VICTORY") % place
		STARS:
			return TranslationServer.translate("ECHO_SOURCE_STARS") % place
		SHOP:
			return TranslationServer.translate("ECHO_SOURCE_SHOP") % [monster.shop_price, place]
	return TranslationServer.translate("EXPEDITION_LOCKED")


static func _place_name(monster: MonsterData) -> String:
	if monster.discovery == STARS:
		var chapter: ChapterData = GameDB.chapters.get(monster.discovery_chapter)
		return TranslationServer.translate(chapter.name_key) if chapter else TranslationServer.translate("ECHO_SOURCE_LATER")
	if monster.discovery_arena == &"":
		return ""
	var arena: ArenaData = GameDB.arena(monster.discovery_arena)
	return TranslationServer.translate(arena.name_key) if arena else TranslationServer.translate("ECHO_SOURCE_LATER")
