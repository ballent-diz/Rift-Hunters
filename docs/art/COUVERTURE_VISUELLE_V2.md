# Couverture visuelle v2 — livraison locale du 17 novembre 2026

Périmètre : les 15 sorts jouables de la v2, 12 combos, trois effets de passifs et cinq illustrations de récompenses.
Les sorts et mutations conservent leurs icônes existantes comme prévu par les
[fiches de référence](../design/FICHES_VFX_GAMEPLAY_V2.md). Ce lot ne change aucune règle de gameplay.

## État de livraison et limite d’intégration

- Les 12 FX de combos sont présents : PNG RGBA transparents, JSON PixelFX, animations WebP, rapports techniques et captures OpenGL.
- Les trois premiers FX, absents du dépôt malgré les annonces de l’ancienne conversation, ont été recréés.
- Les 12 illustrations de combos sont référencées par `ItemArt.texture("combo", id_runtime)`.
  Le lot ne crée pas de nouvelle interface d’encyclopédie ou de récompense pour ces combos automatiques.
- Les cinq cartes de récompense sont référencées par `ItemArt.texture("upgrade", id)` ; leurs fonds sombres en vignette
  sont intentionnellement opaques, conformément aux fiches. Leur PNG est RGBA, 1254 × 1254 px.
- Les trois combos initiaux et les passifs utilisent le raccord de présentation de la PR #208, déjà fusionnée dans main.
- Les neuf nouveaux déclencheurs appartiennent à la [PR #212](https://github.com/ballent-diz/Rift-Hunters/pull/212),
  encore ouverte lors du contrôle. Aucun de ses changements de gameplay n’a été repris ou fusionné ici.
  [COMBOS_LOT6_VFX.patch](COMBOS_LOT6_VFX.patch) prépare leurs seuls appels de rendu,
  contrôlé par `git apply --check` sur la révision `f8b1925d9a17ad413690703d330fa55a277df236`.
  À appliquer après l’arrivée du lot 6 ; il conserve les dégâts, conditions, états, plafonds et recharges.
  La Prison ajoute un seul anneau par puits ; les effets d’entrave individuels restent présents.
- Livraison locale et publication GitHub sont deux étapes distinctes : ce rapport ne certifie pas une fusion distante.

## Fichiers de chaque combo

Les PNG et JSON sont sous `assets/vfx/pixelfx/<asset_id>/violet.*` ; les illustrations sous
`assets/ui/items/combos/<asset_id>.png`. Les dimensions et cadences des neuf nouveaux effets sont une calibration
graphique proposée ; elles ne remplacent aucune valeur de dégâts ou de portée du gameplay.

| ID utilisé par le jeu | PNG / JSON | Image associée | Aperçu animé | Déclencheur |
|---|---|---|---|---|
| `prismatic_execution` | [combo_prismatic_execution](../../assets/vfx/pixelfx/combo_prismatic_execution/violet.png) · [JSON](../../assets/vfx/pixelfx/combo_prismatic_execution/violet.json) | [illustration](../../assets/ui/items/combos/combo_prismatic_execution.png) | [animation](../previews/couverture-vfx/combo_prismatic_execution.webp) | raccordé dans main |
| `prismatic_deluge` | [combo_prismatic_deluge](../../assets/vfx/pixelfx/combo_prismatic_deluge/violet.png) · [JSON](../../assets/vfx/pixelfx/combo_prismatic_deluge/violet.json) | [illustration](../../assets/ui/items/combos/combo_prismatic_deluge.png) | [animation](../previews/couverture-vfx/combo_prismatic_deluge.webp) | raccordé dans main |
| `gravity_blade` | [combo_gravity_blade](../../assets/vfx/pixelfx/combo_gravity_blade/violet.png) · [JSON](../../assets/vfx/pixelfx/combo_gravity_blade/violet.json) | [illustration](../../assets/ui/items/combos/combo_gravity_blade.png) | [animation](../previews/couverture-vfx/combo_gravity_blade.webp) | raccordé dans main |
| `rift_counter` | [combo_counter_rift](../../assets/vfx/pixelfx/combo_counter_rift/violet.png) · [JSON](../../assets/vfx/pixelfx/combo_counter_rift/violet.json) | [illustration](../../assets/ui/items/combos/combo_counter_rift.png) | [animation](../previews/combos_lot_a/combo_counter_rift.webp) | raccord préparé pour la PR #212 |
| `dimensional_hunt` | [combo_dimensional_hunt](../../assets/vfx/pixelfx/combo_dimensional_hunt/violet.png) · [JSON](../../assets/vfx/pixelfx/combo_dimensional_hunt/violet.json) | [illustration](../../assets/ui/items/combos/combo_dimensional_hunt.png) | [animation](../previews/combos_lot_a/combo_dimensional_hunt.webp) | raccord préparé pour la PR #212 |
| `tracker_rupture` | [combo_tracker_rupture](../../assets/vfx/pixelfx/combo_tracker_rupture/violet.png) · [JSON](../../assets/vfx/pixelfx/combo_tracker_rupture/violet.json) | [illustration](../../assets/ui/items/combos/combo_tracker_rupture.png) | [animation](../previews/combos_lot_a/combo_tracker_rupture.webp) | raccord préparé pour la PR #212 |
| `spectral_rebound` | [combo_spectral_rebound](../../assets/vfx/pixelfx/combo_spectral_rebound/violet.png) · [JSON](../../assets/vfx/pixelfx/combo_spectral_rebound/violet.json) | [illustration](../../assets/ui/items/combos/combo_spectral_rebound.png) | [animation](../previews/combos_lot_b/combo_spectral_rebound.webp) | raccord préparé pour la PR #212 |
| `shattering_rampart` | [combo_shattering_bastion](../../assets/vfx/pixelfx/combo_shattering_bastion/violet.png) · [JSON](../../assets/vfx/pixelfx/combo_shattering_bastion/violet.json) | [illustration](../../assets/ui/items/combos/combo_shattering_bastion.png) | [animation](../previews/combos_lot_b/combo_shattering_bastion.webp) | raccord préparé pour la PR #212 |
| `vengeful_aegis` | [combo_avenging_aegis](../../assets/vfx/pixelfx/combo_avenging_aegis/violet.png) · [JSON](../../assets/vfx/pixelfx/combo_avenging_aegis/violet.json) | [illustration](../../assets/ui/items/combos/combo_avenging_aegis.png) | [animation](../previews/combos_lot_b/combo_avenging_aegis.webp) | raccord préparé pour la PR #212 |
| `still_storm` | [combo_still_storm](../../assets/vfx/pixelfx/combo_still_storm/violet.png) · [JSON](../../assets/vfx/pixelfx/combo_still_storm/violet.json) | [illustration](../../assets/ui/items/combos/combo_still_storm.png) | [animation](../previews/combos_lot_c/combo_still_storm.webp) | raccord préparé pour la PR #212 |
| `rift_prison` | [combo_rift_prison](../../assets/vfx/pixelfx/combo_rift_prison/violet.png) · [JSON](../../assets/vfx/pixelfx/combo_rift_prison/violet.json) | [illustration](../../assets/ui/items/combos/combo_rift_prison.png) | [animation](../previews/combos_lot_c/combo_rift_prison.webp) | raccord préparé pour la PR #212 |
| `prismatic_convergence` | [combo_prismatic_convergence](../../assets/vfx/pixelfx/combo_prismatic_convergence/violet.png) · [JSON](../../assets/vfx/pixelfx/combo_prismatic_convergence/violet.json) | [illustration](../../assets/ui/items/combos/combo_prismatic_convergence.png) | [animation](../previews/combos_lot_c/combo_prismatic_convergence.webp) | raccord préparé pour la PR #212 |

Attention aux trois correspondances : `rift_counter` → `combo_counter_rift`, `shattering_rampart` →
`combo_shattering_bastion`, `vengeful_aegis` → `combo_avenging_aegis`. Ne pas renommer les mécaniques.

## Sorts existants vérifiés

Les neuf sorts historiques utilisent leurs scènes de VFX Hunter et leurs sprites d’icônes. Les six sorts ajoutés
utilisent les feuilles PixelFX existantes ; `DraftSpellBar.icon_for` extrait leur image centrale via `AtlasTexture`.
Cette livraison ne prétend pas avoir redessiné ces 15 icônes, ni les anciens sorts d’Échos hors du périmètre v2.

| Sort | Image chargée | Provenance |
|---|---|---|
| `cleaving_slash` | `res://assets/sprites/skills/hunter/hunter_cleaving_slash_sheet.png` | illustration et scène existantes |
| `prismatic_lance` | `res://assets/sprites/skills/hunter/hunter_prismatic_lance_sheet.png` | illustration et scène existantes |
| `rupture` | `res://assets/sprites/skills/hunter/hunter_rupture_sheet.png` | illustration et scène existantes |
| `rift_leap` | `res://assets/sprites/skills/hunter/hunter_rift_leap_sheet.png` | illustration et scène existantes |
| `parry` | `res://assets/sprites/skills/hunter/hunter_parry_sheet.png` | illustration et scène existantes |
| `singularity` | `res://assets/sprites/skills/hunter/hunter_singularity_sheet.png` | illustration et scène existantes |
| `rift_wall` | `res://assets/sprites/skills/hunter/hunter_rift_wall_sheet.png` | illustration et scène existantes |
| `aegis` | `res://assets/sprites/skills/hunter/hunter_rift_aegis_sheet.png` | illustration et scène existantes |
| `refracting_crystal` | `res://assets/sprites/skills/hunter/hunter_refractor_crystal_sheet.png` | illustration et scène existantes |
| `hunter_mark` | `res://assets/vfx/pixelfx/hex_sigil/fallen.png#image_du_milieu` | FX existant, icône AtlasTexture existante de DraftSpellBar |
| `void_rend` | `res://assets/vfx/pixelfx/heavy_cleave/violet.png#image_du_milieu` | FX existant, icône AtlasTexture existante de DraftSpellBar |
| `rift_step` | `res://assets/vfx/pixelfx/blink_in/violet.png#image_du_milieu` | FX existant, icône AtlasTexture existante de DraftSpellBar |
| `stasis_wave` | `res://assets/vfx/pixelfx/frost_nova/givres.png#image_du_milieu` | FX existant, icône AtlasTexture existante de DraftSpellBar |
| `shard_rain` | `res://assets/vfx/pixelfx/star_fall/violet.png#image_du_milieu` | FX existant, icône AtlasTexture existante de DraftSpellBar |
| `ash_veil` | `res://assets/vfx/pixelfx/smoke_bomb/calcines.png#image_du_milieu` | FX existant, icône AtlasTexture existante de DraftSpellBar |

## Passifs et cartes

- `passive_dash_blade` : 6 images à 24 fps, 96 px ; `passive_void_wake` : 8 images à 8 fps, 128 px en boucle ;
  `passive_counter_cut` : 10 images à 22 fps, 144 px. Chaque dossier contient `violet.png` et `violet.json`.
- Cartes : `passive_dash_blade`, `passive_void_wake`, `passive_counter_cut`, `passive_anchor`, `rule_extra_slot`
  dans `assets/ui/items/upgrades/`. L’Ancre réutilise la Singularité, sans nouvel effet de gameplay.
- [Aperçus et contrôles des passifs/cartes](../previews/passifs_cartes_v2/index.html).

## Contrôles et utilisation

`tools/art/check_v2_vfx.py` valide les six effets/cinq cartes prévus par la fiche originale.
`tools/art/audit_v2_visual_coverage.py` valide la couverture des 15 sorts, 12 combos et cinq cartes et produit
[coverage.json](../previews/couverture-vfx/coverage.json). Les rapports par lot vérifient RGBA, transparence,
palette, cellules, ordre, bordure intérieure et taux d’occupation. Les neuf nouveaux FX restent à juger en vraie
partie après raccord de la PR #212 ; aucune mesure d’occultation en combat n’est prétendue ici.

L’[index de contrôle](../previews/couverture-vfx/index.html) ouvre chaque animation et son illustration.
`tools/art/preview_v2_delivery.gd` instancie les 15 effets sur une mire neutre avec la caméra 2,5D et le vrai
renderer OpenGL ; ses captures sont dans `docs/previews/couverture-vfx/rendu/`. Ce ne sont pas des captures
de déclenchement des combos dans une partie. Le fond quadrillé appartient à la mire, pas aux PNG livrés.

Les aperçus WebP animés sont exclus de l’import Godot par `.gdignore` : seuls les assets PNG entrent dans le jeu.
Les sources retenues, prompts et `job.json` sont sous `assets/concepts/incoming/`, également ignorés par Godot.
Génération : ImageGen intégré ; conditionnement mécanique Pillow (découpage, NEAREST et palette de 32 couleurs
pour les FX, conversion RGBA pour les illustrations). Les sources intermédiaires rejetées restent hors dépôt.

Les résultats moteur et la taille exacte du lot sont consignés dans
[verification.json](../previews/couverture-vfx/verification.json) et
[delivery_manifest.json](../previews/couverture-vfx/delivery_manifest.json).
