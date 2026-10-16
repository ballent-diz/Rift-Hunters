class_name RunSetup
extends RefCounted
## Paramètres de lancement d'une partie (choisis au Refuge).

var arena_id: StringName = &"fractured_plain"
var difficulty_id: StringName = &"tension_0"
var starter_id: StringName = &"mossback"
var starter_variant: bool = false
var run_seed: int = 0
## Bot de test : joue seul (smoke tests).
var autopilot: bool = false
## Effets permanents à installer (arbre, maîtrise...), fournis par Profile.
var meta_effects: Array[GameplayEffect] = []
## Effets installés quand un Écho donné rejoint l'équipe : {monster_id: Array[GameplayEffect]}.
var monster_meta_effects: Dictionary = {}
## Rang de départ de l'Écho initial.
var starter_rank: int = 1
## Couleurs alternatives (maîtrise) : {monster_id: [primary, secondary]}.
var palettes: Dictionary = {}
## Contenu débloqué disponible pendant la partie.
var unlocked_monsters: Array[StringName] = []
var unlocked_relics: Array[StringName] = []
var unlocked_upgrades: Array[StringName] = []
## Informations débloquées au Laboratoire (ex. « affixes » : noms des affixes visibles).
var info_unlocks: Array[String] = []
## Modificateurs de partie choisis (Pactes de risque).
var modifier_ids: Array[StringName] = []
## Sorts du Chasseur équipés, dans l'ordre des touches (vide : ceux de l'équilibrage).
var spell_ids: Array[StringName] = []
## Variantes actives des sorts : {spell_id: variant_kind} (arbre du Chasseur v2).
var spell_variants: Dictionary = {}
## Conseils de première partie affichés dans le HUD.
var show_tutorial: bool = false
