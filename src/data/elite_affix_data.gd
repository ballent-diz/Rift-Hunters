class_name EliteAffixData
extends Resource
## Affixe d'élite. on_death : &"" (rien), &"explode", &"split".

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var hp_mult: float = 1.0
@export var speed_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var defense_add: float = 0.0
@export var on_death: StringName = &""
@export var params: Dictionary = {}
@export var tint: Color = Color.WHITE
