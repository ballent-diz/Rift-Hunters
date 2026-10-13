class_name BossData
extends Resource
## Dévoreur (boss).

@export var id: StringName = &""
@export var name_key: String = ""
@export var title_key: String = ""
@export var max_hp: float = 5000.0
@export var damage: float = 20.0
@export var defense: float = 30.0
@export var move_speed: float = 40.0
@export var radius: float = 70.0
@export var phases: Array[BossPhaseData] = []
@export var shard_reward: int = 200
@export var essence_reward: int = 10
@export var visual: VisualData
