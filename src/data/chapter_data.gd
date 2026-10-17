class_name ChapterData
extends Resource
## Chapitre de campagne (docs/design/CAMPAGNE.md) : cartes dans l'ordre, la dernière se termine par le Dévoreur.

@export var id: StringName = &""
## Rang dans la campagne (1 = premier chapitre).
@export var order: int = 1
@export var name_key: String = ""
@export var desc_key: String = ""
## Couleur d'ambiance (titres et cartes du refuge).
@export var color: Color = Color(0.55, 0.75, 0.95)
@export var maps: Array[CampaignMapData] = []
