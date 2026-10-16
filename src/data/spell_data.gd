class_name SpellData
extends Resource
## Sort du Chasseur, visé au curseur et lancé par une touche (A, E, R, F par défaut).
## Conception : docs/design/ARBRE_DU_CHASSEUR.md.

enum Family { OFFENSIVE, DEFENSIVE, TECHNICAL }

@export var id: StringName = &""
## Identifiant de la stratégie de code (voir src/entities/player/hunter_spells.gd).
@export var spell_kind: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var family: Family = Family.OFFENSIVE
## Voie de l'arbre (blade, prism, abyss, bond) : clés de voûte et passifs qui réagissent à une voie.
@export var path: StringName = &""
@export var cooldown: float = 5.0
@export var damage: float = 30.0
## Portée maximale depuis le Chasseur (unités du monde).
@export var spell_range: float = 150.0
## Largeur de la zone touchée : demi-angle en degrés (arc) ou rayon (projectile, zone).
@export var width: float = 60.0
@export var knockback: float = 0.0
## Vitesse du projectile (sorts qui en lancent un).
@export var speed: float = 0.0
@export var statuses: Array[StatusApplication] = []
@export var color: Color = Color(0.7, 0.95, 1.0)
@export var params: Dictionary = {}
