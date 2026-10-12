class_name RelicData
extends Resource
## Relique (coffres). Souvent avec une contrepartie.

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export_range(0, 3) var rarity: int = 0
@export var requires_any_monster: Array[StringName] = []
@export var unlocked_by_default: bool = true
@export var effects: Array[GameplayEffect] = []
@export var color: Color = Color(1.0, 0.8, 0.4)
