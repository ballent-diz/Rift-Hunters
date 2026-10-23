class_name EnemyTechniqueData
extends Resource
## Technique d'un Corrompu (élites et quelques normaux, docs/design/MONSTRES.md). kind correspond à une méthode
## d'EnemyManager (_technique_<kind>) ; anim : rangée de la feuille jouée au déclenchement.

@export var kind: StringName = &""
@export var anim: StringName = &""
@export var cooldown: float = 8.0
## Portée : le Chasseur doit être entre min_range et max_range (pas de répétition au contact).
@export var min_range: float = 0.0
@export var max_range: float = 260.0
@export var telegraph: float = 0.9
@export var damage: float = 12.0
@export var params: Dictionary = {}
