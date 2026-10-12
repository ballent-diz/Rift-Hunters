class_name WavePhaseData
extends Resource
## Tranche de temps de vague.

@export var start_time: float = 0.0
@export var end_time: float = 60.0
@export var enemies: Array[StringName] = []
@export var weights: Array[float] = []
## Ennemis par seconde.
@export var spawn_rate: float = 1.0
@export var max_alive: int = 80
