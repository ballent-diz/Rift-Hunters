class_name EchoTree
extends RefCounted
## Arbres des Échos (docs/design/ARBRES_DES_ECHOS.md), fonctions pures sur ProfileData. Mêmes règles que l'arbre du
## Chasseur : apprendre coûte des Éclats (rangs partagés dans profile.data["tree"]), activer coûte des Points d'Écho
## (1 + niveau de maîtrise). Les activations vivent dans le build actif du Chasseur : build["echoes"][écho]["nodes"].

const BASE_POINTS := 1


static func nodes_of(monster_id: StringName) -> Array[SkillNodeData]:
	var nodes: Array[SkillNodeData] = []
	for id: StringName in GameDB.sorted_ids(GameDB.echo_nodes):
		var node: SkillNodeData = GameDB.echo_nodes[id]
		if node.branch == monster_id:
			nodes.append(node)
	nodes.sort_custom(func(a: SkillNodeData, b: SkillNodeData) -> bool:
		return a.tier < b.tier or (a.tier == b.tier and String(a.id) < String(b.id)))
	return nodes


static func node(id: StringName) -> SkillNodeData:
	return GameDB.echo_nodes.get(id) as SkillNodeData


# --- Apprendre (Éclats)

static func learned_rank(profile: ProfileData, n: SkillNodeData) -> int:
	var rank: int = profile.tree_rank(n.id)
	return maxi(rank, 1) if n.learned_by_default else rank


static func next_cost(profile: ProfileData, n: SkillNodeData) -> int:
	var rank: int = learned_rank(profile, n)
	return n.costs[rank] if rank < n.max_rank() else -1


static func prerequisites_met(profile: ProfileData, n: SkillNodeData) -> bool:
	if n.prerequisites.is_empty():
		return true
	var met: int = 0
	for prereq: StringName in n.prerequisites:
		var other: SkillNodeData = node(prereq)
		if other and learned_rank(profile, other) > 0:
			met += 1
	return met > 0 if n.prerequisites_any else met == n.prerequisites.size()


static func status(profile: ProfileData, n: SkillNodeData) -> HunterTree.Status:
	if learned_rank(profile, n) >= n.max_rank():
		return HunterTree.Status.LEARNED
	if not prerequisites_met(profile, n):
		return HunterTree.Status.LOCKED
	if not profile.can_afford("shards", next_cost(profile, n)):
		return HunterTree.Status.TOO_EXPENSIVE
	return HunterTree.Status.LEARNABLE


static func learn(profile: ProfileData, n: SkillNodeData) -> bool:
	if status(profile, n) != HunterTree.Status.LEARNABLE:
		return false
	profile.add_currency("shards", -next_cost(profile, n))
	profile.set_tree_rank(n.id, learned_rank(profile, n) + 1)
	return true


# --- Activer (Points d'Écho, dans le build actif)

static func _echo_build(profile: ProfileData, monster_id: StringName) -> Dictionary:
	var echoes: Dictionary = HunterTree.active_build(profile)["echoes"]
	var key: String = String(monster_id)
	if not (echoes.get(key) is Dictionary):
		echoes[key] = {"nodes": {}}
	var entry: Dictionary = echoes[key]
	if not (entry.get("nodes") is Dictionary):
		entry["nodes"] = {}
	return entry


static func active_rank(profile: ProfileData, n: SkillNodeData) -> int:
	var nodes: Dictionary = _echo_build(profile, n.branch)["nodes"]
	if n.kind == SkillNodeData.Kind.SPELL and n.learned_by_default:
		# Sort d'origine : actif tant qu'aucun autre sort de l'Écho ne l'est.
		return 0 if _alternative_spell(profile, n.branch) != null else 1
	return mini(int(nodes.get(String(n.id), 0)), learned_rank(profile, n))


static func _alternative_spell(profile: ProfileData, monster_id: StringName) -> SkillNodeData:
	var nodes: Dictionary = _echo_build(profile, monster_id)["nodes"]
	for n: SkillNodeData in nodes_of(monster_id):
		if n.kind == SkillNodeData.Kind.SPELL and not n.learned_by_default and int(nodes.get(String(n.id), 0)) > 0 \
				and learned_rank(profile, n) > 0:
			return n
	return null


static func points_total(profile: ProfileData, monster_id: StringName) -> int:
	var monster: MonsterData = GameDB.monster(monster_id)
	var test: int = 10 if int(profile.data["hunter"].get("test_points", 0)) > 0 else 0
	return BASE_POINTS + (Mastery.level(profile, monster) if monster else 0) + test


static func points_used(profile: ProfileData, monster_id: StringName) -> int:
	var used: int = 0
	for n: SkillNodeData in nodes_of(monster_id):
		used += active_rank(profile, n) * n.point_cost
	return used


static func activation_error(profile: ProfileData, n: SkillNodeData) -> String:
	if active_rank(profile, n) >= learned_rank(profile, n):
		return "TREE_ERR_NOT_LEARNED" if learned_rank(profile, n) == 0 else "TREE_ERR_MAX_ACTIVE"
	if n.point_cost > points_total(profile, n.branch) - points_used(profile, n.branch):
		return "ECHO_TREE_ERR_POINTS"
	return ""


## Active un rang de plus. Un sort remplace l'autre sort de l'Écho (un seul équipé).
static func activate(profile: ProfileData, n: SkillNodeData) -> bool:
	if activation_error(profile, n) != "":
		return false
	var nodes: Dictionary = _echo_build(profile, n.branch)["nodes"]
	if n.kind == SkillNodeData.Kind.SPELL:
		for other: SkillNodeData in nodes_of(n.branch):
			if other.kind == SkillNodeData.Kind.SPELL:
				nodes.erase(String(other.id))
		if not n.learned_by_default:
			nodes[String(n.id)] = 1
		return true
	nodes[String(n.id)] = active_rank(profile, n) + 1
	return true


static func deactivate(profile: ProfileData, n: SkillNodeData) -> bool:
	var rank: int = active_rank(profile, n)
	if rank == 0 or (n.kind == SkillNodeData.Kind.SPELL and n.learned_by_default):
		return false
	var nodes: Dictionary = _echo_build(profile, n.branch)["nodes"]
	if rank <= 1:
		nodes.erase(String(n.id))
	else:
		nodes[String(n.id)] = rank - 1
	return true


# --- Partie

## Second sort équipé (null : la Technique d'origine de l'Écho).
static func chosen_technique(profile: ProfileData, monster_id: StringName) -> TechniqueData:
	var spell: SkillNodeData = _alternative_spell(profile, monster_id)
	return GameDB.techniques.get(spell.spell_id) as TechniqueData if spell else null


## Effets des passifs actifs, installés quand l'Écho rejoint l'équipe.
static func effects_for(profile: ProfileData, monster_id: StringName) -> Array[GameplayEffect]:
	var effects: Array[GameplayEffect] = []
	for n: SkillNodeData in nodes_of(monster_id):
		if n.kind == SkillNodeData.Kind.SPELL:
			continue
		for i: int in active_rank(profile, n):
			effects.append_array(n.effects)
	return effects
