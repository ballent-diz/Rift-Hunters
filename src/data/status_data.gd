class_name StatusData
extends Resource
## Statut de combat (Fracture, Marque, Brûlure, Entrave...).

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var duration: float = 3.0
@export var max_stacks: int = 1
## Défense ajoutée tant que le statut est actif (négatif = réduction).
@export var defense_add: float = 0.0
## Multiplicateur de dégâts subis tant que le statut est actif.
@export var damage_taken_mult: float = 1.0
## Multiplicateur de vitesse de déplacement.
@export var speed_mult: float = 1.0
## Dégâts par seconde et par cumul (dégâts sur la durée).
@export var dps_per_stack: float = 0.0
## Peut être détoné (Marques).
@export var detonatable: bool = false
## Les Dévoreurs (boss) y sont insensibles (ex. Racines).
@export var bosses_immune: bool = false
@export var color: Color = Color.WHITE
