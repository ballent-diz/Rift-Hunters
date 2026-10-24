class_name BalanceConfig
extends Resource
## Paramètres d'équilibrage centralisés. Instance unique : data/balance/balance_config.tres.

@export_group("Chasseur")
@export var player_max_hp: float = 100.0
@export var player_move_speed: float = 150.0
@export var player_radius: float = 15.0
@export var player_regen: float = 0.0
@export var hurt_iframes: float = 0.5
@export var dash_distance: float = 140.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 3.0
@export var dash_iframes: float = 0.3
@export var pickup_radius: float = 70.0
@export var magnet_speed: float = 520.0
## Soins lâchés par les ennemis : chance par ennemi tué, triplée sous un seuil de PV (filet de sécurité),
## soin rendu en part des PV max, soin garanti sur les élites.
@export var heal_drop_chance: float = 0.006
@export var heal_low_hp_ratio: float = 0.35
@export var heal_low_hp_mult: float = 3.0
@export var heal_amount_ratio: float = 0.15
@export var elite_heal_drop: bool = true
@export var player_visual: VisualData
@export_group("Arme du Chasseur")
@export var bolt: AttackData
## Sorts du Chasseur équipés par défaut (touches A, E, R, F), tant que le build (lot C2) ne les choisit pas.
@export var default_spells: Array[StringName] = [&"cleaving_slash", &"prismatic_lance"]
@export_group("Équipe")
@export var base_team_slots: int = 2
@export var max_team_slots: int = 3
@export var ally_rank_max: int = 5
## Bonus de dégâts par rang au-delà du premier.
@export var ally_rank_damage_bonus: float = 0.2
@export var ally_follow_distance: float = 70.0
## Écho bloqué par le décor (avance < 30 % de sa vitesse) pendant ce temps → saut de faille près du Chasseur.
@export var ally_stuck_time: float = 0.8
## Au-delà de cette distance du Chasseur, l'Écho le rejoint aussi par un saut de faille.
@export var ally_leash_distance: float = 560.0
@export var focus_duration: float = 5.0
@export var focus_radius: float = 220.0
@export_group("Niveaux")
@export var xp_base: float = 4.0
@export var xp_exponent: float = 1.3
@export var upgrade_choices: int = 3
## Les montées de niveau ne mettent pas le jeu en pause : leurs choix sont mis en réserve et s'ouvrent aux temps
## forts (coffre, zone nettoyée, faille refermée, arrivée du boss) ou à la demande. Quand la réserve atteint ce
## nombre, elle s'ouvre en entier d'elle-même.
@export var level_reserve_cap: int = 5
## Jalons de campagne (ArenaData.progression = « milestones ») : chaque jalon soigne et donne des dégâts acquis
## jusqu'à la fin de la partie, en plus du choix (ils remplacent les petites caractéristiques des niveaux).
@export var milestone_heal_ratio: float = 0.3
@export var milestone_damage_pct: float = 0.06
@export_group("Ennemis")
## Croissance des PV ennemis par minute (+0.12 = +12 %/min).
@export var enemy_hp_growth_per_min: float = 0.12
@export var enemy_damage_growth_per_min: float = 0.04
@export var elite_hp_mult: float = 7.0
@export var elite_size_mult: float = 1.5
@export var elite_xp_mult: float = 8.0
@export var spawn_distance_min: float = 520.0
@export var spawn_distance_max: float = 700.0
@export var max_enemies_hard_cap: int = 450
@export var contact_damage_interval: float = 0.4
@export_group("Dévoreurs")
## Nombre maximal d'ennemis pendant un combat de boss (vagues, invocations et Nuées-mères comprises).
@export var boss_fight_enemy_cap: int = 90
## Après ce délai de combat, le Dévoreur s'enrage (garantit une issue).
@export var boss_enrage_time: float = 180.0
@export var boss_enrage_damage_mult: float = 1.6
@export var boss_enrage_speed_mult: float = 1.4
@export_group("Fonctionnalités")
## Fonctionnalités mises de côté (décision du propriétaire, 24 octobre 2026) : &"relics", &"chests", &"evolutions".
## Le contenu reste en données ; retirer l'identifiant de la liste le remet en jeu.
@export var disabled_features: Array[StringName] = [&"relics", &"chests", &"evolutions"]
@export_group("Récompenses")
@export var shards_per_minute: float = 8.0
@export var shards_per_elite: float = 6.0
@export var shards_per_kill: float = 0.1
@export var essence_per_elite: int = 1
@export var chest_break_shards: int = 20
@export var chest_break_heal_ratio: float = 0.3
@export var relic_choices: int = 3
## Récompenses dégressives d'une carte de campagne déjà gagnée : ×decay par victoire dans la difficulté, plancher floor.
@export var map_repeat_decay: float = 0.8
@export var map_repeat_floor: float = 0.4
@export_group("Capture (Rite de lien)")
## Chance qu'une élite laisse un Écho errant.
@export var capture_chance: float = 0.3
## Poids relatif des Échos encore verrouillés (les capturer les débloque).
@export var capture_locked_weight: float = 0.6
@export var capture_time: float = 2.5
@export var capture_radius: float = 46.0
@export var capture_lifetime: float = 25.0
@export_group("Lisibilité")
## Zoom de la caméra (> 1 = plus proche).
@export var camera_zoom: float = 1.3333
@export var max_damage_numbers: int = 60


func xp_to_next(level: int) -> int:
	return int(ceil(xp_base * pow(float(level), xp_exponent))) + 1


func feature_enabled(id: StringName) -> bool:
	return id == &"" or not disabled_features.has(id)
