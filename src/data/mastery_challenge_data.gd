class_name MasteryChallengeData
extends Resource
## Défi de maîtrise : récompense une façon de jouer un Écho.

@export var id: StringName = &""
@export var desc_key: String = ""
## Statistique de partie suivie (voir RunStats).
@export var stat_key: StringName = &""
@export var threshold: float = 1.0
## true : cumul sur toutes les parties, false : en une seule partie.
@export var lifetime: bool = false
@export var requires_victory: bool = false
@export var xp: int = 40
