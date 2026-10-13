class_name ResearchData
extends Resource
## Recherche du Laboratoire, payée en Essence.

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var order: int = 0
@export var cost_essence: int = 5
@export var prerequisites: Array[StringName] = []
## Déblocages « type:id » (voir ObjectiveData.reward_unlocks).
@export var unlocks: Array[String] = []
