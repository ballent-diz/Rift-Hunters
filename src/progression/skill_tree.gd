class_name SkillTree
extends RefCounted
## Règles de l'arbre permanent du Chasseur (fonctions pures sur ProfileData).

enum Status { OWNED_MAX, AVAILABLE, TOO_EXPENSIVE, LOCKED, EXCLUDED }

const RESPEC_ESSENCE_PER_RESET := 2
const RESPEC_ESSENCE_CAP := 10


static func next_cost(profile: ProfileData, node: SkillNodeData) -> int:
	var rank: int = profile.tree_rank(node.id)
	return node.costs[rank] if rank < node.max_rank() else -1


static func prerequisites_met(profile: ProfileData, node: SkillNodeData) -> bool:
	if node.prerequisites.is_empty():
		return true
	var met: int = 0
	for prereq: StringName in node.prerequisites:
		if profile.tree_rank(prereq) > 0:
			met += 1
	return met > 0 if node.prerequisites_any else met == node.prerequisites.size()


## Nœud d'un même groupe exclusif déjà acquis (sinon &"").
static func excluded_by(profile: ProfileData, node: SkillNodeData) -> StringName:
	if node.exclusive_group == &"":
		return &""
	for id: StringName in GameDB.skill_nodes:
		var other: SkillNodeData = GameDB.skill_nodes[id]
		if other.id != node.id and other.exclusive_group == node.exclusive_group and profile.tree_rank(other.id) > 0:
			return other.id
	return &""


static func status(profile: ProfileData, node: SkillNodeData) -> Status:
	if profile.tree_rank(node.id) >= node.max_rank():
		return Status.OWNED_MAX
	if excluded_by(profile, node) != &"":
		return Status.EXCLUDED
	if not prerequisites_met(profile, node):
		return Status.LOCKED
	if not profile.can_afford("shards", next_cost(profile, node)):
		return Status.TOO_EXPENSIVE
	return Status.AVAILABLE


static func buy(profile: ProfileData, node: SkillNodeData) -> bool:
	if status(profile, node) != Status.AVAILABLE:
		return false
	profile.add_currency("shards", -next_cost(profile, node))
	profile.set_tree_rank(node.id, profile.tree_rank(node.id) + 1)
	return true


static func spent_shards(profile: ProfileData) -> int:
	var total: int = 0
	for id: StringName in GameDB.skill_nodes:
		var node: SkillNodeData = GameDB.skill_nodes[id]
		for i: int in mini(profile.tree_rank(id), node.max_rank()):
			total += node.costs[i]
	return total


## Coût en Essence de la prochaine réinitialisation (la première est gratuite).
static func respec_cost(profile: ProfileData) -> int:
	return mini(int(profile.data["tree_resets"]) * RESPEC_ESSENCE_PER_RESET, RESPEC_ESSENCE_CAP)


## Réinitialise l'arbre : rembourse 100 % des Éclats dépensés.
static func respec(profile: ProfileData) -> bool:
	var cost: int = respec_cost(profile)
	if not profile.can_afford("essence", cost) or spent_shards(profile) == 0:
		return false
	profile.add_currency("essence", -cost)
	profile.add_currency("shards", spent_shards(profile))
	profile.data["tree"] = {}
	profile.data["tree_resets"] = int(profile.data["tree_resets"]) + 1
	return true


## Effets à installer en début de partie (une fois par rang).
static func effects_for(profile: ProfileData) -> Array[GameplayEffect]:
	var effects: Array[GameplayEffect] = []
	for id: StringName in GameDB.sorted_ids(GameDB.skill_nodes):
		var node: SkillNodeData = GameDB.skill_nodes[id]
		for i: int in mini(profile.tree_rank(id), node.max_rank()):
			effects.append_array(node.effects)
	return effects


static func nodes_of_branch(branch_id: StringName) -> Array[SkillNodeData]:
	var nodes: Array[SkillNodeData] = []
	for id: StringName in GameDB.sorted_ids(GameDB.skill_nodes):
		var node: SkillNodeData = GameDB.skill_nodes[id]
		if node.branch == branch_id:
			nodes.append(node)
	nodes.sort_custom(func(a: SkillNodeData, b: SkillNodeData) -> bool:
		return a.tier < b.tier or (a.tier == b.tier and String(a.id) < String(b.id)))
	return nodes
