class_name UpgradeOffer
extends RefCounted
## Une carte proposée au passage de niveau.

enum Kind { STAT, MUTATION, RECRUIT, EMPOWER, EVOLVE, HEAL, SHARDS, RELIC }

var kind: Kind = Kind.STAT
## Clé stable (bannissement, tests) : « up:<id> », « recruit:<id> », « empower:<id> », « evolve:<id> »,
## « relic:<id> » (jalons de campagne).
var key: String = ""
var upgrade: UpgradeData
var monster_id: StringName = &""
var evolution: EvolutionData
var relic: RelicData
var weight: float = 1.0


func title() -> String:
	match kind:
		Kind.STAT, Kind.MUTATION:
			return tr(upgrade.name_key)
		Kind.RECRUIT:
			return tr("OFFER_RECRUIT_TITLE") % tr(GameDB.monster(monster_id).name_key)
		Kind.EMPOWER:
			return tr("OFFER_EMPOWER_TITLE") % tr(GameDB.monster(monster_id).name_key)
		Kind.EVOLVE:
			return tr(evolution.name_key)
		Kind.HEAL:
			return tr("OFFER_HEAL_TITLE")
		Kind.RELIC:
			return tr(relic.name_key)
	return tr("OFFER_SHARDS_TITLE")


func description() -> String:
	match kind:
		Kind.STAT, Kind.MUTATION:
			return tr(upgrade.desc_key)
		Kind.RECRUIT:
			return tr(GameDB.monster(monster_id).desc_key)
		Kind.EMPOWER:
			return tr("OFFER_EMPOWER_DESC")
		Kind.EVOLVE:
			return tr(evolution.desc_key)
		Kind.HEAL:
			return tr("OFFER_HEAL_DESC")
		Kind.RELIC:
			return tr(relic.desc_key)
	return tr("OFFER_SHARDS_DESC")


func category() -> String:
	match kind:
		Kind.MUTATION:
			return tr("OFFER_TAG_MUTATION")
		Kind.RECRUIT:
			return tr("OFFER_TAG_PACT")
		Kind.EMPOWER:
			return tr("OFFER_TAG_EMPOWER")
		Kind.EVOLVE:
			return tr("OFFER_TAG_SECRET_EVOLUTION") if evolution.secret else tr("OFFER_TAG_EVOLUTION")
		Kind.RELIC:
			return tr("RELIC_RARITY_%d" % relic.rarity)
	return tr("OFFER_TAG_UPGRADE")


func color() -> Color:
	match kind:
		Kind.STAT:
			return upgrade.color
		Kind.MUTATION:
			return Color(0.85, 0.45, 1.0)
		Kind.RECRUIT:
			return GameDB.monster(monster_id).visual.primary.lightened(0.2)
		Kind.EMPOWER:
			return Color(1.0, 0.85, 0.4)
		Kind.EVOLVE:
			return Color(1.0, 0.95, 0.6)
		Kind.RELIC:
			return relic.color
	return Color(0.6, 0.9, 0.6)
