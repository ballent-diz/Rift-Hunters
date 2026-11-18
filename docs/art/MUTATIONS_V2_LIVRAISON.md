# Mutations V2 — livraison graphique du 18 novembre 2026

Huit nouveaux effets conformément aux [fiches de Claude](../design/FICHES_VFX_MUTATIONS_V2.md),
avec PNG RGBA transparents, JSON PixelFX et WebP animés. Aucun script de gameplay ni valeur de combat modifié.
Les raccords sont déjà présents sur la base main `0dac247` : déposer les ressources les active.

## Effets créés

Chaque ID désigne `assets/vfx/pixelfx/<id>/violet.png` et `violet.json`.

| Mutation | ID exact | Cellule | Images / FPS | Boucle | Animation |
|---|---|---|---|---|---|
| Fente perçante | `mutation_rend_pierce` | 104 × 104 | 6 / 24 | non | [aperçu](../previews/mutations_v2/mutation_rend_pierce.webp) |
| Éclats de stase | `mutation_stasis_shards` | 80 × 80 | 8 / 16 | non | [aperçu](../previews/mutations_v2/mutation_stasis_shards.webp) |
| Concentration | `mutation_rain_focus` | 104 × 104 | 8 / 24 | non | [aperçu](../previews/mutations_v2/mutation_rain_focus.webp) |
| Traque | `mutation_mark_hunt` | 104 × 104 | 8 / 20 | non | [aperçu](../previews/mutations_v2/mutation_mark_hunt.webp) |
| Contrecoup | `mutation_veil_recoil` | 80 × 80 | 8 / 20 | non | [aperçu](../previews/mutations_v2/mutation_veil_recoil.webp) |
| Exécution | `mutation_mark_execute` | 140 × 140 | 12 / 24 | non | [aperçu](../previews/mutations_v2/mutation_mark_execute.webp) |
| Ombre piégée | `mutation_step_trap` | 176 × 176 | 12 / 20 | non | [aperçu](../previews/mutations_v2/mutation_step_trap.webp) |
| Orage | `mutation_rain_storm` | 384 × 384 | 8 / 10 | oui | [aperçu](../previews/mutations_v2/mutation_rain_storm.webp) |

## Réutilisations et non-production volontaire

| Mutation | Ressources conservées | Justification validée par Claude |
|---|---|---|
| Double fente | Fente de base : `blink_out`, `heavy_cleave`, `hit` ; impact dédié si Perçante est également équipée | Même geste répété ; fenêtre gratuite déjà indiquée par la barre. |
| Deux charges | `blink_out` et `blink_in`, plus l’ombre habituelle du Pas | Le nombre de charges est affiché par la barre ; aucun nouveau geste. |
| Onde circulaire | `frost_nova/givres` centré sur le Chasseur | Nova circulaire existante, portée adaptée par le code actuel. |
| Voile mobile | `smoke_bomb/calcines` | Le nuage suit déjà le Chasseur. |

Concentration, Traque, Exécution et Ombre piégée reçoivent bien leurs effets dédiés, contrairement aux hypothèses
du pré-audit établi avant réception des fiches. Les effets génériques restent utilisés pour les cas sans mutation.
Les scènes des neuf sorts historiques `assets/vfx/hunter/` ne sont pas remplacées ; leurs doubles mutations sont
traitées par le correctif existant de Claude ([audit](../design/DOUBLES_MUTATIONS_VFX.md)).

## Contrôles et retouches

- Lots A : Fente perçante et Éclats de stase ; B : Concentration, Traque et Contrecoup ; C : Exécution,
  Ombre piégée et Orage. Chaque export a été contrôlé avant poursuite.
- Huit rapports vérifient dimensions, cadence, ordre des cellules, alpha, 32 couleurs au plus et bordure interne
  transparente de2px. Occupation opaque et blancs lumineux limités pour préserver la lisibilité.
- Effets au sol : contrôle du centre translucide (alpha maximal127 dans la zone centrale testée), ouverture
  inspectée visuellement ; boucle d’Orage comparée entre images consécutives et au raccord8→1.
- Retouches ImageGen retenues : cadrage de Concentration, fin de Traque, ellipse et dissipation d’Ombre piégée,
  recalage de son ancrage, projection de l’ellipse d’Orage. Les essais rejetés restent hors dépôt.
- [Index des aperçus et fichiers](../previews/mutations_v2/index.html),
  [rapports d’export](../previews/mutations_v2/validation.json). Les captures moteur utilisent une mire2,5D ;
  elles vérifient le chargement et le rendu, pas une mesure d’occultation dans une foule en vraie partie.

Génération : ImageGen intégré, sans CLI/API externe. Sources retenues, prompts et `job.json` dans
`assets/concepts/incoming/mutations_v2/` (`.gdignore`). Conditionnement mécanique : cellules régulières,
réduction NEAREST, marge transparente interne et quantification RGBA32 sans tramage. Les aperçus animés sont
également ignorés par Godot ; seuls les PNG exploitables sont importés.

PR graphique dédiée, sans fusion automatique.

Contrôles moteur : import Godot4.3 réussi, tests de raccord4/4, lint réussi, huit captures OpenGL sans erreur. [Rapport moteur](../previews/mutations_v2/verification_moteur.json).
