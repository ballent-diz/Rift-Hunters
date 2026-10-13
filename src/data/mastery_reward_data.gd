class_name MasteryRewardData
extends Resource
## Récompense d'un palier de maîtrise.

enum Kind { STAT_BONUS, PALETTE, VARIANT, START_RANK, TITLE }

@export var level: int = 1
@export var kind: Kind = Kind.STAT_BONUS
@export var name_key: String = ""
@export var desc_key: String = ""
## STAT_BONUS : effets installés quand l'Écho est dans l'équipe.
@export var effects: Array[GameplayEffect] = []
## PALETTE : couleur principale alternative.
@export var palette_primary: Color = Color.WHITE
@export var palette_secondary: Color = Color.WHITE
## START_RANK : rang de départ quand l'Écho est choisi au départ.
@export var start_rank: int = 2
