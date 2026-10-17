class_name DifficultyData
extends Resource
## Difficulté : Normal (niveau 0) ou Cauchemar (niveau 1, débloqué en finissant la campagne). Ajoute des règles,
## pas seulement des PV (docs/design/LONGEVITE.md).

@export var id: StringName = &""
@export var level: int = 0
@export var name_key: String = ""
@export var desc_key: String = ""
@export var enemy_hp_mult: float = 1.0
@export var enemy_damage_mult: float = 1.0
@export var enemy_speed_mult: float = 1.0
@export var spawn_rate_mult: float = 1.0
@export var elite_interval_mult: float = 1.0
@export var elite_affix_count: int = 1
## Seuil de phase 2 du boss (−1 = valeur du boss).
@export var boss_phase2_threshold: float = -1.0
@export var reward_mult: float = 1.0
@export var unlocked_by_default: bool = false
