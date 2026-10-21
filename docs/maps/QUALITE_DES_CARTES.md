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
- PR #39 : une « recomposition à l'échelle » à 1536 pixels n'a presque rien changé (objets de même taille,
  mesuré). Ce n'est pas la composition qui fixe l'échelle des objets, c'est la passe de régions (§ 2).

## 2. La recette des cartes de référence

Les Ruines et les Hautes Terres ont été faites ainsi (job.json de `map.three_rifts` et `map.storm_highlands`) :

1. **Composition** de toute la carte, validée par le propriétaire : c'est le **plan figé**.
2. **Régions** : la composition est découpée en carrés d'environ **1672 × 1672 unités** ; chacun est redessiné par le
   générateur avec du vrai détail, à **0,75 pixel par unité** au moins (1254 pixels pour 1672 unités).
3. **Assemblage** des régions (recouvrements fondus), retouche des raccords si besoin. `map_regions.py assemble`
   calibre la **netteté native** de chaque région : les régions des Ruines et des Hautes Terres ont 379 à 395 petits
   détails pour 10 000 pixels ; une région plus douce (le générateur de Codex sort souvent ≈ 290) reçoit le plus petit
   renforcement de netteté (rayon 1 pixel, ≤ 120 %) qui l'y amène. Constaté sur les cartes 3 et 4 (21 octobre) : même
   détail moyen que les références, seul le pixel était moins net ; après calibrage, les deux cartes sont conformes.
4. **Présentation** : agrandissement ×3 jusqu'à **2,25 pixels par unité** (densité affichée en jeu), en tuiles
   verticales de 1672 unités de large (3762 pixels).

**L'échelle des objets est fixée par les régions (étape 2 ci-dessus), pas par la composition.** Le générateur dessine un arbre, une pierre ou un pavé à
peu près toujours à la même taille en pixels. Redessinée à 1,3 unité par pixel, une région reçoit donc des objets à la
taille des Ruines, quelle que soit la grossièreté de la composition. Preuve ([planche](../previews/echelle-hautes-terres.png) : carte finale, composition, Ruines, à 1 pixel par
unité) : la composition des Hautes Terres faisait
4 unités par pixel (pavés d'environ 45 unités) ; leur carte finale a des pavés d'environ 20 unités, comme les Ruines.
Condition : le prompt de région doit autoriser à remplacer un objet trop gros par plusieurs objets plus petits sur
la même emprise (c'est le cas de `PROMPT_REGION.txt`). La composition, elle, ne fixe que le plan.

Le nombre de régions ne dépend que de la surface. `map_regions.py` ajoute 160 unités de recouvrement de chaque côté et
garde cœur + marges dans 1672 unités : une sortie de générateur de 1254 pixels (le maximum courant) donne ainsi au
moins 0,75 pixel par unité, comme les régions des Hautes Terres (faites sans recouvrement, d'où leur nombre plus bas) :

| Carte (unités) | Régions | Tuiles livrées |
|---|---|---|
| 5016 × 1672 (3:1, Ruines) | 4 × 2 = 8 | 3 × (3762 × 3762) |
| 5016 × 3344 (3:2) | 4 × 3 = 12 | 3 × (3762 × 7524) |
| 5016 × 5016 (1:1, Hautes Terres) | 4 × 4 = 16 | 3 × (3762 × 11286) |
| Autre taille W × H | ⌈W / 1352⌉ × ⌈H / 1352⌉ | ⌈W / 1672⌉ tuiles de (2,25 W / n) × 2,25 H |

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
**Échelle des objets** (arbres, rochers, blocs, pavés) : aucune mesure automatique fiable n'a été trouvée (les
comptages de formes à 8 à 32 unités ne séparent pas les Ruines des plans trop gros). Elle se contrôle donc sur la
planche `python3 tools/art/map_regions.py compare` : extraits de 560 × 420 unités au même zoom (carte livrée,
composition, Ruines), **obligatoire dans la PR**. Repères à 1 pixel par unité : pavé 15 à 25, bloc de falaise 20 à 30,
sapin 100 à 140 de haut. Au zoom du jeu, le Chasseur fait environ 60 pixels de haut à l'écran.

## 4. Le parcours, étape par étape

| Étape | Qui | Commande / livrable | Contrôle |
|---|---|---|---|
| 1. Composition (1536 px de large) | générateur | prompt de composition (GENERER_UNE_CARTE.md § 4), joindre les cartes du chapitre | plan validé par le propriétaire (circulation, zones, passages) |
| 2. Collisions | propriétaire | peinture sur la composition validée | DE_L_IMAGE_AU_NIVEAU.md |
| 3. Découpage | Codex | `python3 tools/art/map_regions.py split composition.png --world WxH --out <dossier>` | — |
| 4. Régions | générateur | une génération par `regions/rY_X_input.png`, prompt `PROMPT_REGION.txt`, joindre `reference_scale.png` ; enregistrer `regions/rY_X.png` | chaque sortie ≥ 1254 pixels de côté |
| 5. Assemblage | Codex | `python3 tools/art/map_regions.py assemble <dossier> --out assets/environments/<id>/map` | — |
| 6. Contrôle | Codex | `python3 tools/art/check_map_quality.py --images <tuiles> --world WxH --composition composition.png --json qualite.json` | **conforme**, sinon refaire les régions des secteurs signalés |
| 7. Échelle | Codex | `python3 tools/art/map_regions.py compare --images <tuiles> --world WxH --composition composition.png --out echelle.png` | planche jointe à la PR : objets à la taille des Ruines (le propriétaire juge) |
| 8. Intégration | Claude | manifeste (`status: final`), collisions, mini-carte, niveau | `tools/run_tests.sh` (étape `map_quality`) |

Une carte « final » utilisée par une arène qui ne passe pas le contrôle fait échouer `tools/run_tests.sh`.
`map_regions.py scale-reference` (extrait des Ruines à l'échelle d'une composition) reste disponible pour illustrer
l'échelle, mais n'est pas une étape : la composition ne fixe pas la taille finale des objets.

## 5. Prompts

**Composition** (étape 1) : le prompt type de [GENERER_UNE_CARTE.md](GENERER_UNE_CARTE.md) (§ 4). Il fixe le plan
(chemins, largeurs, clairières, passages) ; inutile d'y chercher la taille finale des objets.

**Région** (étape 4) : `PROMPT_REGION.txt`, écrit par `map_regions.py split`. Il impose : plan figé (contours,
largeurs, emprises des massifs et des repères, rien sur le sol praticable), détail neuf (pas d'agrandissement), et
**l'échelle de la référence jointe** : un objet trop gros est remplacé par plusieurs objets à la bonne taille sur la
même emprise (arbre géant → bosquet, rocher géant → éboulis, grande dalle → pavés). Bords inchangés pour les
recouvrements.

**Raccord** (si une couture reste visible) : prompts « vertical » et « horizontal » de
`assets/concepts/incoming/map.storm_highlands/job.json` (« LOCAL SEAM REPAIR ONLY »), sur un recadrage étroit du
raccord, puis réinsertion et nouveau contrôle.

## 6. Interdits

- Livrer comme carte finale un **agrandissement** (Real-ESRGAN ou autre) d'une image qui n'a pas reçu sa passe de
  régions : l'agrandissement ×3 de l'étape de présentation n'est permis qu'après les régions.
- **Recomposer** une carte après validation du plan (le contrôle de fidélité le détecte).
- Modifier `collision.png` ou la peinture du propriétaire pour faire coïncider une image qui a dérivé.
- Déclarer une carte terminée sans le rapport `check_map_quality.py` **conforme**, joint à la fiche de livraison.
