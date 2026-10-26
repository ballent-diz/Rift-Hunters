class_name EnemyData
extends Resource
## Définition d'un Corrompu.

enum Brain { CHASER, RANGED, CHARGER, STATIC, SUMMONER, BLINKER, WARDEN }

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var brain: Brain = Brain.CHASER
@export var max_hp: float = 10.0
## Dégâts de contact.
@export var damage: float = 5.0
@export var defense: float = 0.0
@export var move_speed: float = 80.0
@export var radius: float = 12.0
@export var xp_value: int = 1
@export_range(0.0, 1.0) var knockback_resist: float = 0.0
@export var can_be_elite: bool = true
## Structure (cerveau STATIC) : immobile mais ciblée et attaquée comme un Corrompu (faille à refermer).
## Sans cela, un STATIC est un simple obstacle ignoré par les attaques automatiques.
@export var structure: bool = false
## Bulbe de braise (brique B5, PodDirector) : un coup allié l'amorce au lieu de le blesser.
@export var pod: bool = false
## Attaque spéciale (projectile du Cracheur, charge du Bondisseur).
@export var attack: AttackData
@export var visual: VisualData
## Techniques propres (élites : docs/design/MONSTRES.md), en plus du cerveau.
@export var techniques: Array[EnemyTechniqueData] = []
## Volant (chapitre 3) : survole le décor (rochers, eau, vase), mais pas les barrières de zone.
@export var flying: bool = false
## Furtif : invisible et impossible à viser au-delà de cette distance du Chasseur (0 = toujours visible).
@export var stealth_range: float = 0.0
