class_name BossData
extends Resource
## Dévoreur (boss de fin de chapitre) ou gardien (boss de carte, plus court : docs/design/CARTES.md).

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
## Gardien : boss de carte en une phase, souvent sur le sprite d'une élite agrandi (annonce et barre propres).
@export var guardian: bool = false
## Agrandissement du sprite (un gardien réutilise le sprite d'une élite).
@export var visual_scale: float = 1.0
