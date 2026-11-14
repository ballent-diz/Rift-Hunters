# Rendu pixel 3D (« 3D pixel art ») — premier lot

Session « Art et rendu », 14 novembre 2026. Objectif : que les modules 3D KayKit (surfaces unies, dégradés doux,
pleine résolution) parlent la même langue que les sprites pixel art (docs/ART_BIBLE.md), **sans toucher aux modules,
aux collisions ni au jeu**. Le rendu est actif par défaut sur toutes les cartes ; il a été réglé et vérifié sur la
Cour des Veilleurs (carte 1).

## Comparer

| Action | Commande |
|---|---|
| Basculer en partie | **F4** (bandeau « Rendu pixel : activé / désactivé ») ; le choix est gardé quand on rejoue (R) |
| Lancer sans le rendu pixel | `godot --path . res://draft3d/main.tscn -- --pixel=0` |
| Aplats et contours sans palette | `-- --pixel-palette=0` |
| Essai de pixels plus gros | `-- --pixel-scale=2` (le décor devient plus « gros pixel », mais les sprites perdent la moitié de leur détail : non retenu) |
| Gros plan fixe pour une capture | `-- --look=x,z,20` (hauteur de vue en mètres, 20 = zoom par défaut) |

Captures avant/après au même cadrage (même graine, même instant) : `docs/previews/rendu-pixel-3d/` — terrasse,
escaliers, abris du parvis, entrepôts, horde ; chaque image montre l'ancien rendu à gauche, le nouveau à droite.
Vidéo courte : `docs/previews/rendu-pixel-3d/deplacement.webm` (le Chasseur se déplace, rendu image par image par
le Movie Maker de Godot : la fluidité y est exacte, pas celle du conteneur).

## Principe

```
monde 3D (modules, sprites, effets) ─► SubViewport basse résolution (1 texel = 1 pixel d'art des sprites)
   1. décor opaque en aplats .................. toon.gdshader (paliers de lumière, soleil haut-gauche)
   2. passe plein écran ....................... pixel_post.gdshader (contours, liseré, palette du chapitre)
      ▲ profondeur du décor seul ............... vue jumelle, pixel_depth.gdshader
   3. sprites, PixelFX, cristaux, télégraphes .. dessinés ensuite : intacts
─► TextureRect plein écran (pixel_display.gdshader) : agrandissement net + décalage sub-pixel ─► HUD par-dessus
```

Fichiers : `draft3d/render/` (`pixel_render.gd` pilote tout, `pixel_palette.gd` ressource de palette,
`palettes/chapter_<n>.tres`, quatre shaders), outil `tools/art/build_pixel_palette.py`, essais
`tests/unit/test_pixel_render.gd`. Raccordement : `draft3d/run.gd` (option, F4, `view_size` remplace la taille de la
caméra), `draft3d/sprite_view.gd` (mode de transparence des sprites).

### 1. Basse résolution calée sur les sprites

- **Taille d'un texel : `TEXEL = 0,037 × 0,65 = 0,02405 m`**, celle d'un pixel d'art du Chasseur et des monstres de
  la campagne (échelle 0,65 du manifeste, `DraftSpriteView.PIXEL`). La vue basse résolution a donc
  `hauteur de vue / TEXEL` rangées : 832 rangées au zoom par défaut (20 m), de 457 (zoom 11) à 1081 (zoom 26).
  Décor et sprites ont exactement la même densité : un sprite d'échelle 0,65 est dessiné texel pour texel, net.
- **Facteur d'agrandissement : il dépend de l'écran**, pas d'un réglage. Il vaut `hauteur de fenêtre ÷ rangées` :
  ≈ 1,1 en 1600 × 900, 1,3 en 1080p, 1,7 en 1440p, **2,6 en 4K** (zoom par défaut), jusqu'à 4,7 en 4K zoomé au plus
  près. Le « facteur 3 à 4 » de la demande correspond donc à la 4K ; sur un écran plus petit, viser 3 à 4 rendrait le
  décor trois fois plus grossier que les sprites (ou abîmerait les sprites s'ils partagent la vue, voir
  `--pixel-scale=2`). Le pixel du décor = le pixel des sprites a été préféré, comme demandé.
- Si la vue demande plus de rangées que la fenêtre n'a de pixels (vue d'ensemble), elle est plafonnée à la hauteur
  de la fenêtre.
- **Caméra calée sur la grille** : sa position est arrondie au texel le long de ses axes droite/haut, à chaque
  image. Le décor ne scintille plus en mouvement (un mur avance d'un texel entier ou pas du tout).
- **Défilement fluide** : la vue est rendue avec un texel de marge de chaque côté ; l'image agrandie est décalée de
  la fraction de texel retirée par le calage (`remainder`).
- **Agrandissement net à toute échelle** (`pixel_display.gdshader`) : échantillonnage « nearest lissé » — chaque texel
  reste un aplat ; seule la rangée de pixels d'écran à cheval entre deux texels est mélangée. À une échelle non
  entière (1,1 ; 1,3…), un nearest pur doublerait une rangée sur dix et ferait « vibrer » le défilement.
- Le HUD (CanvasLayer) reste en pleine résolution, au-dessus.

### 2. Ombrage en aplats

- `toon.gdshader` remplace, à l'exécution seulement, chaque matériau standard opaque et éclairé du décor (textures,
  couleurs et UV repris du matériau d'origine ; l'eau, les matériaux transparents et non éclairés restent tels
  quels). Les fichiers des modules ne changent pas ; F4 remet les matériaux d'origine.
- Lumière en **4 paliers** (`bands`), ombres portées comprises ; teinte d'ombre violet-bleu (`shadow_tint`) et de
  lumière ambre (`light_tint`), comme les rampes des sprites (bible § 3 : ombres vers 262°, lumières vers 48°).
- **Soleil haut-gauche** en rendu pixel (`SUN_ROTATION = (-52°, -60°)`) : sommets clairs, faces gauches éclairées,
  façades à mi-teinte, faces droites et ombres portées vers le bas-droite.
- **Tramage** optionnel : `band_dither` (Bayer 4 × 4 sur la grille des texels, aux transitions de paliers) et
  `palette_dither` (avant quantification). Désactivés par défaut : sur les grands sols unis, le tramage se lisait
  comme du bruit ; à essayer par chapitre (0,2 à 0,35).

### 3. Contours, liseré et palette (passe plein écran)

Le moteur de compatibilité de Godot 4.3 (`gl_compatibility`) **n'offre pas la texture de profondeur aux shaders**
(`hint_depth_texture` ne compile pas). Une **vue jumelle** dessine donc la profondeur du décor seul : copies
statiques des maillages de la carte (même transformation), matériau `pixel_depth.gdshader` qui code la profondeur
sur deux octets. Avantage : les sprites n'y figurent pas, ils ne reçoivent aucun contour en double.

- **Silhouettes** (saut de profondeur > 0,35 m) : contour sélectif de la bible — côté bas-droite, `#0e0a17` mêlé à
  40 % au **liseré violet `#b56cf0`** (hors palette, couleur exacte) ; côté haut-gauche, la couleur du matériau
  assombrie (`lit_outline`).
- **Plis** (courbure de la profondeur > `crease_depth`, 5 cm) : creux et pied des objets assombris
  (`crease_dark`), arêtes saillantes éclaircies d'un pixel (`edge_light`). En dessous de 5 cm (dalles légèrement
  inégales du pack), rien n'est tracé : à 1,2 cm, chaque dalle KayKit se striait de lignes parasites.
- **Palette** : chaque pixel du décor prend la couleur de la palette la plus proche (distance OKLab). 32 couleurs
  par chapitre au départ.
- Ordre de dessin : la passe a la priorité de rendu minimale de la passe transparente. Sprites (passés en
  transparence mélangée pendant le rendu pixel), PixelFX, cristaux (matériau transparent), ombres au sol et
  télégraphes sont dessinés ensuite : ni contour, ni palette.

## Palette par chapitre (ressource éditable)

`draft3d/render/palettes/chapter_<n>.tres` (`DraftPixelPalette`, modifiable dans l'inspecteur de Godot ; F4 deux fois
recharge le décor, une nouvelle partie relit le fichier) :

| Champ | Défaut | Rôle |
|---|---|---|
| `colors` | 32 couleurs tirées de la carte | couleurs permises pour le décor (64 au plus ; vide = pas de quantification) |
| `outline`, `rim`, `rim_strength`, `lit_outline` | `#0e0a17`, `#b56cf0`, 0,4, 0,55 | contour sélectif et liseré |
| `shadow_tint`, `light_tint` | violet-bleu, ambre pâle | glissement de teinte des paliers |
| `bands` | 4 | paliers de lumière (3 ou 4) |
| `band_dither`, `palette_dither` | 0, 0 | tramages |
| `crease_depth`, `crease_dark`, `edge_light` | 0,05 m, 0,45, 0,18 | plis |
| `textures` | vide | textures pixel art des modules (lot suivant) : chemin d'origine → texture repeinte |

Chapitres 1 et 5 : Cour des Veilleurs (même palette). Chapitres 2 à 4 : première palette tirée de leur carte, non
retouchée (le réglage fin de ce lot porte sur la carte 1).

## Appliquer le rendu à une nouvelle carte

1. Rien à faire pour les aplats, contours et calage : tout `MeshInstance3D` du niveau (`DraftLevel`) est pris en
   charge. Un matériau transparent ou non éclairé reste tel quel (eau, lueurs).
2. Palette : capturer la carte en aplats sans palette à plusieurs endroits, puis en tirer la palette :
   ```bash
   for spot in 0,-4,24 0,24,24 -30,6,24 30,6,24 0,-16,24; do
     xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 res://draft3d/main.tscn -- \
       --chapter=<n> --seed=1 --god --passive --look=$spot --pixel-palette=0 --shots=/tmp/pal/$spot \
       --shot-times=2 --quit-after-shots
   done
   python3 tools/art/build_pixel_palette.py <n> /tmp/pal/*/*.png [--colors=32]
   ```
3. Retoucher la palette dans l'inspecteur (supprimer les couleurs de sprites ramassées par la capture, ajouter une
   teinte manquante), régler `crease_depth` si le pack a des sols en relief.
4. Si un élément de décor bouge (porte, pont mobile), sa copie dans la vue de profondeur ne le suivra pas : le
   déplacer aussi dans `_depth_root` ou l'exclure (les décors actuels sont tous statiques).

## Coût (horde de 300 ennemis)

Mesure : `godot --path . res://draft3d/main.tscn -- --perf=100,200,300 [--pixel=0]`, même conteneur que la mesure du
13 novembre (4 cœurs Xeon, **sans carte graphique**, rendu logiciel llvmpipe), fenêtre 1600 × 900.

MESURES_PERF

Sur une vraie carte graphique, le rendu pixel dessine **moins** de pixels que le rendu lisse (832 rangées contre la
résolution native), plus une vue de profondeur du décor seul (même nombre de rangées, sans éclairage) et une passe
plein écran (cinq lectures de profondeur et 32 comparaisons de couleur par texel). À mesurer chez le propriétaire
avec la même commande, avec et sans `--pixel=0`.

## Limites connues

- Les sprites d'échelle différente de 0,65 (0,75 pour les Corrompus de base, 0,5 pour certains effets) ne tombent
  pas exactement sur la grille : un pixel d'art couvre 1,15 ou 0,77 texel, comme aujourd'hui à l'écran.
- Les sprites ne sont pas calés sur la grille (ils se déplacent au sous-texel) : aucune différence visible au
  facteur 1 à 2, à surveiller en 4K.
- Les PixelFX d'origine sont dessinés à 0,03 m par pixel (pas 0,024) : légère différence de densité, inchangée.
- La transparence mélangée des sprites trie les sprites par distance (comme des cartes posées) au lieu du tampon de
  profondeur : identique pour des sprites face caméra, à surveiller sur les très grands boss.

## Lots suivants (préparés, non faits)

1. **Textures pixel art des modules, par chapitre** : prompt Codex n° 2 de `docs/prompts/CODEX_EN_ATTENTE.md`. Le
   branchement existe déjà (champ `textures` de la palette, remplacement à la volée dans `_toon_for`).
2. **Détails posés** en sprites (herbes, gravats, flaques, feuilles) : `Sprite3D` couchés au sol (`billboard`
   désactivé, `axis` Y) ou debout pour les touffes, dessinés après la passe de palette comme les autres sprites,
   semés de façon déterministe par carte (même principe que `DecorLayout` de la v1) en évitant les chemins de la
   navigation ; feuilles 32 × 32 à l'échelle 0,65, palette du chapitre.
3. **Brume et lumière par chapitre** : champs de la palette (couleur et densité de brume de hauteur, teinte du
   soleil et de l'ambiance) appliqués avant la quantification pour que la brume elle-même tombe dans la palette ;
   brume au sol tramée (Bayer) plutôt qu'en dégradé ; lumières des torches en anneaux de paliers (déjà le cas).
