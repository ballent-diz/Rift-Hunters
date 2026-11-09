class_name DefeatAdvice
extends RefCounted
## Conseil après une défaite (lot 2 des menus) : il part de ce qui a le plus blessé le Chasseur (dégâts subis par
## source, mesurés pendant la partie). Un Corrompu : sa fiche, qui dit comment le contrer ; un gardien ou un
## Dévoreur : sa mécanique phare ; un danger de carte : comment l'éviter. S'y ajoute un rappel si des Éclats
## attendent dans l'arbre du Chasseur : la marge de progression vient aussi du build.

## Mécanique phare d'un boss → son explication (annonce de la mécanique).
const SIGNATURE_INTRO := {
	&"source_orb": "BOSS_ORB_INTRO", &"star_crown": "BOSS_CROWN_INTRO", &"mist_veil": "BOSS_VEIL_INTRO",
	&"pyre_ram": "BOSS_RAM_INTRO", &"duel_circle": "BOSS_DUEL_INTRO", &"silk_threads": "BOSS_THREADS_INTRO",
	&"slag_rain": "BOSS_SHELL_INTRO", &"crater_sequence": "BOSS_CRATER_INTRO", &"bark_guard": "BOSS_GUARD_INTRO",
	&"maw_dive": "BOSS_DIVE_INTRO", &"spore_veil": "BOSS_SPORE_VEIL_INTRO", &"prism_beam": "BOSS_MIRROR_INTRO",
	&"portal_hop": "BOSS_PORTAL_INTRO",
	&"spell_capture": "BOSS_CAPTURE_INTRO", &"avalanche": "BOSS_AVALANCHE_INTRO",
	&"deep_freeze": "BOSS_DEEP_FREEZE_INTRO", &"storm_hunt": "BOSS_STORM_HUNT_INTRO",
	&"floe_quake": "BOSS_FLOE_QUAKE_INTRO", &"war_cry": "BOSS_WAR_CRY_INTRO",
	&"rune_barrage": "BOSS_RUNE_BARRAGE_INTRO", &"pantheon_wake": "BOSS_PANTHEON_WAKE_INTRO",
}
## Dangers de carte et sources sans fiche.
const SOURCE_ADVICE := {
	"burn": ["ADVICE_SOURCE_BURN", "ADVICE_BURN"], "cold": ["JOURNAL_COLD", "COLD_INTRO"],
	"crystal_mirror": ["JOURNAL_CRYSTAL", "ADVICE_CRYSTAL"], "ember_pod": ["JOURNAL_POD", "ADVICE_POD"],
	"floe": ["JOURNAL_FLOE", "FLOE_INTRO"],
	"rockfall": ["ADVICE_SOURCE_ROCKFALL", "ADVICE_ROCKFALL"], "boss": ["ADVICE_SOURCE_BOSS", "ADVICE_BOSS"],
}


## Source qui a fait le plus de dégâts au Chasseur ("" : aucune).
static func main_threat(result: Dictionary) -> String:
	var damage: Dictionary = result.get("stats", {}).get("damage_by_source", {})
	var best: String = ""
	var most: float = 0.0
	for source: Variant in damage:
		var key: String = String(source)
		if key.begins_with("taken_") and float(damage[source]) > most:
			most = float(damage[source])
			best = key.trim_prefix("taken_")
	return best


## [nom de la menace, conseil], ou vide si rien de pertinent.
static func advice(result: Dictionary) -> Array[String]:
	var source: String = main_threat(result)
	var lines: Array[String] = []
	if source == "":
		return lines
	var enemy: EnemyData = GameDB.enemy(StringName(source))
	var boss: BossData = GameDB.boss(StringName(source))
	if boss:
		lines.assign([TranslationServer.translate(boss.name_key), MechanicJournal.body(SIGNATURE_INTRO[boss.signature])
			if SIGNATURE_INTRO.has(boss.signature) else TranslationServer.translate("ADVICE_BOSS")])
	elif enemy and enemy.desc_key != "":
		lines.assign([TranslationServer.translate(enemy.name_key), TranslationServer.translate(enemy.desc_key)])
	elif SOURCE_ADVICE.has(source):
		lines.assign([TranslationServer.translate(SOURCE_ADVICE[source][0]),
			TranslationServer.translate(SOURCE_ADVICE[source][1])])
	return lines


## Rappel de progression : des Éclats suffisent pour apprendre un nœud de l'arbre du Chasseur ("" sinon).
static func build_hint(profile: ProfileData) -> String:
	for id: StringName in GameDB.sorted_ids(GameDB.skill_nodes):
		if HunterTree.status(profile, GameDB.skill_nodes[id]) == HunterTree.Status.LEARNABLE:
			return TranslationServer.translate("ADVICE_SPEND") % profile.shards()
	return ""
