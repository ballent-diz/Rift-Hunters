class_name BossPatternData
extends Resource
## Attaque de boss. kind correspond à une méthode de BossController (_pattern_<kind>).

@export var kind: StringName = &""
@export var name_key: String = ""
@export var weight: float = 1.0
@export var cooldown: float = 6.0
@export var damage: float = 15.0
@export var telegraph: float = 0.8
@export var params: Dictionary = {}
