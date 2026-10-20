# Qualité des cartes : la même pour toutes, ni plus ni moins

Règle du propriétaire (20 octobre 2026) : **chaque carte a exactement la qualité des Ruines des Cascades et des
Hautes Terres d'Orage**, quelle que soit sa taille. La qualité se définit donc **par unité du monde** : une grande
carte a plus de pixels, une petite en a moins, mais chaque unité a la même densité et le même détail.

Ce document fait foi pour Codex, ChatGPT et Claude. Le plan et les dimensions sont dans
[GENERER_UNE_CARTE.md](GENERER_UNE_CARTE.md), les collisions dans [DE_L_IMAGE_AU_NIVEAU.md](DE_L_IMAGE_AU_NIVEAU.md).

## 1. Ce qui a raté (cartes 3 et 4) et pourquoi

- La composition (1536 px pour 5016 unités, soit 0,3 pixel par unité) a été **agrandie ×4** au lieu d'être
  redessinée par régions : image floue, aplats, pavés grands comme un Écho.
- Pour la carte 3, une passe par régions a **recomposé** le plan validé : un passage est devenu inaccessible.
- La doc ne donnait que des minimums de disposition et un contrôle « à l'œil » de la netteté.

## 2. La recette des cartes de référence

Les Ruines et les Hautes Terres ont été faites ainsi (job.json de `map.three_rifts` et `map.storm_highlands`) :

1. **Composition** de toute la carte, validée par le propriétaire : c'est le **plan figé**.
2. **Régions** : la composition est découpée en carrés d'environ **1672 × 1672 unités** ; chacun est redessiné par le
   générateur avec du vrai détail, à **0,75 pixel par unité** au moins (1254 pixels pour 1672 unités).
3. **Assemblage** des régions (recouvrements fondus), retouche des raccords si besoin.
4. **Présentation** : agrandissement ×3 jusqu'à **2,25 pixels par unité** (densité affichée en jeu), en tuiles
   verticales de 1672 unités de large (3762 pixels).

Le nombre de régions ne dépend que de la surface :

| Carte (unités) | Régions | Tuiles livrées |
|---|---|---|
| 5016 × 1672 (3:1, Ruines) | 3 | 3 × (3762 × 3762) |
| 5016 × 3344 (3:2) | 6 | 3 × (3762 × 7524) |
| 5016 × 5016 (1:1, Hautes Terres) | 9 | 3 × (3762 × 11286) |
| Autre taille W × H | ⌈W / 1672⌉ × ⌈H / 1672⌉ | ⌈W / 1672⌉ tuiles de (2,25 W / n) × 2,25 H |

## 3. Les chiffres qui définissent la qualité

Mesurés par `tools/art/check_map_quality.py` au zoom du jeu, par secteurs de 800 × 800 unités ; référence calibrée
sur les Ruines et les Hautes Terres (`tools/art/map_quality_reference.json`, 63 secteurs).

| Mesure | Référence (médiane) | Accepté |
|---|---|---|
| Densité de l'image livrée | 2,25 pixels par unité | 2,18 à 2,32 |
| Part lisse (pixels sans texture) | 0,19 | ≤ 0,27 (un agrandissement : 0,5 à 0,6) |
| Détails fins (≈ 1 unité) par 100 × 100 unités | 388 | 330 à 446 (agrandissement : ≈ 200) |
| Détails moyens (≈ 2 unités : pavés, touffes) par 100 × 100 unités | 107 | 91 à 123 (agrandissement : ≈ 60) |
| Secteurs conformes | 96 à 100 % | ≥ 85 % (finesse homogène, pas un seul secteur soigné) |
| Fidélité au plan validé (corrélation des formes) | 1,00 | ≥ 0,85 (une recomposition : 0,6) |

Trop peu de détails = flou ou détail trop gros ; trop = détail trop fin (bruit, objets miniatures).
**Échelle des objets** : elle se juge avec les extraits des Ruines au même zoom que fournit
`tools/art/map_regions.py` (arbres, rochers, ponts, pavés à la même taille à l'écran). Repères au zoom du jeu :
le Chasseur fait environ 60 pixels de haut à l'écran, un pavé 25 à 40, un arbre isolé 130 à 200.

## 4. Le parcours, étape par étape

| Étape | Qui | Commande / livrable | Contrôle |
|---|---|---|---|
| 1. Référence d'échelle | Codex ou propriétaire | `python3 tools/art/map_regions.py scale-reference --world WxH --out ref.png` | — |
| 2. Composition (1536 px de large) | générateur | prompt de composition (§ 5), joindre `ref.png` et les cartes du chapitre | plan validé par le propriétaire ; échelle des objets égale à `ref.png` |
| 3. Collisions | propriétaire | peinture sur la composition validée | DE_L_IMAGE_AU_NIVEAU.md |
| 4. Découpage | Codex | `python3 tools/art/map_regions.py split composition.png --world WxH --out <dossier>` | — |
| 5. Régions | générateur | une génération par `regions/rY_X_input.png`, prompt `PROMPT_REGION.txt`, joindre `reference_scale.png` ; enregistrer `regions/rY_X.png` | chaque sortie ≥ 1494 pixels de côté |
| 6. Assemblage | Codex | `python3 tools/art/map_regions.py assemble <dossier> --out assets/environments/<id>/map` | — |
| 7. Contrôle | Codex | `python3 tools/art/check_map_quality.py --images <tuiles> --world WxH --composition composition.png --json qualite.json` | **conforme**, sinon refaire les régions des secteurs signalés |
| 8. Intégration | Claude | manifeste (`status: final`), collisions, mini-carte, niveau | `tools/run_tests.sh` (étape `map_quality`) |

Une carte « final » utilisée par une arène qui ne passe pas le contrôle fait échouer `tools/run_tests.sh`.

## 5. Prompts

**Composition** (étape 2) : le prompt type de [GENERER_UNE_CARTE.md](GENERER_UNE_CARTE.md) (§ 4), en ajoutant :

```
Image2 is a SCALE reference: an extract of the Waterfall Ruins map at EXACTLY the same scale as the map you draw
(same number of world units per pixel). Every tree, rock, ruin, bridge, stair, road and clearing must have the same
size relative to the image as in image2. Do not draw oversized trees, giant paving stones or huge rocks.
```

**Région** (étape 5) : `PROMPT_REGION.txt`, écrit par `map_regions.py split`. Il impose : plan figé (rien d'ajouté,
retiré ou déplacé, mêmes largeurs de chemins), détail neuf (pas d'agrandissement), même taille à l'écran que la
référence jointe, bords inchangés pour les recouvrements.

**Raccord** (si une couture reste visible) : prompts « vertical » et « horizontal » de
`assets/concepts/incoming/map.storm_highlands/job.json` (« LOCAL SEAM REPAIR ONLY »), sur un recadrage étroit du
raccord, puis réinsertion et nouveau contrôle.

## 6. Interdits

- Livrer comme carte finale un **agrandissement** (Real-ESRGAN ou autre) d'une image qui n'a pas reçu sa passe de
  régions : l'agrandissement ×3 de l'étape de présentation n'est permis qu'après les régions.
- **Recomposer** une carte après validation du plan (le contrôle de fidélité le détecte).
- Modifier `collision.png` ou la peinture du propriétaire pour faire coïncider une image qui a dérivé.
- Déclarer une carte terminée sans le rapport `check_map_quality.py` **conforme**, joint à la fiche de livraison.
