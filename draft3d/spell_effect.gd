class_name DraftSpellEffect
extends GameplayEffect
## Effet d'une carte de sort de la base 3D (docs/design/SORTS_ACTIFS_V2.md), appliqué par `DraftSpells.apply_effect`.
## Les cartes de sort ne s'offrent que si elles servent (`DraftSpells.can_apply`) :
## - LEARN : apprendre le sort `spell_id` (sort inconnu, emplacement libre) ;
## - VARIANT : variante du sort (une seule par sort, groupe exclusif de la carte), réglée par `params` ;
## - MODIFY : rang d'amélioration, `pct` ajouté à la statistique `stat` du sort (damage, cooldown, area, reach).

## - PASSIVE : passif technique `passive` (draft3d/passives.gd), une fois par expédition ;
## - RULE : altération des règles `rule` (ex. extra_slot : 5e emplacement), une fois par expédition.

enum Kind { LEARN, VARIANT, MODIFY, PASSIVE, RULE }

@export var kind: Kind = Kind.LEARN
@export var spell_id: StringName = &""
## VARIANT : variante reprise de la v1 (whirlwind, thrust, fan, overcharge, reaction, blaze, return, impact).
@export var variant: StringName = &""
## VARIANT : réglages de la variante (portée, nombre, durée, part des dégâts…). Aucune valeur en dur dans le code.
@export var params: Dictionary = {}
## VARIANT : mutations du même sort avec lesquelles celle-ci ne peut pas coexister (Tourbillon ⟂ Estoc…).
@export var incompatible: Array[StringName] = []
## PASSIVE / RULE : identifiant du passif ou de la règle.
@export var passive: StringName = &""
@export var rule: StringName = &""
## MODIFY : statistique du sort et part ajoutée par rang (+0,2 = +20 % ; −0,15 sur la recharge = −15 %).
@export var stat: StringName = &""
@export var pct: float = 0.0
