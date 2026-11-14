# Matière des cartes 3D — Cour des Veilleurs

Premier lot du 14 novembre 2026, **à valider visuellement par le propriétaire avant toute déclinaison**.
Les sources KayKit Dungeon Remastered conservent leur licence CC0 et leurs collisions.

## Résultat et périmètre

La Cour reçoit des matières peintes, une palette commune de 32 couleurs et une bibliothèque de 23 petits détails.
Après retour du propriétaire, son sol est entièrement remplacé visuellement par une matière de terre tassée,
pierre plate et mousse : les grands hexagones KayKit disparaissent. Le placement contient désormais 193 instances
de 21 variantes, générées avec la graine `241114` ; les deux fissures en surimpression ne sont plus posées.
L'entrée de l'habillage est dans `draft3d/level_ruins.gd` ; seul ce niveau appelle `cour_dressing.gd`.
Le chapitre 5 utilise actuellement le niveau 1 par défaut dans `DraftLevel.create` : il hérite donc aussi de cette
Cour tant qu'il n'a pas sa propre carte. Aucun autre niveau n'est habillé par ce lot.

Les textures apportent fissures fines, traces d'usure, lichen, veinage du bois et trame des bannières.
Les grandes plages de sol restent calmes pour que le Chasseur et les Corrompus se détachent.
Le nouveau sol continu ne comporte aucune grille de pavés. Les escaliers restent en pierre, avec leur géométrie d'origine.
L'albedo ne contient ni éclairage directionnel ni ombre portée ; le moteur fournit ceux des volumes.
Les torches existantes gardent leur matière et leur lumière.

## Fichiers livrés

| Contenu | Emplacement |
|---|---|
| Atlas des 16 matières, 640 × 640 | `draft3d/matter/cour/materials_atlas.png` |
| Tuiles séparées, 160 × 160 | `draft3d/matter/cour/textures/` |
| Sol terre/pierre/verdure, 640 × 640, répétition de 16 m | `draft3d/matter/cour/terrain.png` |
| Matériaux utilisés, StandardMaterial3D | `draft3d/matter/cour/materials/` |
| Copies visuelles des 11 modules hors sol, 12 maillages | `draft3d/matter/cour/meshes/` |
| Détails, cellules 64 × 64 | `draft3d/matter/cour/details/` |
| Planche contact et liste des variantes | `details_atlas.png`, `details.json` dans le même dossier |
| Palette et références | `draft3d/matter/cour/palette.json` |
| Placement déterministe en mètres | `draft3d/matter/cour/placements.json` |
| Rapport des exceptions UV | `draft3d/matter/cour/uv_report.json` |
| Sources peintes retenues | `assets/concepts/incoming/material.cour_veilleurs/source/` |
| Source commune des détails | `assets/concepts/incoming/planches_communes/cour_details/source/` |
| Jobs individuels | `assets/concepts/incoming/object.cour_*/job.json` |
| Entrées des détails | `assets/asset_manifest.json`, identifiants `object.cour_*` |
| Captures et rapport | `docs/previews/matiere-cour-veilleurs/` |
| Consignes de génération | [MATIERE_COUR_PROMPTS.md](MATIERE_COUR_PROMPTS.md) |

Les 23 variantes couvrent touffes/herbes, fougère, gravats, ardoise, brique, graviers, flaque, humidité,
feuilles sèches et vertes, racines, lierre, deux toiles, crâne, ossements, deux fissures et deux corruptions.
Le lierre sert aux pieds des murs. Une variante comportant un faux morceau de mur a été écartée.
Les détails restent au statut `wip` pendant la validation artistique. Le job de l'atlas est un job spécialisé
`material_atlas`, traité par `build_cour_matter.py` ; les 23 jobs de sprites utilisent le contrat habituel.

## Densité de texels et palette

Le Chasseur utilise actuellement `0,037 × 0,65 = 0,02405 m` par pixel d'art dans `DraftSpriteView`.
Une tuile de matière de 160 texels couvre 4 m, soit **0,025 m par texel**, un écart de 3,95 %.
La caméra de référence est celle du jeu : projection orthographique, taille 20, décalage `(0, 18, 17)`.
À 1600 × 900, un texel de matière correspond à environ 1,125 pixel écran vertical ; un pixel du Chasseur à 1,082.
Sur les faces inclinées, la projection raccourcit naturellement les texels. Aucun filtre plein écran n'est ajouté.
Les cellules des petits détails suivent le manifeste : 64 px, `scale: 0.5`, ancre `[32, 60]`, soit 0,0185 m/pixel.
Cette échelle plus fine des petits accessoires est explicite ; elle ne change pas celle des personnages.

Les 32 couleurs de `palette.json` sont des pixels opaques réellement présents dans les feuilles du Chasseur,
Mossback, Thornweave, Stormshell, Golem calciné, Chevalier de cendre et Skitterling.
Rampes dominantes : ardoise `#3b4148 #5d5a60 #7b7c82`, pierre froide `#76838a #7c7c80`,
bois `#553a36 #65544f #8d725f`, végétation `#273728 #33413a #375736 #5f6a47`,
Faille `#382735 #4a384a #704964 #864c78 #c661b6`.
La pierre utilise un sous-ensemble peu contrasté pour éviter le scintillement de points clairs isolés.
La palette limite les **images**, pas les couleurs calculées ensuite par la lumière du moteur.

Textures importées sans mipmaps, compression sans perte ; matériaux `TEXTURE_FILTER_NEAREST`, répétition activée.
La mise en raccord ne travaille que les huit texels de marge avant quantification, sans tramage.
Les bords opposés de chaque tuile sont ensuite vérifiés identiques au texel près.

## UV KayKit : exception nécessaire et réversible

Les UV0 originaux échantillonnent de petits aplats/dégradés dans la palette KayKit. Par exemple le sol a seulement
47 coordonnées UV distinctes pour 311 sommets, dans une petite portion de l'image. Y poser des détails à densité
uniforme écrase les motifs. Ces UV sont conservés pour identifier les matières de chaque triangle.

Les onze modules hors sol nécessitent donc des UV de matière dédiés : `wall`, `wall_cracked`,
`wall_broken`, `stairs_wide`, `pillar_decorated`, `wall_doorway`, `barrier`, `banner_red`, `crates_stacked`,
`barrel_large`, `chest`. Les copies `.res` utilisent une projection planaire selon la normale dominante,
avec 4 m par répétition. Les **UV0 originaux sont conservés dans UV2**. Les scènes KayKit ne sont pas réécrites.
Les sommets et triangles restent identiques ; le classement par matière change le nombre de surfaces.
Le coffre garde ses deux maillages distincts, corps et couvercle.

### Remplacement intégral du sol après retour du propriétaire

Une texture seule aurait conservé les joints hexagonaux, présents dans le relief KayKit. L'habillage masque
donc les MeshInstance3D des modules `floor_tile_large` et construit un maillage visuel commun : deux triangles
par emprise de 4 × 4 m, à l'altitude exacte du sommet d'origine. Les terrasses sont traitées de la même façon.
Les modules et leurs corps physiques sont conservés, avec les mêmes positions et collisions.
Seule cette géométrie **visuelle** de sol est volontairement remplacée ; il serait faux de la dire identique.

Le terrain est peint dans une image de 640 × 640 couvrant 16 m, soit la même densité de 0,025 m/texel.
Ses UV sont calculés dans le repère du niveau, avec une phase commune entre les anciens modules :
le motif ne recommence pas tous les quatre mètres. Un matériau standard partagé couvre l'ensemble.
La source retenue est `assets/concepts/incoming/material.cour_veilleurs/source/terrain.png`.
Les traits fins des deux détails `crack_thin` et `crack_branch` ne sont plus superposés au sol.

L'échelle uniforme de chaque module est compensée dans `uv1_scale` du matériau ; celle des escaliers
`(1, 0.5, 1.5)` est prise en compte dans les UV préparés. Une autre carte avec d'autres proportions d'escalier
devra préparer sa propre variante visuelle. Les deux fondations BoxMesh reçoivent uniquement des UV et une matière.
Le `shadow_mesh` simplifié KayKit à une seule surface ne peut pas être réutilisé avec plusieurs matières :
les copies projettent leurs ombres à partir du maillage complet, de même forme.

## Placement et réversibilité

### Herbe en volume

Après retour du propriétaire, les trois variantes d'herbe sont remplacées à leurs emplacements par de véritables
MeshInstance3D. `grass_mesh.gd` produit trois maillages partagés, déterministes : sept petits bouquets de treize
brins courbés, à section triangulaire, hauts de 20 à 48 cm. Les quatre couleurs viennent de la palette commune.
Les normales et le matériau standard permettent l'éclairage et les ombres du moteur, sans nouveau shader.
Ces touffes ne suivent pas la caméra ; elles restent sans collision. La mousse basse reste dans le terrain peint.
Les autres détails gardent leur rendu en sprites. Le rendu combiné de Claude reste à valider séparément.

Les sprites sont des Sprite3D en alpha découpé, nearest, sans corps physique et sans effet de gameplay.
Les herbes sont des maillages 3D ; la fougère et le lierre restent des billboards,
les traces des quads au sol et les toiles des quads sur les murs.
La position JSON désigne l'ancre ; l'habillage compense le décalage de la cellule jusque sur un quad tourné.
Les variantes et les placements sont éditables séparément. Les axes de circulation principaux restent dégagés.

Pour comparer à l'original, lancer avec `--cour-matter=0` après le séparateur `--`.
Ce drapeau évite à la fois les matières et les détails. Les modules source restent disponibles sans conversion.
Le code n'ajoute aucun corps ni collision, ne déplace aucun module et ne modifie aucune règle de navigation.
Le maillage commun du terrain est purement visuel ; la physique reste celle des modules KayKit.

## Compatibilité avec le rendu pixel de Claude

Contrat consulté sur `claude/rendu-pixel-3d`, commit `cbd38afe`, sans fusion de ses fichiers.
Les matériaux restent des StandardMaterial3D ordinaires avec `albedo_texture`, `uv1_scale`, répétition et nearest.
Son convertisseur toon reprend ces propriétés. Les détails transparents/unshaded restent exclus de cette conversion.
Les textures sans mipmaps empêchent une chaîne de niveaux flous même si le sampler du rendu accepte des mipmaps.

Les captures de ce lot montrent **la matière seule sous le rendu standard de main**, avec les lumières originales.
L'association finale avec son rendu basse résolution, ses contours et sa palette reste à vérifier en jeu après
rapprochement des deux branches. Aucune modification de shader, de brume ou d'éclairage n'est incluse ici.

## Ambiance proposée — valeurs à essayer après validation de la matière

| Paramètre | Proposition |
|---|---|
| Fond / vide | `#141827` |
| Brume | `#323b4c`, densité de départ `0.008`, hauteur `0.25 m`, densité en hauteur `0.10` |
| Ambiante | `#a1abbc`, énergie `0.35` |
| Soleil haut-gauche | `#dfceb4`, énergie `0.75`, conserver la direction actuelle |
| Contre-jour discret | `#655176`, énergie `0.12` |
| Torches | `#d9a16a`, énergie `1.1`, portée `4.5 m` |

Ce sont des valeurs de proposition, pas des changements de code. La brume doit rester légère pour préserver les
petits détails, et le violet réservé aux accents de Faille pour ne pas masquer les ennemis magenta.

## Reproduction et contrôles

Depuis la racine, avec Python, Pillow, NumPy et Godot 4.3 disponibles :

```powershell
python tools/art/build_cour_matter.py assets/concepts/incoming/material.cour_veilleurs/source/atlas_matieres.png assets/concepts/incoming/planches_communes/cour_details/source/planche.png assets/concepts/incoming/material.cour_veilleurs/source/pierres_neutres.png
python tools/art/build_cour_ground.py assets/concepts/incoming/material.cour_veilleurs/source/terrain.png
python tools/art/place_cour_details.py
godot --headless --editor --import --path .
godot --path . --script res://tools/art/build_cour_meshes.gd
python tools/art/check_cour_images.py
godot --path . res://tools/art/check_cour_matter.tscn -- --cour-matter=0 --report=<rapport.json>
godot --path . --resolution 1600x900 res://tools/art/cour_preview.tscn -- --cour-matter=0 --out=<avant>
godot --path . --resolution 1600x900 res://tools/art/cour_preview.tscn -- --out=<apres>
```

Les deux dernières commandes figent les mêmes acteurs aux mêmes poses sur terrasse, escaliers, abris et entrepôts.
Elles utilisent le Chasseur et deux Corrompus réels. Le banc ne change aucun sprite du jeu.
Le contrôle des maillages et de la navigation est effectué avec le rendu natif, pas le pilote headless dummy.

Résultat détaillé dans `docs/previews/matiere-cour-veilleurs/controle_geometrie.json` : les 11 modules hors sol
sont comparés à leurs sources ; **551 poses de modules, 532 collisions et 885 polygones de navigation inchangés**.
Pour le sol remplacé visuellement, le contrôle porte sur la totalité des emprises, leur altitude et la phase UV.
Les textures passent le contrôle de palette et de raccord, les 23 sprites celui d'ancre/alpha/manifeste.
Le fichier de placement se régénère octet pour octet.

Le nombre d'appels de dessin est relevé dans le README des captures : mesure de complexité visuelle,
**pas un benchmark de FPS**. Le sol continu est partagé ; les autres surfaces par matière et les détails ont un coût.
La validation du propriétaire doit donc porter aussi sur la fluidité avec une horde, et sur le rendu combiné.

## Habiller une nouvelle carte après accord

1. Relever ses modules et leurs échelles, et photographier les cadrages de référence avec les acteurs.
2. Prélever sa palette commune sur les sprites et les références du chapitre ; produire ses albedos neutres.
3. Garder les UV existants s'ils portent une texture à densité stable ; sinon préparer des copies visuelles,
   conserver les UV source dans UV2 et ajouter l'exception au rapport.
4. Préparer ses détails en cellules ancrées et écrire son propre fichier de placement déterministe.
5. Brancher l'habillage uniquement dans son niveau, sans changer les modules physiques.
6. Comparer triangles, poses, collisions et navigation ; vérifier palette, raccords, lisibilité et coût en jeu.
7. Faire valider les captures avant d'étendre ce traitement à un autre chapitre.
