class_name DraftTuning
extends Resource
## Réglages propres au premier jet (draft3d/tuning.tres). Les valeurs de base (PV, vitesses, dégâts, EXP par ennemi,
## courbe de niveaux) viennent toujours de l'équilibrage commun ; ce fichier ne porte que les écarts nécessaires au
## Chasseur seul, que la campagne compensait par l'équipe d'Échos.

@export_group("Chasseur")
## Bonus de départ : sans Échos, le Trait de Faille doit suffire à tenir les premières vagues.
@export var hunter_damage_pct: float = 0.5
@export var hunter_attack_speed_pct: float = 0.25
@export_group("Ennemis")
@export var enemy_damage_scale: float = 0.8
@export var enemy_hp_growth_per_min: float = 0.1
@export var swarm_every: float = 60.0
@export var swarm_size: int = 10
@export_group("Boss")
## Gardien de mi-parcours : un des gardiens du chapitre, affaibli ; le vaincre lâche une grosse réserve d'EXP.
@export var guardian_time: float = 240.0
@export var guardian_hp_mult: float = 0.45
@export var guardian_xp: int = 40
@export var boss_time: float = 480.0
@export var boss_hp_mult: float = 0.55
@export var boss_damage_mult: float = 0.8
@export_group("Vagues")
## Début (s), apparitions par seconde, plafond d'ennemis en vie. Le mélange vient du bestiaire du chapitre
## (DraftRoster.mix) : chaque palier ouvre de nouveaux monstres.
@export var waves: Array[Dictionary] = [
	{"at": 0.0, "rate": 0.9, "cap": 22},
	{"at": 45.0, "rate": 1.3, "cap": 36},
	{"at": 120.0, "rate": 1.8, "cap": 55},
	{"at": 210.0, "rate": 2.4, "cap": 75},
	{"at": 300.0, "rate": 3.0, "cap": 100},
	{"at": 390.0, "rate": 3.6, "cap": 125},
]
@export var boss_wave: Dictionary = {"rate": 0.9, "cap": 28}
