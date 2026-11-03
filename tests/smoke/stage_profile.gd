class_name StageProfile
extends RefCounted
## Profil d'équilibrage « joueur moyen-bon arrivé à cette carte » (docs/design/DIFFICULTE.md) : la progression de la
## campagne est rejouée avec les vraies règles (Éclats, Points de Chasseur, emplacements de sorts, sceau d'Écho,
## maîtrise et arbres des Échos), carte gagnée après carte gagnée, puis dépensée comme le ferait un tel joueur.
## Le bot reçoit ainsi ce qu'un vrai joueur aurait débloqué : rien de plus, rien de moins.

## Hypothèses (à ajuster ici seulement) : tentatives par carte gagnée, objectifs de carte réussis (« terminer » à
## chaque victoire, plus un autre une carte sur deux), part des Éclats laissée à la boutique, part réservée aux Échos.
const ATTEMPTS_PER_MAP := 1.6
const SHOP_SHARE := 0.2
const ECHO_SHARE := 0.3
## Éclats d'une tentative (hors premières victoires et objectifs) : mesurés en partie, ils montent avec la carte.
const RUN_SHARDS_BASE := 90
const RUN_SHARDS_PER_MAP := 10
## XP de maîtrise d'un Écho par partie jouée dans l'équipe (jeu + défis faciles).
const MASTERY_XP_PER_RUN := 25
## Arbre du Chasseur d'un joueur moyen-bon : [nœud, rang] dans l'ordre d'achat. Les sorts sont équipés dès que leur
## emplacement s'ouvre ; l'activation suit le même ordre, tant que les Points de Chasseur suffisent.
const HUNTER_PLAN := [
	["combat_training", 1], ["trunk_vigor", 1], ["blade_slash_whirlwind", 1], ["prism_lance_fan", 1],
	["blade_rift_leap", 1], ["combat_training", 2], ["trunk_vigor", 2], ["echoes_veteran", 1], ["echoes_third_seal", 1],
	["combat_phantom_step", 1], ["echoes_bonds", 1], ["echoes_bonds", 2], ["prism_rupture", 1], ["blade_leap_impact", 1],
	["combat_training", 3], ["trunk_vigor", 3], ["prism_rupture_blaze", 1], ["echoes_bonds", 3], ["blade_honed_edge", 1],
	["blade_honed_edge", 2], ["combat_last_breath", 1], ["blade_honed_edge", 3], ["blade_parry", 1],
]


## Profil du joueur qui arrive sur `arena_id` (carte de la campagne principale). `starter` mène l'équipe.
static func build(arena_id: StringName, starter: StringName) -> ProfileData:
	var profile := ProfileData.new()
	var echo_wallet: int = 0
	var hunter_wallet: int = 0
	var team: Array[StringName] = [starter]
	var found: Array[StringName] = []
	var index: int = 0
	for map: CampaignMapData in Campaign.maps_in_order():
		if map.arena_id == arena_id:
			break
		index += 1
		# Les tentatives de la carte : maîtrise des Échos de l'équipe, Éclats de partie.
		var earned: int = int(ATTEMPTS_PER_MAP * (RUN_SHARDS_BASE + RUN_SHARDS_PER_MAP * index))
		for id: StringName in team:
			var entry: Dictionary = profile.mastery_entry(id)
			entry["xp"] = int(entry["xp"]) + int(ATTEMPTS_PER_MAP * MASTERY_XP_PER_RUN)
		# La victoire : carte gagnée, objectifs, Écho découvert.
		Campaign._mode_entry(profile, map.arena_id, Campaign.NORMAL)["wins"] = 1
		HunterTree.record_victory(profile, String(map.arena_id))
		profile.data["runs"]["won"] = int(profile.data["runs"].get("won", 0)) + 1
		earned += map.first_victory_shards
		var objectives: Array = Campaign._mode_entry(profile, map.arena_id, Campaign.NORMAL).get_or_add("objectives", [])
		var targets: Array[MapObjectiveData] = Campaign.objectives_of(map, Campaign.NORMAL)
		for i: int in targets.size():
			if i == 0 or (i == 1 and index % 2 == 1):
				objectives.append(String(targets[i].id))
				earned += targets[i].reward_shards
		for id: StringName in GameDB.sorted_ids(GameDB.monsters):
			if GameDB.monsters[id].discovery_arena == map.arena_id:
				profile.unlock("monster:%s" % id)
				found.append(id)
		team = _team(profile, starter, found)
		earned = int(earned * (1.0 - SHOP_SHARE))
		echo_wallet += int(earned * ECHO_SHARE)
		hunter_wallet += earned - int(earned * ECHO_SHARE)
		hunter_wallet = _spend_hunter(profile, hunter_wallet)
		echo_wallet = _spend_echoes(profile, team, echo_wallet)
	team = _team(profile, starter, found)
	_activate_hunter(profile)
	for id: StringName in team:
		_activate_echo(profile, id)
	var ids: PackedStringArray = []
	for id: StringName in team:
		ids.append(String(id))
	profile.set_preference("team", ",".join(ids))
	profile.data["flags"]["tutorial_done"] = true
	return profile


## Équipe : l'Écho de tête et les plus récemment découverts, dans la limite des emplacements (2, 3 avec le sceau).
static func _team(profile: ProfileData, starter: StringName, found: Array[StringName]) -> Array[StringName]:
	var slots: int = mini(GameDB.balance.base_team_slots + (1 if profile.tree_rank(&"echoes_third_seal") > 0 else 0),
		GameDB.balance.max_team_slots)
	var result: Array[StringName] = [starter]
	for i: int in range(found.size() - 1, -1, -1):
		if result.size() < slots and not result.has(found[i]):
			result.append(found[i])
	return result


## Achats de l'arbre du Chasseur dans l'ordre du plan ; on économise pour le prochain nœud plutôt que de sauter.
static func _spend_hunter(profile: ProfileData, wallet: int) -> int:
	for step: Array in HUNTER_PLAN:
		var node: SkillNodeData = GameDB.skill_node(StringName(step[0]))
		if node == null or HunterTree.learned_rank(profile, node) >= int(step[1]):
			continue
		var cost: int = HunterTree.next_cost(profile, node)
		if cost > wallet or HunterTree.boss_wins(profile) < node.required_wins:
			break
		profile.add_currency("shards", cost)
		if not HunterTree.learn(profile, node):
			profile.add_currency("shards", -cost)
			continue
		wallet -= cost
	return wallet


## Arbres des Échos : nœuds dans l'ordre des paliers (sans changer leur sort), tant que maîtrise et Éclats le permettent.
static func _spend_echoes(profile: ProfileData, team: Array[StringName], wallet: int) -> int:
	for id: StringName in team:
		for node: SkillNodeData in EchoTree.nodes_of(id):
			if node.kind == SkillNodeData.Kind.SPELL and not node.learned_by_default:
				continue
			var cost: int = EchoTree.next_cost(profile, node)
			if cost < 0 or cost > wallet:
				continue
			profile.add_currency("shards", cost)
			if EchoTree.learn(profile, node):
				wallet -= cost
			else:
				profile.add_currency("shards", -cost)
	return wallet


## Build actif dans l'ordre du plan, selon les points (un sort activé s'équipe seul sur le premier emplacement ouvert).
static func _activate_hunter(profile: ProfileData) -> void:
	for step: Array in HUNTER_PLAN:
		var node: SkillNodeData = GameDB.skill_node(StringName(step[0]))
		if node == null or node.is_utility():
			continue
		while HunterTree.active_rank(profile, node) < mini(int(step[1]), HunterTree.learned_rank(profile, node)):
			if not HunterTree.activate(profile, node):
				break


static func _activate_echo(profile: ProfileData, id: StringName) -> void:
	for node: SkillNodeData in EchoTree.nodes_of(id):
		if node.kind == SkillNodeData.Kind.SPELL:
			continue
		while EchoTree.active_rank(profile, node) < EchoTree.learned_rank(profile, node):
			if not EchoTree.activate(profile, node):
				break


## Résumé lisible (journal de la simulation).
static func describe(profile: ProfileData) -> String:
	var loadout: Dictionary = HunterTree.loadout(profile)
	var team: String = profile.preference("team", "")
	var levels: PackedStringArray = []
	for raw: String in team.split(",", false):
		levels.append("%s m%d" % [raw, Mastery.level(profile, GameDB.monster(StringName(raw)))])
	return "points %d/%d · sorts %s · variantes %s · sceau %s · équipe %s · arbres d'Échos %s" % [
		HunterTree.points_used(profile), HunterTree.points_total(profile), loadout["spells"], loadout["variants"].keys(),
		"oui" if profile.tree_rank(&"echoes_third_seal") > 0 else "non", ", ".join(levels), _echo_points(profile, team)]


static func _echo_points(profile: ProfileData, team: String) -> String:
	var parts: PackedStringArray = []
	for raw: String in team.split(",", false):
		parts.append("%d/%d" % [EchoTree.points_used(profile, StringName(raw)), EchoTree.points_total(profile, StringName(raw))])
	return " ".join(parts)
