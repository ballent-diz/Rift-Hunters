class_name BossPhaseData
extends Resource
## Phase de boss : active quand ratio de PV <= hp_threshold.

@export var hp_threshold: float = 1.0
@export var name_key: String = ""
@export var move_speed_mult: float = 1.0
## Pause entre deux attaques.
@export var pattern_interval: float = 2.0
## Durée de la transformation à l'entrée de la phase (invulnérable).
@export var transition_time: float = 0.0
@export var patterns: Array[BossPatternData] = []
