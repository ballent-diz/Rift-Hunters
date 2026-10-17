extends Node
## Base de données du contenu. Charge tous les .tres de data/ et les indexe par identifiant.
## Ajouter du contenu = déposer un .tres dans le bon dossier.

const DATA_ROOT := "res://data/"

var balance: BalanceConfig
var monsters: Dictionary = {}
var enemies: Dictionary = {}
var affixes: Dictionary = {}
var bosses: Dictionary = {}
var statuses: Dictionary = {}
var upgrades: Dictionary = {}
var relics: Dictionary = {}
var synergies: Dictionary = {}
var arenas: Dictionary = {}
var difficulties: Dictionary = {}
var skill_branches: Dictionary = {}
var skill_nodes: Dictionary = {}
var objectives: Dictionary = {}
var research: Dictionary = {}
var modifiers: Dictionary = {}
var spells: Dictionary = {}
## Arbres des Échos (nœuds, branch = identifiant de l'Écho) et seconds sorts des Échos (lot C3).
var echo_nodes: Dictionary = {}
var techniques: Dictionary = {}
var chapters: Dictionary = {}
var load_errors: PackedStringArray = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	load_errors.clear()
	balance = load(DATA_ROOT + "balance/balance_config.tres") as BalanceConfig
	if balance == null:
		load_errors.append("balance_config.tres introuvable")
		balance = BalanceConfig.new()
	monsters = _load_dir("monsters")
	enemies = _load_dir("enemies")
	affixes = _load_dir("affixes")
	bosses = _load_dir("bosses")
	statuses = _load_dir("statuses")
	upgrades = _load_dir("upgrades")
	relics = _load_dir("relics")
	synergies = _load_dir("synergies")
	arenas = _load_dir("arenas")
	difficulties = _load_dir("difficulties")
	skill_branches = _load_dir("progression/branches")
	skill_nodes = _load_dir("progression/skill_tree")
	objectives = _load_dir("progression/objectives")
	research = _load_dir("progression/research")
	modifiers = _load_dir("modifiers")
	spells = _load_dir("spells")
	echo_nodes = _load_dir("progression/echo_tree")
	techniques = _load_dir("techniques")
	chapters = _load_dir("chapters")
	for error: String in load_errors:
		push_error("GameDB : " + error)


func monster(id: StringName) -> MonsterData:
	return monsters.get(id) as MonsterData


func enemy(id: StringName) -> EnemyData:
	return enemies.get(id) as EnemyData


func affix(id: StringName) -> EliteAffixData:
	return affixes.get(id) as EliteAffixData


func boss(id: StringName) -> BossData:
	return bosses.get(id) as BossData


func status(id: StringName) -> StatusData:
	return statuses.get(id) as StatusData


func upgrade(id: StringName) -> UpgradeData:
	return upgrades.get(id) as UpgradeData


func relic(id: StringName) -> RelicData:
	return relics.get(id) as RelicData


func arena(id: StringName) -> ArenaData:
	return arenas.get(id) as ArenaData


func difficulty(id: StringName) -> DifficultyData:
	return difficulties.get(id) as DifficultyData


func skill_node(id: StringName) -> SkillNodeData:
	return skill_nodes.get(id) as SkillNodeData


func modifier(id: StringName) -> RunModifierData:
	return modifiers.get(id) as RunModifierData


func objective(id: StringName) -> ObjectiveData:
	return objectives.get(id) as ObjectiveData


func research_item(id: StringName) -> ResearchData:
	return research.get(id) as ResearchData


## Identifiants triés (ordre stable pour l'UI et les tests).
static func sorted_ids(dict: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in dict:
		ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## Chapitres de campagne dans l'ordre.
func chapters_in_order() -> Array[ChapterData]:
	var list: Array[ChapterData] = []
	for id: StringName in chapters:
		list.append(chapters[id] as ChapterData)
	list.sort_custom(func(a: ChapterData, b: ChapterData) -> bool: return a.order < b.order)
	return list


func difficulties_by_level() -> Array[DifficultyData]:
	var list: Array[DifficultyData] = []
	for id: StringName in difficulties:
		list.append(difficulties[id])
	list.sort_custom(func(a: DifficultyData, b: DifficultyData) -> bool: return a.level < b.level)
	return list


## Liste les fichiers de ressources d'un dossier (gère les .remap des exports).
static func list_resource_files(dir_path: String) -> PackedStringArray:
	var files: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return files
	for file_name: String in dir.get_files():
		var clean: String = file_name.trim_suffix(".remap")
		if clean.ends_with(".tres") or clean.ends_with(".res"):
			if not files.has(dir_path.path_join(clean)):
				files.append(dir_path.path_join(clean))
	files.sort()
	return files


func _load_dir(sub: String) -> Dictionary:
	var result: Dictionary = {}
	for path: String in list_resource_files(DATA_ROOT + sub):
		var res: Resource = load(path)
		if res == null or not ("id" in res):
			load_errors.append("Ressource invalide : " + path)
			continue
		var id: StringName = res.get("id")
		if id == &"":
			load_errors.append("Identifiant vide : " + path)
		elif result.has(id):
			load_errors.append("Identifiant dupliqué '%s' : %s" % [id, path])
		else:
			result[id] = res
	return result
