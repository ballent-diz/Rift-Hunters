class_name CampaignMapData
extends Resource
## Carte d'un chapitre de campagne : arène jouée, objectifs Normal et Cauchemar, prime de première victoire.

@export var arena_id: StringName = &""
@export var first_victory_shards: int = 150
@export var nightmare_first_victory_shards: int = 250
@export var objectives: Array[MapObjectiveData] = []
@export var nightmare_objectives: Array[MapObjectiveData] = []
