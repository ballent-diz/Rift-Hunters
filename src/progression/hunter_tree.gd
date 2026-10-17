class_name HunterTree
extends RefCounted
## Règles de l'arbre du Chasseur v2 (docs/design/ARBRE_DU_CHASSEUR.md), fonctions pures sur ProfileData.
## Apprendre un rang coûte des Éclats, une fois pour toutes ; l'activer dans un build coûte des Points de Chasseur.
## Changer de build ou d'activation est gratuit. Les améliorations du refuge (UTILITY) sont actives dès qu'apprises.

enum Status { COMING_SOON, GATED, LOCKED, TOO_EXPENSIVE, LEARNABLE, LEARNED }

const BUILD_COUNT := 3
const SPELL_SLOTS := 4
## Points de départ : de quoi activer les 2 sorts de départ (2 + 2) et un premier passif.
const BASE_POINTS := 6
## +1 point tous les N objectifs réussis (objectifs du jeu et objectifs de carte).
const OBJECTIVES_PER_POINT := 3
const DEFAULT_SPELLS: Array[String] = ["cleaving_slash", "prismatic_lance", "", ""]


# --- Apprendre (Éclats)

static func learned_rank(profile: ProfileData, node: SkillNodeData) -> int:
	var rank: int = profile.tree_rank(node.id)
	return maxi(rank, 1) if node.learned_by_default else rank


static func next_cost(profile: ProfileData, node: SkillNodeData) -> int:
	var rank: int = learned_rank(profile, node)
	return node.costs[rank] if rank < node.max_rank() else -1


static func boss_wins(profile: ProfileData) -> int:
	return int(profile.data["runs"].get("won", 0))


static func prerequisites_met(profile: ProfileData, node: SkillNodeData) -> bool:
	if node.prerequisites.is_empty():
		return true
	var met: int = 0
	for prereq: StringName in node.prerequisites:
		var other: SkillNodeData = GameDB.skill_node(prereq)
		if other and learned_rank(profile, other) > 0:
			met += 1
	return met > 0 if node.prerequisites_any else met == node.prerequisites.size()


static func status(profile: ProfileData, node: SkillNodeData) -> Status:
	if not node.implemented:
		return Status.COMING_SOON
	if learned_rank(profile, node) >= node.max_rank():
		return Status.LEARNED
	if boss_wins(profile) < node.required_wins:
		return Status.GATED
	if not prerequisites_met(profile, node):
		return Status.LOCKED
	if not profile.can_afford("shards", next_cost(profile, node)):
		return Status.TOO_EXPENSIVE
	return Status.LEARNABLE


static func learn(profile: ProfileData, node: SkillNodeData) -> bool:
	if status(profile, node) != Status.LEARNABLE:
		return false
	profile.add_currency("shards", -next_cost(profile, node))
	profile.set_tree_rank(node.id, learned_rank(profile, node) + 1)
	return true


# --- Builds (Points de Chasseur)

static func default_build() -> Dictionary:
	return {"name": "", "nodes": {"blade_cleaving_slash": 1, "prism_prismatic_lance": 1},
		"spells": DEFAULT_SPELLS.duplicate(), "echoes": {}}


## Builds du profil, complétés si la sauvegarde est incomplète ou abîmée.
static func builds(profile: ProfileData) -> Array:
	var hunter: Dictionary = profile.data["hunter"]
	var list: Array = hunter["builds"]
	var migrated: bool = list.is_empty()
	for i: int in list.size():
		if not (list[i] is Dictionary):
			list[i] = default_build()
		var build: Dictionary = list[i]
		if not (build.get("nodes") is Dictionary):
			build["nodes"] = {}
		if not (build.get("spells") is Array):
			build["spells"] = DEFAULT_SPELLS.duplicate()
		while (build["spells"] as Array).size() < SPELL_SLOTS:
			(build["spells"] as Array).append("")
		if not build.has("name"):
			build["name"] = ""
		if not (build.get("echoes") is Dictionary):
			build["echoes"] = {}
	while list.size() < BUILD_COUNT:
		list.append(default_build())
	if migrated:
		_activate_learned_passives(profile)
	return list


## Sauvegarde venue de l'arbre v1 : le build actif reprend les passifs déjà appris, tant que les points suffisent.
static func _activate_learned_passives(profile: ProfileData) -> void:
	for id: StringName in GameDB.sorted_ids(GameDB.skill_nodes):
		var node: SkillNodeData = GameDB.skill_nodes[id]
		if node.kind != SkillNodeData.Kind.PASSIVE:
			continue
		while activation_error(profile, node) == "" and _rivals(profile, node).is_empty():
			activate(profile, node)


static func active_index(profile: ProfileData) -> int:
	return clampi(int(profile.data["hunter"].get("active_build", 0)), 0, BUILD_COUNT - 1)


static func set_active_index(profile: ProfileData, index: int) -> void:
	profile.data["hunter"]["active_build"] = clampi(index, 0, BUILD_COUNT - 1)


static func active_build(profile: ProfileData) -> Dictionary:
	return builds(profile)[active_index(profile)]


static func active_rank(profile: ProfileData, node: SkillNodeData) -> int:
	if node.is_utility():
		return learned_rank(profile, node)
	return mini(int(active_build(profile)["nodes"].get(String(node.id), 0)), learned_rank(profile, node))


static func points_total(profile: ProfileData) -> int:
	var maps: int = (profile.data["hunter"].get("maps_won", []) as Array).size()
	var objectives: int = (profile.data["objectives"].get("completed", []) as Array).size() \
		+ Campaign.objectives_completed(profile)
	var test: int = int(profile.data["hunter"].get("test_points", 0))
	return BASE_POINTS + maps + objectives / OBJECTIVES_PER_POINT + test


static func points_used(profile: ProfileData) -> int:
	var used: int = 0
	for key: Variant in active_build(profile)["nodes"]:
		var node: SkillNodeData = GameDB.skill_node(StringName(str(key)))
		if node and not node.is_utility():
			used += active_rank(profile, node) * node.point_cost
	return used


static func points_left(profile: ProfileData) -> int:
	return points_total(profile) - points_used(profile)


## Nœud SPELL qui débloque un sort donné (null si aucun).
static func spell_node(spell_id: StringName) -> SkillNodeData:
	for id: StringName in GameDB.skill_nodes:
		var node: SkillNodeData = GameDB.skill_nodes[id]
		if node.kind == SkillNodeData.Kind.SPELL and node.spell_id == spell_id:
			return node
	return null


## Nœuds actifs du même groupe exclusif (remplacés si on active `node`).
static func _rivals(profile: ProfileData, node: SkillNodeData) -> Array[SkillNodeData]:
	var rivals: Array[SkillNodeData] = []
	if node.exclusive_group == &"":
		return rivals
	for id: StringName in GameDB.skill_nodes:
		var other: SkillNodeData = GameDB.skill_nodes[id]
		if other != node and other.exclusive_group == node.exclusive_group and active_rank(profile, other) > 0:
			rivals.append(other)
	return rivals


## Clé de traduction de la raison d'un refus d'activation, vide si l'activation (d'un rang de plus) est possible.
static func activation_error(profile: ProfileData, node: SkillNodeData) -> String:
	if node.is_utility():
		return "TREE_ERR_UTILITY"
	if not node.implemented:
		return "TREE_ERR_COMING_SOON"
	if active_rank(profile, node) >= learned_rank(profile, node):
		return "TREE_ERR_NOT_LEARNED" if learned_rank(profile, node) == 0 else "TREE_ERR_MAX_ACTIVE"
	if node.kind == SkillNodeData.Kind.VARIANT:
		var spell: SkillNodeData = spell_node(node.spell_id)
		if spell == null or active_rank(profile, spell) == 0:
			return "TREE_ERR_NEEDS_SPELL"
	var freed: int = 0
	for rival: SkillNodeData in _rivals(profile, node):
		freed += active_rank(profile, rival) * rival.point_cost
	if node.point_cost > points_left(profile) + freed:
		return "TREE_ERR_POINTS"
	return ""


## Active un rang de plus dans le build actif (remplace un nœud exclusif déjà actif). Un sort activé est équipé
## sur le premier emplacement libre.
static func activate(profile: ProfileData, node: SkillNodeData) -> bool:
	if activation_error(profile, node) != "":
		return false
	for rival: SkillNodeData in _rivals(profile, node):
		_set_active(profile, rival, 0)
	_set_active(profile, node, active_rank(profile, node) + 1)
	if node.kind == SkillNodeData.Kind.SPELL and slot_of(profile, node.spell_id) < 0:
		var spells: Array = active_build(profile)["spells"]
		var free: int = spells.find("")
		if free >= 0:
			spells[free] = String(node.spell_id)
	return true


## Retire un rang actif. Un sort désactivé perd ses variantes et quitte son emplacement.
static func deactivate(profile: ProfileData, node: SkillNodeData) -> bool:
	var rank: int = active_rank(profile, node)
	if rank == 0 or node.is_utility():
		return false
	_set_active(profile, node, rank - 1)
	return true


static func _set_active(profile: ProfileData, node: SkillNodeData, rank: int) -> void:
	var nodes: Dictionary = active_build(profile)["nodes"]
	if rank <= 0:
		nodes.erase(String(node.id))
	else:
		nodes[String(node.id)] = rank
	if rank <= 0 and node.kind == SkillNodeData.Kind.SPELL:
		for id: StringName in GameDB.skill_nodes:
			var other: SkillNodeData = GameDB.skill_nodes[id]
			if other.kind == SkillNodeData.Kind.VARIANT and other.spell_id == node.spell_id:
				nodes.erase(String(other.id))
		var slot: int = slot_of(profile, node.spell_id)
		if slot >= 0:
			active_build(profile)["spells"][slot] = ""


static func slot_of(profile: ProfileData, spell_id: StringName) -> int:
	return (active_build(profile)["spells"] as Array).find(String(spell_id))


## Équipe un sort actif sur un emplacement (échange avec l'emplacement qu'il occupait).
static func equip(profile: ProfileData, spell_id: StringName, slot: int) -> bool:
	var node: SkillNodeData = spell_node(spell_id)
	if node == null or active_rank(profile, node) == 0 or slot < 0 or slot >= SPELL_SLOTS:
		return false
	var spells: Array = active_build(profile)["spells"]
	var previous: int = spells.find(String(spell_id))
	if previous >= 0:
		spells[previous] = spells[slot]
	spells[slot] = String(spell_id)
	return true


# --- Partie

## Sorts équipés (dans l'ordre des touches) et variantes actives {sort: variante}.
static func loadout(profile: ProfileData) -> Dictionary:
	var spells: Array[StringName] = []
	for raw: Variant in active_build(profile)["spells"]:
		var spell_id := StringName(str(raw))
		var node: SkillNodeData = spell_node(spell_id) if spell_id != &"" else null
		spells.append(spell_id if node and active_rank(profile, node) > 0 else &"")
	var variants: Dictionary = {}
	for id: StringName in GameDB.skill_nodes:
		var node: SkillNodeData = GameDB.skill_nodes[id]
		if node.kind == SkillNodeData.Kind.VARIANT and node.implemented and active_rank(profile, node) > 0:
			variants[node.spell_id] = node.variant_kind
	return {"spells": spells, "variants": variants}


## Effets à installer en début de partie (une fois par rang actif ; améliorations du refuge : par rang appris).
static func effects_for(profile: ProfileData) -> Array[GameplayEffect]:
	var effects: Array[GameplayEffect] = []
	for id: StringName in GameDB.sorted_ids(GameDB.skill_nodes):
		var node: SkillNodeData = GameDB.skill_nodes[id]
		if not node.implemented:
			continue
		for i: int in mini(active_rank(profile, node), node.max_rank()):
			effects.append_array(node.effects)
	return effects


## Mode test (outil de développement, jamais dans le jeu publié) : tout l'arbre appris, paliers ouverts, points
## en abondance. Le joueur active et équipe ensuite ce qu'il veut essayer.
static func unlock_all_for_testing(profile: ProfileData) -> void:
	for id: StringName in GameDB.skill_nodes:
		var node: SkillNodeData = GameDB.skill_nodes[id]
		profile.set_tree_rank(id, node.max_rank())
	for id: StringName in GameDB.echo_nodes:
		profile.set_tree_rank(id, (GameDB.echo_nodes[id] as SkillNodeData).max_rank())
	profile.data["runs"]["won"] = maxi(boss_wins(profile), 3)
	profile.data["hunter"]["test_points"] = 200
	Campaign.unlock_all_for_testing(profile)
	profile.add_currency("shards", 10000)


## Première victoire sur une carte (clé « nightmare:<carte> » pour le Cauchemar) : +1 Point de Chasseur.
static func record_victory(profile: ProfileData, arena_id: String) -> bool:
	var maps: Array = profile.data["hunter"]["maps_won"]
	if arena_id == "" or maps.has(arena_id):
		return false
	maps.append(arena_id)
	return true


static func nodes_of_branch(branch_id: StringName) -> Array[SkillNodeData]:
	var nodes: Array[SkillNodeData] = []
	for id: StringName in GameDB.sorted_ids(GameDB.skill_nodes):
		var node: SkillNodeData = GameDB.skill_nodes[id]
		if node.branch == branch_id:
			nodes.append(node)
	nodes.sort_custom(func(a: SkillNodeData, b: SkillNodeData) -> bool:
		return a.tier < b.tier or (a.tier == b.tier and (a.kind < b.kind or (a.kind == b.kind and String(a.id) < String(b.id)))))
	return nodes
