class_name ZoneWaveData
extends Resource
## Une vague du mode « vagues par zone » : un nombre fini de Corrompus à éliminer.

@export var enemies: Array[StringName] = []
@export var weights: Array[float] = []
## Nombre de Corrompus standards de la vague.
@export var count: int = 30
## Élites de la vague (une entrée = une élite).
@export var elites: Array[StringName] = []
## Apparitions par seconde.
@export var spawn_rate: float = 2.0
## Présents en même temps au maximum.
@export var max_alive: int = 60
