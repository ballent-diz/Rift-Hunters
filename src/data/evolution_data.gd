class_name EvolutionData
extends Resource
## Évolution (ou variante de maîtrise) d'un Écho : change rôle, attaque ou comportement.

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var required_rank: int = 3
## Évolution secrète : masquée tant qu'elle n'a pas été découverte.
@export var secret: bool = false
@export var hint_key: String = ""
@export var requires_monsters: Array[StringName] = []
@export var requires_relics: Array[StringName] = []
## Remplacements (laisser vide / null pour conserver la valeur de base).
@export var behavior_id: StringName = &""
@export var attack: AttackData
@export var technique: TechniqueData
@export var damage_mult: float = 1.0
@export var attack_speed_mult: float = 1.0
@export var range_mult: float = 1.0
@export var added_affinities: Array[StringName] = []
@export var effects: Array[GameplayEffect] = []
@export var visual: VisualData
