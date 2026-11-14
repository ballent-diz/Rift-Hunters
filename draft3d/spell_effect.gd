class_name DraftSpellEffect
extends GameplayEffect
## Effet d'une carte de sort de la base 3D (docs/design/SORTS_ACTIFS_V2.md), appliqué par `DraftSpells.apply_effect`.
## LEARN : apprendre le sort `spell_id` (emplacement libre). Les cartes de sort ne s'offrent que si elles servent :
## sort inconnu et place libre pour LEARN, sort connu pour les autres.

enum Kind { LEARN }

@export var kind: Kind = Kind.LEARN
@export var spell_id: StringName = &""
