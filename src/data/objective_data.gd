class_name ObjectiveData
extends Resource
## Objectif (mission, succès, défi de build, collection) avec condition et récompense explicites.

enum Category { MISSION, ACHIEVEMENT, BUILD_CHALLENGE, COLLECTION, SECRET }
## RUN : la valeur d'une partie doit atteindre le seuil. LIFETIME : cumul sur toutes les parties.
enum Scope { RUN, LIFETIME }

@export var id: StringName = &""
@export var category: Category = Category.MISSION
@export var name_key: String = ""
@export var desc_key: String = ""
@export var stat_key: StringName = &""
@export var threshold: float = 1.0
@export var scope: Scope = Scope.RUN
@export var requires_victory: bool = false
@export var min_difficulty: int = 0
## Taille d'équipe maximale autorisée pendant la partie (−1 = libre).
@export var max_team_size: int = -1
@export var hidden: bool = false
@export_group("Récompense")
@export var reward_shards: int = 0
@export var reward_essence: int = 0
## Déblocages « type:id » : monster:lucivelle, relic:ember_heart, difficulty:tension_1, title:...
@export var reward_unlocks: Array[String] = []
