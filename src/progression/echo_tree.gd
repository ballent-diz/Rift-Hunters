class_name EchoTree
extends RefCounted
## Arbres des Échos (docs/design/ARBRES_DES_ECHOS.md), fonctions pures sur ProfileData. Mêmes règles que l'arbre du
## Chasseur : apprendre coûte des Éclats (rangs partagés dans profile.data["tree"]), activer coûte des Points d'Écho
## (2 + niveau de maîtrise). Les activations vivent dans le build actif du Chasseur : build["echoes"][écho]["nodes"].
## v2 (docs/design/ARBRES_DES_ECHOS.md) : la maîtrise de l'Écho ouvre les nœuds (required_mastery) ; une variante
## (VARIANT) ne vaut que pour le sort équipé, désigné dans ses prérequis ; un groupe exclusif (signatures A ou B)
## n'a qu'un nœud actif.

const BASE_POINTS := 2


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


## Niveau de maîtrise de l'Écho (0 à 5).
static func mastery_level(profile: ProfileData, monster_id: StringName) -> int:
	var monster: MonsterData = GameDB.monster(monster_id)
	return Mastery.level(profile, monster) if monster else 0


static func status(profile: ProfileData, n: SkillNodeData) -> HunterTree.Status:
	if learned_rank(profile, n) >= n.max_rank():
		return HunterTree.Status.LEARNED
	if mastery_level(profile, n.branch) < n.required_mastery:
		return HunterTree.Status.GATED
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
	if n.kind == SkillNodeData.Kind.VARIANT:
		# Une variante ne compte que pour le sort équipé.
		var spell: SkillNodeData = spell_of(n)
		if spell == null or active_rank(profile, spell) == 0:
			return 0
	return mini(int(nodes.get(String(n.id), 0)), learned_rank(profile, n))


## Sort modifié par une variante : le premier de ses prérequis qui est un sort.
static func spell_of(n: SkillNodeData) -> SkillNodeData:
	for prereq: StringName in n.prerequisites:
		var other: SkillNodeData = node(prereq)
		if other and other.kind == SkillNodeData.Kind.SPELL:
			return other
	return null


## Nœuds actifs du même groupe exclusif (signatures A ou B, variantes d'un sort), remplacés si on active `n`.
## Les deux sorts d'un Écho s'échangent à part (un seul équipé).
static func rivals(profile: ProfileData, n: SkillNodeData) -> Array[SkillNodeData]:
	var result: Array[SkillNodeData] = []
	if n.exclusive_group == &"" or n.kind == SkillNodeData.Kind.SPELL:
		return result
	for other: SkillNodeData in nodes_of(n.branch):
		if other != n and other.exclusive_group == n.exclusive_group and active_rank(profile, other) > 0:
			result.append(other)
	return result


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


static func points_left(profile: ProfileData, monster_id: StringName) -> int:
	return points_total(profile, monster_id) - points_used(profile, monster_id)


static func activation_error(profile: ProfileData, n: SkillNodeData) -> String:
	if active_rank(profile, n) >= learned_rank(profile, n):
		return "TREE_ERR_NOT_LEARNED" if learned_rank(profile, n) == 0 else "TREE_ERR_MAX_ACTIVE"
	if n.kind == SkillNodeData.Kind.VARIANT:
		var spell: SkillNodeData = spell_of(n)
		if spell == null or active_rank(profile, spell) == 0:
			return "TREE_ERR_NEEDS_SPELL"
	var freed: int = 0
	for rival: SkillNodeData in rivals(profile, n):
		freed += active_rank(profile, rival) * rival.point_cost
	if n.point_cost > points_left(profile, n.branch) + freed:
		return "ECHO_TREE_ERR_POINTS"
	return ""


## Active un rang de plus. Un sort remplace l'autre sort de l'Écho (un seul équipé) et retire les variantes de
## l'ancien ; un nœud exclusif remplace son rival.
static func activate(profile: ProfileData, n: SkillNodeData) -> bool:
	if activation_error(profile, n) != "":
		return false
	var nodes: Dictionary = _echo_build(profile, n.branch)["nodes"]
	if n.kind == SkillNodeData.Kind.SPELL:
		for other: SkillNodeData in nodes_of(n.branch):
			if other.kind == SkillNodeData.Kind.SPELL or (other.kind == SkillNodeData.Kind.VARIANT and spell_of(other) != n):
				nodes.erase(String(other.id))
		if not n.learned_by_default:
			nodes[String(n.id)] = 1
		return true
	for rival: SkillNodeData in rivals(profile, n):
		nodes.erase(String(rival.id))
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


## Mode test (outil de développement, jamais dans le jeu publié) : tous les Échos débloqués et découverts,
## sans passer par le Rite de lien. Retourne le nombre d'Échos nouvellement débloqués.
static func unlock_all_echoes_for_testing(profile: ProfileData) -> int:
	var added: int = 0
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		if not profile.is_monster_unlocked(GameDB.monsters[id]):
			profile.unlock("monster:" + String(id))
			added += 1
		profile.discover("monsters", String(id))
	return added


# --- Partie

## Second sort équipé (null : la Technique d'origine de l'Écho).
static func chosen_technique(profile: ProfileData, monster_id: StringName) -> TechniqueData:
	var spell: SkillNodeData = _alternative_spell(profile, monster_id)
	return GameDB.techniques.get(spell.spell_id) as TechniqueData if spell else null


## Variante active du sort équipé (null : aucune) ; son variant_kind modifie la technique en partie.
static func chosen_variant(profile: ProfileData, monster_id: StringName) -> SkillNodeData:
	for n: SkillNodeData in nodes_of(monster_id):
		if n.kind == SkillNodeData.Kind.VARIANT and active_rank(profile, n) > 0:
			return n
	return null


## Effets des passifs actifs, installés quand l'Écho rejoint l'équipe.
static func effects_for(profile: ProfileData, monster_id: StringName) -> Array[GameplayEffect]:
	var effects: Array[GameplayEffect] = []
	for n: SkillNodeData in nodes_of(monster_id):
		if n.kind == SkillNodeData.Kind.SPELL:
			continue
		for i: int in active_rank(profile, n):
			effects.append_array(n.effects)
	return effects
