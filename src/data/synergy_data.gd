class_name SynergyData
extends Resource
## Synergie d'équipe : active quand tous les Échos requis sont présents.

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var required_monsters: Array[StringName] = []
## Affinités requises : {&"ember": 2} = au moins deux Échos d'affinité braise.
@export var required_affinities: Dictionary = {}
@export var effects: Array[GameplayEffect] = []
@export var color: Color = Color(1.0, 0.9, 0.5)
