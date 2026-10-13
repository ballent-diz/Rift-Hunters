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
## Attaque spéciale (projectile du Cracheur, charge du Bondisseur).
@export var attack: AttackData
@export var visual: VisualData
