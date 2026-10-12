class_name SkillNodeData
extends Resource
## Nœud de l'arbre permanent. Les effets sont installés une fois par rang en début de partie.

@export var id: StringName = &""
@export var branch: StringName = &""
## Palier (ligne) dans la branche, à partir de 0.
@export var tier: int = 0
@export var name_key: String = ""
@export var desc_key: String = ""
## Coût en Éclats de chaque rang (taille = rang maximum).
@export var costs: Array[int] = [50]
## Nœuds requis (au moins un rang).
@export var prerequisites: Array[StringName] = []
## true : un seul prérequis suffit. false : tous sont requis.
@export var prerequisites_any: bool = false
## Un seul nœud d'un même groupe exclusif peut être acquis.
@export var exclusive_group: StringName = &""
@export var effects: Array[GameplayEffect] = []


func max_rank() -> int:
	return costs.size()
