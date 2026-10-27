class_name LevelZoneData
extends Resource
## Zone du mode « vagues par zone » : région de la carte fermée par des barrières, avec ses vagues.

@export var name_key: String = ""
## Point à l'intérieur de la zone (la région est retrouvée par connexité, barrières fermées).
@export var anchor: Vector2 = Vector2.ZERO
@export var waves: Array[ZoneWaveData] = []
## Barrières qui s'ouvrent quand la dernière vague est nettoyée.
@export var exit_walls: Array[Rect2] = []
## Récompense à la sortie : part des PV max rendue, et un coffre.
@export_range(0.0, 1.0, 0.05) var heal_ratio: float = 0.25
@export var reward_chest: bool = true
@export_group("Gardien de fin de palier (grande arène)")
## Élite en version boss qui apparaît après la dernière vague ; le palier se termine à sa mort.
@export var guardian_enemy: StringName = &""
@export var guardian_hp_mult: float = 12.0
@export var guardian_scale: float = 1.7
## Boss (BossData) qui apparaît après la dernière vague : sa mort finit la carte (Dévoreur du chapitre).
@export var guardian_boss: StringName = &""
