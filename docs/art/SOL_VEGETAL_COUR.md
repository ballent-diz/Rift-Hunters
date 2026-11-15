# Sol végétal — suite du kit peint

**Validé comme référence le 15 novembre 2026**, actif par défaut sur la Cour. Retour à l’ancien ensemble avec
`--painted-kit=0` ; voir `REFERENCE_DECORS_3D.md`. Les paragraphes d’activation optionnelle ci-dessous sont historiques.

Essai à valider dans la Cour, branche `codex/essai-kit-pierre-peinte`, PR #169.
Il complète le mur, l’escalier et le pilier du [kit peint](ESSAI_KIT_PIERRE_PEINTE.md).
Le propriétaire demande de rester cohérent avec les sprites et le décor ; ses deux références servent
à la forme des touffes et aux petites dalles envahies, pas à reprendre leur saturation ni leur rendu vectoriel.

## Choix retenus

- Herbe basse et mousse en masses connectées, centres calmes, détails aux transitions.
- Petits groupes de dalles froides espacés. Les premières pierres, trop grandes et trop répétitives en jeu,
  ont été reprises. Leurs couleurs ont ensuite été calibrées dans le véritable éclairage et rendu pixel.
- Suppression du tapis de **3 450 groupes de petits brins 3D**, qui doublait le dessin du sol.
- Conservation des **40 touffes 3D** ponctuelles, aux positions déterministes existantes : trois petits bouquets
  de sept brins plus larges, hauts de 0,16 à 0,27 m, contre sept bouquets de treize brins auparavant.
- Retrait des surimpressions de gravats, ardoises, briques, gravier, feuilles et taches humides qui doublaient
  la nouvelle matière. Racines, fougères, lierre, flaques, toiles, os et accents de corruption restent en place.

Cette passe concernait uniquement le sol. Depuis l’extension suivante, les murs et escaliers de la Cour
utilisent tous la pierre du kit ; voir `ESSAI_KIT_PIERRE_PEINTE.md`. Les captures de cette page conservent
l’état antérieur à cette extension pour comparer le sol seul.
Aucun nouvel obstacle, aucune modification de déplacement, de relief, de collision, de navigation ou de shader.
Les sprites du Chasseur et des monstres restent inchangés. Aucun changement dans `src/` ou `data/`.

## Activer et comparer

Dans Godot 4.3, lancer `draft3d/main.tscn` avec `--chapter=1 --painted-kit`.
L’essai reste désactivé sans cette option. Ajouter **`--painted-kit-ground=0`** restitue l’ancien sol,
son tapis d’herbe et ses détails, en conservant les trois modules du kit et sa palette : comparaison du sol seul.

Les captures de `docs/previews/sol_vegetal_cour/` utilisent `tools/art/cour_reference.tscn`, dérivée
de DraftRun : Chasseur et trois Corrompus figés, même caméra, éclairage et palette de 48 couleurs pour les deux vues.
Le second cadrage utilise la référence par défaut au lieu de `--painted-kit-frame`.
Les exports WebP sont des captures de jeu, non des illustrations générées. Le comparatif recadre les images
à l’identique sans les agrandir ; le reste des textures et les personnages sont strictement identiques.

## Assets et reproduction

- Source retenue imagegen intégré : `assets/concepts/incoming/material.cour_ground/source/ground.png`.
- Métadonnées : `assets/concepts/incoming/material.cour_ground/job.json`.
- Texture et matériau : `draft3d/matter/painted_kit/ground/terrain.png` et `material.tres`.
- Pas d’entrée de sprite au manifeste : il s’agit d’une texture de matériau 3D, pas d’un objet Sprite3D importé.
  Les entrées des détails existants restent valides et inchangées.

La source est réduite en nearest à **640 × 640**, soit **40 texels/m** pour une répétition de **16 m**.
Le sol conserve exactement ses UV mondiaux, raccordés entre les anciennes tuiles et sur les terrasses.
Le matériau est en nearest, sans mipmaps, rugosité 1, spéculaire 0 ; modulation d’albédo (0,70 ; 0,75 ; 0,80).
L’éclairage vient du moteur. La palette de rendu de 48 couleurs du kit n’est pas modifiée par ce lot.

Le conditionnement réserve **24 tons végétaux et 8 tons de pierre**, 32 couleurs au maximum au total,
sans tramage. Une quantification globale effaçait les nuances des dalles parce qu’elles occupent peu de pixels.
La répartition technique détecte les pixels froids (bleu > vert + 3) ; elle quantifie séparément les deux
ensembles sans ajouter de dessin ni recolorer la source. Les nuances de pierre doivent être revérifiées
si une autre source emploie aussi du bleu hors des pierres.

```text
python tools/art/condition_cour_ground.py assets/concepts/incoming/material.cour_ground/source/ground.png
godot --headless --editor --import --path .
godot --path . res://tools/art/check_cour_ground.tscn -- --cour-matter=0 --painted-kit --report=<rapport.json>
```

Python nécessite Pillow et NumPy. L’import Windows a employé le projet minimal aux mêmes chemins res://
décrit dans le guide du kit, puis les captures ont été prises dans le projet complet sur OpenGL Intel Iris Xe.
Une seule source finale est conservée dans Git ; les essais intermédiaires restent hors du dépôt.

## Vérification

Le contrôle natif `check_cour_ground` compare chacun des six sommets visuels de chacune des **336 anciennes
tuiles** à ses coins et à sa hauteur d’origine, et contrôle les UV mondiaux. Les **532 formes de collision**,
les placements et la navigation (**885 polygones**) sont identiques. Les 40 touffes restent sans collision
et sous 0,28 m ; le tapis dense est absent.

Le contrôle existant `check_cour_matter` passe aussi **sans l’option d’essai** : 7 662 triangles des 11 modules,
23 entrées de détails et géométrie d’origine conformes, ancien sol et ancienne herbe conservés. Les empreintes
SHA-256 de collision et de navigation concordent entre ces deux contrôles. Lint des trois scripts GDScript
modifiés/ajoutés conforme ; chargements et captures de jeu sans erreur. Rapport livré avec les aperçus.

La validation artistique reste celle du propriétaire : vérifier particulièrement le contraste du sol, la quantité
résiduelle d’herbe en volume et la lecture des dalles en mouvement. Pas de généralisation aux autres cartes.

## Prompts exacts

La première génération a utilisé les deux références du propriétaire et la capture du kit comme références.
Chaque correction suivante a pris la génération précédente comme image source. Seul le dernier résultat est retenu.

### 1. Génération depuis les références

```text
Use case: stylized-concept. Production TOP-DOWN SEAMLESS TILEABLE ALBEDO TEXTURE for the ground of an ancient overgrown stone courtyard in a detailed pixel-art dark fantasy game, applied to flat 3D terrain. The third reference is an actual in-game screenshot: MATCH its cold slate-grey painted masonry, dark fantasy sprite craftsmanship, restrained contrast, and desaturated woodland greens, but make the ground FAR cleaner and more deliberately composed than its current scratchy surface. First two references show only the desired grouped grass blades and partially swallowed rectangular paving: do NOT reproduce their bright lime saturation, vector smoothness or cartoon simplicity.
Output only a square edge-to-edge orthographic ground texture, not a scene, not a render, no characters, no props, no text, no frame, no perspective. Physically flat, neutral albedo, no baked cast shadows or directional lighting; restrained painted material shading only.
Art style: richly crafted detailed 16-bit pixel art, coherent crisp pixel clusters, clear shapes, clean edges, no anti-aliasing or blur. Native design scale about 640 x 640 texels representing 16 x 16 metres: individual paving blocks 14-24 native texels wide, blades grouped into tufts 6-12 texels wide. NO speckled noise, NO photographic grit, NO dithering, NO scribbled cracks, NO camouflage patches.
Composition: 60 percent a continuous quiet bed of short dark sage-green / olive grass and fine moss in LARGE calm readable masses, 30 percent worn slate-grey paving in about 9 loosely arranged irregular clusters of 4-10 rectangular stones, some staggered short broken rows. 10 percent dark olive-brown packed soil visible in joints and a few small clearings. No single central motif, no path drawn, no circular islands. Grass edges dissolve through deliberate short hooked blade groups growing over some stone edges, not random dots scattered over everything. Most blade detail at cluster edges; interiors broad and quiet. Stones clean medium cool grey, slightly uneven chipped corners, sparse edge wear, tiny moss at joints, matching the wall/stairs grey from third screenshot. Fine detail at edges, quiet centers. No pink or ochre cobbles, no pebbles confetti, no flower sprinkles, no isolated giant leaves.
Palette roughly 24-32 closely related colors: shaded forest #25362f #30462f #3e5a35, sage #4f6944 #60744d, rare subdued green highlight #74845a; slate stones #4b5561 #606c78 #76828e, tiny pale weathering #8c98a3; earth #353b2d #454a35. Vegetation should be alive but remain darker and quieter than the foreground character sprites. Shadows gently cool, no magenta accents on safe ground.
The tile must repeat seamlessly on ALL FOUR EDGES, same motif scale and values at opposite boundaries, no dark border and no obvious rectangular edge. Keep grass LOW, walkable and visually calm; this is the continuous floor texture under a few separately placed 3D tufts.
```

### 2. Espacement et échelle des dalles

```text
Edit this tile into the final production albedo for the same detailed pixel-art dark fantasy overgrown courtyard. Keep the same restrained olive / sage greens, cold slate grey stone, crisp clustered pixel detail, flat orthographic top-down view, no scene objects and no cast shadows. Preserve the painted craftsmanship and seamless repeatability on all four edges.
Main correction: this texture will cover SIXTEEN BY SIXTEEN METRES, then be reduced to a native 640x640 pixel tile. The paving in the current image is MUCH TOO LARGE and much too abundant. ERASE ALL current big stone clusters. Replace them with 12 SMALL ASYMMETRIC groups, each just 2-5 small worn stones. IMPORTANT: at this output image size, each individual stone must be only 35-45 pixels wide and 25-35 pixels tall, representing about 0.5 metre, not the current 100px wide blocks. Each little cluster around 90-130 output pixels across. Only about 8-10 percent of the whole texture should be exposed paving. Use uneven cluster spacing, some large open areas with none, no rows of repeated islands, no central motif. A couple isolated stones are okay, no gravel confetti. All stone faces cold slate grey, quiet centers, chipped edges, tiny moss in joints, subtle material variation.
Make the rest mainly a QUIET continuous short grass/moss bed, with low contrast broad connected greens. Reduce the contrast and density of the tiny grass-tip highlights by about a third: grass groups near paving and larger vegetation transitions have detail, but broad green areas should not be covered in equal tiny scratches. Rounded hooked blade clusters as in painted game environments, clean pixel clusters, not noisy camouflage, not lawn photo. Earth dark olive-brown only in small joints and clearings. No pink/ochre pebbles, flowers, arbitrary decorations, big leaves or thick black outlines. Neutral albedo illumination; actual lighting is provided by the 3D engine. No lime green.
Output only a single square SEAMLESS tileable texture, no atlas divisions, no text, no frames. Opposite edges must join invisibly, no dark or bright border. This is background under detailed character sprites; prioritize calm composition and subordinate contrast.
```

### 3. Correction de l’albédo de pierre

```text
Precise material correction to this seamless pixel-art ground tile. Preserve the ENTIRE layout, all grass/moss/soil areas, all 12 small stone groups, stone sizes, spacing, small grass blades, low contrast and all edges unchanged. Change ONLY the color/albedo of the exposed small paving stones: they currently become olive and too dark under the game lighting. Make their centers a clearly COOL BLUE-SLATE GREY around #8994a3, with edge wear #a4afbb and restrained joints #4b586a. They must match a cold grey-blue stone staircase in a dark fantasy game, visibly distinguishable from the muted green vegetation. Brighten the stone albedo substantially by about 40 percent, but keep their painted texture and restrained edge chips. No warm beige, greenish or yellow stones. No new stones, no rearrangement, no growth of the existing stone groups, no brightening of the grass. Flat neutral albedo without baked shadows; crisp detailed pixel art. Output a single square tile, seamless on all edges, no text or border.
```
