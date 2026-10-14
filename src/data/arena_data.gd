class_name ArenaData
extends Resource
## Arène : taille, durée, vagues, événements et boss.

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var size: Vector2 = Vector2(3200, 3200)
## Moment d'arrivée du boss (secondes).
@export var boss_time: float = 420.0
@export var boss_id: StringName = &""
## Finale : vider les vagues puis rejoindre un cercle (rayons nuls = boss chronométré classique).
@export var finale_center := Vector2.ZERO
@export var finale_radii := Vector2.ZERO
@export var finale_opening_duration: float = 3.0
@export var waves: Array[WavePhaseData] = []
@export var events: Array[RunEventData] = []
@export var elite_first_time: float = 90.0
@export var elite_interval: float = 60.0
## Décor (entrée « environment.<id> » du manifeste d'assets). Absent : sol de remplacement aux couleurs ci-dessous.
@export var environment_id: StringName = &""
## Multiplicateur du nombre d'éléments de décor (1 = densité prévue par le décor).
@export var decor_density: float = 1.0
@export var ground_color: Color = Color(0.11, 0.12, 0.18)
@export var ground_detail_color: Color = Color(0.16, 0.17, 0.25)
@export var unlocked_by_default: bool = true
## Obstacles présents dès le début : {identifiant d'ennemi STATIC: nombre}.
@export var start_obstacles: Dictionary = {}
## Règles propres à l'arène (effets installés au début de la partie).
@export var rule_effects: Array[GameplayEffect] = []
@export var rule_key: String = ""
