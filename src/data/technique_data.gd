class_name TechniqueData
extends Resource
## Technique active d'un Écho, déclenchée par le joueur (touches 1-2-3).

@export var id: StringName = &""
## Identifiant de la stratégie de code (voir src/entities/allies/techniques.gd).
@export var technique_kind: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var cooldown: float = 10.0
@export var damage: float = 20.0
@export var radius: float = 150.0
@export var duration: float = 0.0
@export var count: int = 1
@export var statuses: Array[StatusApplication] = []
@export var params: Dictionary = {}
