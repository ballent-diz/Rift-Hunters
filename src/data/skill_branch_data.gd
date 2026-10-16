class_name SkillBranchData
extends Resource
## Voie de l'arbre du Chasseur (tronc, Lame, Prisme, Abîme, Lien) ou groupe d'améliorations du refuge.

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var order: int = 0
@export var color: Color = Color.WHITE
## Améliorations du refuge (toujours actives une fois apprises, hors du budget de points).
@export var utility: bool = false
