class_name SkillNodeData
extends Resource
## Nœud de l'arbre du Chasseur v2 (docs/design/ARBRE_DU_CHASSEUR.md). Apprendre un rang coûte des Éclats (une fois,
## pour toujours) ; l'activer dans un build coûte des Points de Chasseur. Les nœuds UTILITY (améliorations du refuge)
## sont toujours actifs une fois appris. Les effets sont installés une fois par rang actif en début de partie.

enum Kind { UTILITY, PASSIVE, SPELL, VARIANT, TRANSFORM, KEYSTONE }

@export var id: StringName = &""
@export var branch: StringName = &""
## Niveau dans la voie, à partir de 0 (niveau I).
@export var tier: int = 0
@export var kind: Kind = Kind.UTILITY
@export var name_key: String = ""
@export var desc_key: String = ""
## Coût en Éclats pour apprendre chaque rang (taille = rang maximum).
@export var costs: Array[int] = [50]
## Points de Chasseur par rang actif dans un build (0 pour les améliorations du refuge).
@export var point_cost: int = 1
## Nœuds requis pour apprendre (au moins un rang appris).
@export var prerequisites: Array[StringName] = []
## true : un seul prérequis suffit. false : tous sont requis.
@export var prerequisites_any: bool = false
## Un seul nœud actif par groupe exclusif dans un build (variantes A/B, clés de voûte, styles).
@export var exclusive_group: StringName = &""
## SPELL : sort débloqué (data/spells). VARIANT : sort modifié.
@export var spell_id: StringName = &""
## VARIANT : variante appliquée au sort (voir HunterSpells).
@export var variant_kind: StringName = &""
## Palier de campagne provisoire : victoires contre un boss nécessaires pour apprendre.
@export var required_wins: int = 0
## Connu dès le départ (sorts de départ).
@export var learned_by_default: bool = false
## false : nœud prévu mais pas encore réalisé (affiché « à venir », ni apprenable ni activable).
@export var implemented: bool = true
@export var effects: Array[GameplayEffect] = []
## Fonctionnalité dont dépend ce contenu (BalanceConfig.disabled_features) : masqué quand elle est mise de côté.
@export var feature: StringName = &""


func max_rank() -> int:
	return costs.size()


func is_utility() -> bool:
	return kind == Kind.UTILITY
