class_name UpgradeData
extends Resource
## Carte d'amélioration statique (stats, mutations). Les cartes Pacte/Éveil/Évolution sont dynamiques.

enum Kind { STAT, MUTATION }

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var kind: Kind = Kind.STAT
@export var weight: float = 1.0
@export var max_stacks: int = 5
## Une seule carte d'un même groupe exclusif peut être prise par partie.
@export var exclusive_group: StringName = &""
## L'équipe doit contenir au moins un de ces Échos (vide = aucune condition).
@export var requires_any_monster: Array[StringName] = []
@export var unlocked_by_default: bool = true
@export var effects: Array[GameplayEffect] = []
@export var color: Color = Color(0.5, 0.8, 1.0)
