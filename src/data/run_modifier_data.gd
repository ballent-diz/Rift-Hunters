class_name RunModifierData
extends Resource
## Modificateur de partie à risque (« Pacte de risque ») : plus difficile, mieux récompensé.

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var enemy_hp_mult: float = 1.0
@export var enemy_damage_mult: float = 1.0
@export var enemy_speed_mult: float = 1.0
@export var spawn_rate_mult: float = 1.0
@export var elite_interval_mult: float = 1.0
@export var extra_elite_affixes: int = 0
## Effets appliqués au Chasseur (ex. PV réduits, soins réduits).
@export var player_effects: Array[GameplayEffect] = []
## Bonus de récompenses (+0.2 = +20 %).
@export var reward_bonus: float = 0.2
## Difficulté minimale pour pouvoir le choisir (1 = Cauchemar : les pactes font partie du Pacte).
@export var min_difficulty: int = 1
