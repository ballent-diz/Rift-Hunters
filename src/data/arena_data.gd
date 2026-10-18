class_name ArenaData
extends Resource
## Arène : taille, durée, vagues, événements et boss.

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var size: Vector2 = Vector2(3200, 3200)
## Résolution de navigation adaptée aux grandes cartes ; les collisions du terrain restent précises.
@export_range(16.0,64.0,8.0) var navigation_cell_size: float = 16.0
## Moment d'arrivée du boss (secondes).
@export var boss_time: float = 420.0
@export var boss_id: StringName = &""
## Finale : vider les vagues puis rejoindre un cercle (rayons nuls = boss chronométré classique).
@export var finale_center := Vector2.ZERO
@export var finale_radii := Vector2.ZERO
@export var finale_opening_duration: float = 3.0
## Finale murée : barrières qui apparaissent quand le Chasseur entre dans l'arène (ses collisions et ces barrières
## délimitent le combat ; aucun cercle d'énergie). Vide : finale en cercle (finale_radii).
@export var finale_walls: Array[Rect2] = []
## Message d'appel vers l'arène du boss (une fois les zones ou les failles terminées).
@export var finale_travel_key: String = "FINALE_TRAVEL"
@export_group("Fermeture de failles")
## Mode « fermeture de failles » (si non vide, docs/design/LONGEVITE.md) : une faille (structure à détruire) à chaque
## point ; tant qu'elle est ouverte, des Corrompus en sortent. Toutes refermées : la finale appelle vers l'arène.
@export var rift_points: Array[Vector2] = []
@export var rift_enemy_id: StringName = &"rift_breach"
## Corrompus par seconde et par faille ouverte (× difficulté), dans la limite de la vague en cours (max_alive).
@export var rift_spawn_rate: float = 0.8
## Distance d'apparition autour de la faille.
@export var rift_spawn_radius: float = 240.0
## Une élite sort d'une faille ouverte toutes les N secondes (× difficulté).
@export var rift_elite_interval: float = 40.0
@export_group("")
@export var waves: Array[WavePhaseData] = []
## Mode « vagues par zone » (si non vide) : zones à nettoyer dans l'ordre, puis la finale (boss).
## Les vagues au chrono, les événements et le boss chronométré sont alors désactivés.
@export var zones: Array[LevelZoneData] = []
## Multiplicateur d'XP des Corrompus (mode zones : nombre fini d'ennemis, il faut garder le rythme des niveaux).
@export var xp_mult: float = 1.0
@export var events: Array[RunEventData] = []
@export var elite_first_time: float = 90.0
@export var elite_interval: float = 60.0
## Bestiaire réservé aux apparitions élites ; vide utilise les candidats des vagues.
@export var elite_enemy_ids: Array[StringName] = []
## Décor (entrée « environment.<id> » du manifeste d'assets). Absent : sol de remplacement aux couleurs ci-dessous.
@export var environment_id: StringName = &""
## Multiplicateur du nombre d'éléments de décor (1 = densité prévue par le décor).
@export var decor_density: float = 1.0
@export var ground_color: Color = Color(0.11, 0.12, 0.18)
@export var ground_detail_color: Color = Color(0.16, 0.17, 0.25)
## Arènes hors campagne seulement : les cartes d'un chapitre se débloquent en avançant (Campaign).
@export var unlocked_by_default: bool = true
## Obstacles présents dès le début : {identifiant d'ennemi STATIC: nombre}.
@export var start_obstacles: Dictionary = {}
## Règles propres à l'arène (effets installés au début de la partie).
@export var rule_effects: Array[GameplayEffect] = []
@export var rule_key: String = ""


## L'arène se termine par une finale (cercle ou arène murée) plutôt que par un boss chronométré classique.
func has_finale() -> bool:
	return finale_radii.x > 0 or not finale_walls.is_empty()
