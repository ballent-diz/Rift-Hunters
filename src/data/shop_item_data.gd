class_name ShopItemData
extends Resource
## Objet de la boutique du refuge (docs/design/MODES.md, lot M3), payé en éclats.
## - « consumable » : en stock, emporté à l'expédition suivante (une unité par expédition), dans les deux modes ;
## - « survival » : acquis une fois pour toutes, actif seulement dans les épreuves de survie (montées de niveau) ;
## - « look » : apparence (plus tard).
## Les Échos en vente viennent de MonsterData (discovery = « shop »).

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var kind: StringName = &"consumable"
@export var price: int = 100
## En vente après une victoire sur cette carte (vide : dès le départ).
@export var requires_arena: StringName = &""
## Effets installés au début de la partie.
@export var effects: Array[GameplayEffect] = []
## Consommable réservé aux épreuves de survie : pas emporté (ni consommé) sur une carte de campagne.
@export var survival_only: bool = false
## Niveaux gagnés au départ (mode survie) : autant de choix immédiats.
@export var start_levels: int = 0
@export var color: Color = Color(1.0, 0.8, 0.4)
@export var order: int = 0
