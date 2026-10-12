class_name StatusApplication
extends Resource
## Application d'un statut par une attaque ou une technique.

@export var status_id: StringName = &""
@export var stacks: int = 1
@export_range(0.0, 1.0) var chance: float = 1.0
