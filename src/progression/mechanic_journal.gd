class_name MechanicJournal
extends RefCounted
## Journal des mécaniques (docs/ROADMAP.md, lot 1 des menus) : chaque mécanique de carte, de Corrompu ou de boss
## rencontrée en partie y est notée une fois (profile.data["journal"]). La première rencontre affiche une fiche dans
## le HUD ; le refuge permet de les relire. Le texte de chaque fiche est l'annonce de la mécanique (clé *_INTRO).

const MAPS := &"maps"
const ENEMIES := &"enemies"
const BOSSES := &"bosses"
## Annonce de la mécanique → [titre, famille], dans l'ordre d'affichage du Journal.
const ENTRIES := {
	"NIGHT_INTRO": ["JOURNAL_NIGHT", MAPS],
	"NIGHT_EMBERS_INTRO": ["JOURNAL_NIGHT_EMBERS", MAPS],
	"NIGHT_BRAZIERS_INTRO": ["JOURNAL_NIGHT_BRAZIERS", MAPS],
	"BLIZZARD_INTRO": ["JOURNAL_BLIZZARD", MAPS],
	"FLOOD_INTRO": ["JOURNAL_FLOOD", MAPS],
	"POD_INTRO": ["JOURNAL_POD", MAPS],
	"NEST_INTRO": ["JOURNAL_NEST", MAPS],
	"LAVA_INTRO": ["JOURNAL_LAVA", MAPS],
	"MUD_INTRO": ["JOURNAL_MUD", MAPS],
	"TIDE_INTRO": ["JOURNAL_TIDE", MAPS],
	"FLOE_INTRO": ["JOURNAL_FLOE", MAPS],
	"SPELL_ECHO_INTRO": ["JOURNAL_SPELL_ECHO", MAPS],
	"CRYSTAL_INTRO": ["JOURNAL_CRYSTAL", MAPS],
	"PORTAL_INTRO": ["JOURNAL_PORTAL", MAPS],
	"COLD_INTRO": ["JOURNAL_COLD", MAPS],
	"ICE_INTRO": ["JOURNAL_ICE", MAPS],
	"ICE_PRISON_INTRO": ["JOURNAL_ICE_PRISON", ENEMIES],
	"HUSH_INTRO": ["JOURNAL_HUSH", ENEMIES],
	"SOUL_LINK_INTRO": ["JOURNAL_SOUL_LINK", ENEMIES],
	"BOSS_ORB_INTRO": ["JOURNAL_ORB", BOSSES],
	"BOSS_VEIL_INTRO": ["JOURNAL_MIST_VEIL", BOSSES],
	"BOSS_CROWN_INTRO": ["JOURNAL_CROWN", BOSSES],
	"BOSS_RAM_INTRO": ["JOURNAL_RAM", BOSSES],
	"BOSS_DUEL_INTRO": ["JOURNAL_DUEL", BOSSES],
	"BOSS_THREADS_INTRO": ["JOURNAL_THREADS", BOSSES],
	"BOSS_SHELL_INTRO": ["JOURNAL_SHELL", BOSSES],
	"BOSS_CRATER_INTRO": ["JOURNAL_CRATER", BOSSES],
	"BOSS_GUARD_INTRO": ["JOURNAL_GUARD", BOSSES],
	"BOSS_DIVE_INTRO": ["JOURNAL_DIVE", BOSSES],
	"BOSS_SPORE_VEIL_INTRO": ["JOURNAL_SPORE_VEIL", BOSSES],
	"BOSS_PORTAL_INTRO": ["JOURNAL_PORTAL_LADY", BOSSES],
	"BOSS_MUD_WALL_INTRO": ["JOURNAL_MUD_WALL", BOSSES],
	"BOSS_LEASH_INTRO": ["JOURNAL_LEASH", BOSSES],
	"BOSS_LEECH_INTRO": ["JOURNAL_LEECH", BOSSES],
	"BOSS_FACETS_INTRO": ["JOURNAL_FACETS", BOSSES],
	"BOSS_MIRROR_INTRO": ["JOURNAL_MIRROR", BOSSES],
	"BOSS_WHIRLPOOL_INTRO": ["JOURNAL_WHIRLPOOL", BOSSES],
	"BOSS_TIDE_RING_INTRO": ["JOURNAL_TIDE_RING", BOSSES],
	"BOSS_SWALLOW_INTRO": ["JOURNAL_SWALLOW", BOSSES],
	"BOSS_CAPTURE_INTRO": ["JOURNAL_CAPTURE", BOSSES],
	"BOSS_AVALANCHE_INTRO": ["JOURNAL_AVALANCHE", BOSSES],
	"BOSS_DEEP_FREEZE_INTRO": ["JOURNAL_DEEP_FREEZE", BOSSES],
	"BOSS_STORM_HUNT_INTRO": ["JOURNAL_STORM_HUNT", BOSSES],
	"BOSS_FLOE_QUAKE_INTRO": ["JOURNAL_FLOE_QUAKE", BOSSES],
	"BOSS_SHATTER_INTRO": ["JOURNAL_SHATTER", BOSSES],
}
const GROUPS: Array[StringName] = [MAPS, ENEMIES, BOSSES]


static func is_mechanic(key: String) -> bool:
	return ENTRIES.has(key)


static func title_key(key: String) -> String:
	return str(ENTRIES[key][0])


## Explication de la fiche : l'annonce, sans son préfixe quand il répète le titre (« Miroirs : … »).
static func body(key: String) -> String:
	var text: String = TranslationServer.translate(key)
	var title: String = TranslationServer.translate(title_key(key))
	for separator: String in [" : ", ": "]:
		var cut: int = text.find(separator)
		if cut > 0 and text.substr(0, cut).to_lower() == title.to_lower():
			var rest: String = text.substr(cut + separator.length())
			return rest.substr(0, 1).to_upper() + rest.substr(1)
	return text


static func group_of(key: String) -> StringName:
	return ENTRIES[key][1]


static func seen(profile: ProfileData) -> Array:
	return profile.data.get_or_add("journal", [])


static func has_seen(profile: ProfileData, key: String) -> bool:
	return seen(profile).has(key)


## Note la mécanique ; vrai si c'est sa première rencontre.
static func record(profile: ProfileData, key: String) -> bool:
	if not is_mechanic(key) or has_seen(profile, key):
		return false
	seen(profile).append(key)
	return true


static func keys_of(group: StringName) -> Array[String]:
	var keys: Array[String] = []
	for key: String in ENTRIES:
		if ENTRIES[key][1] == group:
			keys.append(key)
	return keys
