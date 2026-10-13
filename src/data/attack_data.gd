class_name AttackData
extends Resource
## Paramètres d'une attaque automatique. Le comportement qui les utilise est choisi ailleurs.

@export var name_key: String = ""
@export var damage: float = 10.0
@export var cooldown: float = 1.0
## Portée d'acquisition de cible.
@export var attack_range: float = 220.0
## Rayon de zone (0 = mono-cible).
@export var radius: float = 0.0
@export var projectile_speed: float = 420.0
@export var projectile_count: int = 1
@export var pierce: int = 0
## Cibles supplémentaires (rebonds / frappes en chaîne).
@export var chain: int = 0
## Nombre d'éclats créés à l'impact.
@export var split: int = 0
## Vitesse de rotation en rad/s pour les projectiles à tête chercheuse (0 = ligne droite).
@export var homing: float = 0.0
@export var knockback: float = 0.0
@export var statuses: Array[StatusApplication] = []
## Paramètres propres au comportement (documentés dans le comportement).
@export var params: Dictionary = {}
