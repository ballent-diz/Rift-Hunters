class_name MapObjectiveData
extends Resource
## Objectif d'une carte de campagne (« étoile ») : toujours évalué sur une victoire, dans une difficulté donnée.

## AT_LEAST : le compteur doit atteindre le seuil. AT_MOST : il ne doit pas le dépasser (dégâts subis, durée…).
enum Compare { AT_LEAST, AT_MOST }

## Unique au sein de la carte et de la difficulté (clear, untouched, swift…).
@export var id: StringName = &""
## Texte de l'objectif ; « %d » est remplacé par le seuil (en minutes:secondes si duration est vrai).
@export var desc_key: String = ""
@export var stat_key: StringName = &"victories"
@export var threshold: float = 1.0
@export var compare: Compare = Compare.AT_LEAST
## Le seuil est une durée en secondes (affichée en m:ss).
@export var duration: bool = false
@export var reward_shards: int = 0
