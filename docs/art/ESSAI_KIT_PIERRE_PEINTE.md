# Essai : pierre peinte liée aux formes

Prototype à valider, limité à trois instances de la Cour des Veilleurs : mur nord derrière la terrasse,
escalier central et pilier nord-ouest. Branche `codex/essai-kit-pierre-peinte` ; dépend de la référence
intégrée et de la palette corrigée de la PR #168. Aucun remplacement global avant validation.

## Intention

Les centres de pierre restent calmes. Les joints suivent les assises, les éclats suivent les arêtes,
les marches portent une usure longitudinale et la mousse se concentre au pied. Le reste de la Cour
conserve ses matières actuelles pour rendre la différence visible. La géométrie KayKit, ses placements,
ses collisions et la navigation restent identiques.

Les gabarits ont été générés avec l’outil imagegen intégré, puis conditionnés sans dessin procédural
par `tools/art/condition_painted_kit.py`. Source retenue et métadonnées :
`assets/concepts/incoming/material.painted_kit/`. Les quatre panneaux sont : mur, bandes marche/contremarche,
fût de pilier et face de bloc. Les matériaux et atlas utilisables sont dans `draft3d/matter/painted_kit/`.

## UV, densité et palette

Les UV KayKit de palette ne permettent pas de placer cette usure. Seuls les UV0 des surfaces de pierre
des trois copies visuelles sont remplacés. Les UV source restent en UV2 ; sommets, normales et surfaces
non minérales sont conservés. La bannière du pilier conserve son matériau. Les anciens meshes restent intacts.

Les faces coplanaires reliées sont regroupées ; chaque îlot reçoit son fragment de gabarit et une gouttière
de deux texels. La hauteur globale du module positionne la mousse au pied, sans la répéter sur chaque bloc.
Les bandes d’escalier distinguent dessus et contremarches. Plans reproductibles : `*_uv.json`.

Densité nominale : **40 texels/m**, soit 0,025 m/texel, proche des 0,02404 m/pixel du rendu de référence.
Le calcul prend en compte l’échelle de l’escalier (1 ; 0,5 ; 1,5). Les biseaux minuscules ont au moins
deux texels ; les faces obliques utilisent une projection par axe dominant. Cette méthode convient aux
trois instances retenues ; des tailles différentes nécessitent un autre conditionnement.

Les atlas partagent une quantification de 48 couleurs, sans tramage, en nearest et sans mipmaps.
Le matériau de pierre module l’albédo par (0,64 ; 0,68 ; 0,72), rugosité 1, spéculaire 0.
Une palette expérimentale de rendu conserve les 32 couleurs de la Cour et ajoute 16 gris froids :
elle s’applique uniquement avec l’option d’essai, aux chapitres 1 et 5 qui utilisent actuellement cette Cour.
Ce choix dépasse le budget initial de 32 couleurs et reste à valider ; aucun shader de rendu n’est modifié.

## Voir et comparer

Depuis cette branche dans Godot 4.3, lancer la scène `draft3d/main.tscn` avec les arguments utilisateur :

```text
--chapter=1 --painted-kit
```

Sans `--painted-kit`, l’essai est désactivé. Pour comparer les seules matières avec la même palette,
remplacer cette option par `--painted-kit-palette`.

Captures reproductibles, en remplaçant `<sortie>` par un dossier absolu :

```text
godot --path . --resolution 1600x900 res://tools/art/cour_reference.tscn -- --chapter=1 --bot --passive --god --seed=241115 --pixel=1 --painted-kit-frame --painted-kit --reference-out=<sortie>
```

Pour l’avant, remplacer `--painted-kit` par `--painted-kit-palette` : caméra, lumière, palette de 48 couleurs,
Chasseur et trois Corrompus figés restent identiques. La scène dérive de DraftRun et utilise le rendu pixel
réel (vue 20 m). Les images de `docs/previews/kit_pierre_peinte/` sont des captures, pas des maquettes générées.
Le comparatif recadre les deux captures à l’identique sans agrandissement.

## Reproduire les assets et les contrôles

```text
godot --path . --script res://tools/art/build_painted_kit.gd -- --export=<geometrie.json>
python tools/art/condition_painted_kit.py assets/concepts/incoming/material.painted_kit/source/templates.png <geometrie.json>
godot --headless --editor --import --path .
godot --path . --script res://tools/art/build_painted_kit.gd
godot --path . res://tools/art/check_painted_kit.tscn -- --cour-matter=0 --report=<validation.json>
```

Python nécessite Pillow et NumPy. L’export géométrique et les caches Godot restent hors Git.
Sur cette machine, les nouveaux PNG ont été importés dans un projet minimal utilisant les mêmes chemins
`res://`, puis leurs métadonnées et caches transférés : l’import global rencontre des UID obsolètes
dans des packs KayKit inutilisés. Les captures et contrôles ont ensuite tourné dans le projet complet.

Contrôle natif conforme : 1 613 triangles comparés, positions et UV2 identiques ; écart maximal des normales
de 0,000124 dû à l’encodage des meshes. Exactement trois MeshInstance3D changent, 532 formes de collision,
885 polygones de navigation et tous les placements restent identiques. Sept tests de rendu pixel réussissent.
Lint des six scripts GDScript concernés conforme. Le rapport est conservé avec les aperçus.

## Prompt exact de la source retenue

```text
Create a production pixel-art TEXTURE TEMPLATE ATLAS for three existing 3D game modules, NOT a scene or an illustration of models. Square atlas, exactly 2 columns by 2 rows of equal square panels, edge to edge, no border, no text. Use the attached character ONLY as a reference for deliberate detailed 16-bit pixel-art craftsmanship and color discipline. Environmental palette: desaturated slate grey #3b4148 #4b515b #5d616d #707781, muted olive #33413a #375736 #5f6a47, small earthy stains. Crisp intentional pixels, clustered details; NOT photographic, NOT noisy, NO dithering, NO camouflage-like all-over moss. Flat neutral albedo, no directional lighting, no cast shadows, no fake 3D perspective.
UPPER LEFT: flat front elevation texture of a 4m wide x 4m tall ancient ruin wall. Nine irregular horizontal stone courses, roughly five broad stones per row, subtly recessed thin dark mortar joints, small edge chips, large QUIET readable stone centers. Only the bottom quarter has moss growing upward from the base and in a few joints. Upper stones mostly dry and clean. No long scribbled cracks.
UPPER RIGHT: a flat trim sheet with EXACTLY TEN equal horizontal stone strips stacked vertically inside this panel. Strips extend the entire width. First strip is the TOP of a worn stair tread: calm grey center, a few worn chips along its LOWER horizontal front edge, tiny moss at the two end corners only. Second strip is the FRONT riser: slightly darker, a thin mossy lower seam and earthy corner stains, calm center. Repeat these alternating tread/riser strips five times with tiny variations. These strips are texture bands, not perspective stairs. No projecting forms, no black separator bars beyond the narrow natural stone seams.
LOWER LEFT: flat tall PILLAR SURFACE template, grey-green stone, restrained vertical mineral structure. No carved ornament, no painted object silhouette. A narrow weathered band across the TOP and a broad damp mossy FOOT at the BOTTOM; clean readable central shaft, sparse edge chips. Moss should be concentrated in the bottom fifth, no moss scattered across the entire shaft.
LOWER RIGHT: one flat exposed STONE BLOCK FACE template, a quiet grey center, restrained chips and wear close to the four outer edges, tiny olive lichen at the bottom corners only. No grid, no multiple blocks, no objects. This will be fitted separately to the individual raised stones of the 3D mesh.
Every panel must stay clearly in its assigned quarter. Do not include character art in the output. The templates will be reduced to a native 160-320 texel scale and cropped onto real polygon faces. Prioritize hierarchy and purposeful edge wear over fine surface noise.
```
