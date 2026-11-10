# Masquage des personnages par le décor peint

Les cartes sont des images peintes : rochers, arbres, murs, piliers, statues font partie de l'image. Les collisions
sont peintes **au pied** des obstacles, pour que l'on puisse passer derrière leur partie haute. Ce système fait passer
le décor **devant** le Chasseur, les Échos et les Corrompus qui sont derrière : la partie cachée reste visible en
silhouette gris clair translucide (avec un liseré plus sombre), le reste du personnage est normal.

Purement visuel : collisions, déplacements, tirs et règles ne changent pas. Images de carte et collisions intactes.
Une carte sans données de masquage s'affiche comme avant (aucun coût).

Captures : `docs/previews/masquage/` (derrière / sans masquage / devant, ouverture de la clôture, chevauchement du pin
et de la colonne, rocher, éditeur, en jeu de nuit).

## Lancer l'éditeur

```
godot --path . res://tools/art/occlusion_editor.tscn -- --arena=<arène>
```

Dans Godot : ouvrir `tools/art/occlusion_editor.tscn` puis **F6** (sans argument : `three_rifts`). `<arène>` est un
fichier de `data/arenas/` sans `.tres` (ex. `firefly_woods`). Les données appartiennent au **décor** (l'image) : deux
arènes qui partagent une carte partagent ses masques.

## Procédure pour équiper une carte

1. Lancer l'éditeur sur l'arène. Les collisions existantes sont hachurées en rouge (lecture seule, **C**).
2. Pour chaque obstacle qui peut cacher un personnage (arbre, rocher, mur, pilier, statue, ruine, gros débris) :
   - **N** avec la souris au pied de l'obstacle : nouvel élément (identifiant stable `<catégorie>_<nn>`) ;
     **K** change la catégorie (facultative : rock, tree, wall, building, ruin, pillar, statue, debris).
   - **P** polygone : clic gauche pour chaque point du contour **visible** (toute la silhouette, pas seulement le
     pied), clic droit ou Entrée pour fermer et remplir. **Maj** en fermant découpe un trou : portes, arches,
     intervalles entre les piliers, vides d'une clôture.
   - **B** pinceau pour retoucher : clic gauche peint, clic droit gomme, **[** et **]** règlent la taille.
   - **F** ligne de pied : simple clic = ligne horizontale ; glisser de gauche à droite = ligne inclinée (mur ou
     clôture vus de biais). Un personnage dont le pied est **au-dessus** de la ligne est derrière l'obstacle.
     La placer là où l'obstacle touche le sol (bas de la base), en général au bord bas de sa collision.
3. **V** aperçu, au zoom réel avec **R** : un personnage suit la souris (**1** Chasseur, **2** Écho, **3** Corrompu),
   clic gauche pour en poser un, Retour arrière pour les retirer. Passer devant et derrière chaque obstacle.
4. **Ctrl+S** enregistre (puis `godot --headless --import --path .` pour que le jeu lise la nouvelle texture).
   On peut fermer et reprendre plus tard : tout est rechargé.

| Action | Commande |
|---|---|
| Choisir l'élément sous la souris (répéter = suivant parmi ceux qui se chevauchent) | G, ou clic dans la liste |
| Masquer / afficher l'élément (affichage de l'éditeur seulement) ; tout afficher | H ; Maj+H |
| Supprimer l'élément | Suppr |
| Annuler / rétablir | Ctrl+Z / Ctrl+Y (ou Ctrl+Maj+Z) |
| Vue : déplacer / zoom / zoom réel du jeu | ZQSD, WASD, flèches, clic milieu ; molette, + et - ; R |
| Calques : collisions / masques / lignes de pied | C / M / L |

Conseils : un élément par obstacle (deux obstacles qui se chevauchent = deux éléments, chacun avec sa ligne) ; un
élément peut avoir plusieurs morceaux (poteaux et traverse d'une clôture). Inutile de masquer ce qui ne dépasse pas de
sa collision vers le haut : personne ne peut se tenir derrière.

## Fichiers

Dans `assets/environments/<décor>/occlusion/` (séparés des images et des collisions) :

| Fichier | Rôle |
|---|---|
| `occlusion.json` | liste des éléments et repères (lue par l'éditeur ; le jeu n'en lit que l'en-tête) |
| `masks/<id>.png` | silhouette de chaque élément (alpha), recadrée sur son rectangle ; sources de travail, ignorées par l'import et l'export de Godot (`.gdignore`) |
| `depth.png` | texture de profondeur cuite à l'enregistrement, recadrée sur les éléments ; seule donnée image du jeu |

Le manifeste (`assets/asset_manifest.json`) reçoit `"occlusion": "res://.../occlusion.json"` dans l'entrée du décor
au premier enregistrement.

`occlusion.json` :

```
version     1
environment "environment.<décor>"
map_size    [largeur, hauteur]   pixels de la carte entière (toutes les tuiles côte à côte)
cell        pixels de carte par cellule de la grille de masquage (≈ 2 unités peintes, fixé à la création)
grid        [colonnes, lignes]   = map_size / cell, arrondi au-dessus
depth       "depth.png"
depth_rect  [x, y, l, h]         cellules couvertes par depth.png
elements    [{id, category, rect: [x, y, l, h] en cellules, mask, depth: [[x1, y1], [x2, y2]] en cellules, hidden}]
```

`depth.png` (RVB 8 bits, lu en RG8) : par cellule, la ligne de pied de l'élément visible à cet endroit, en fraction
de la hauteur de la carte codée sur 16 bits (R = octet fort, G = octet faible) ; 0 = aucun élément. Là où des
éléments se chevauchent, le plus proche (ligne la plus basse) l'emporte, ce qui reproduit la peinture. La ligne est
évaluée à la colonne de la cellule (constante au-delà de ses deux repères).

## Repères

- pixel de la carte → cellule : `cellule = pixel / cell` (les tuiles se suivent de gauche à droite, un masque peut
  enjamber un raccord de tuiles) ;
- cellule → monde : `monde = arène.position + cellule × cell / map_size × arène.size`, où `arène` est le rectangle de
  l'arène **en jeu** (centré sur 0, déjà réduit par `ArenaData.decor_scale`, voir `ArenaData.scaled_copy`). La carte
  couvre exactement ce rectangle : changer `decor_scale` ou la taille de l'arène ne demande pas de refaire les masques ;
- une carte remplacée par une image d'une autre taille invalide ses masques (l'éditeur les ignore et l'annonce).

## Rendu en jeu

- `ArenaGround.occlusion_map()` charge les données (`OcclusionMap`), rangées dans `RunContext.occlusion`.
- Un seul `ShaderMaterial` partagé (`assets/shaders/occluded_entity.gdshader`) pour tous les corps, un pour les
  ombres : pas de paramètre par entité, pas de nœud par couple obstacle/entité, pas de calcul processeur par pixel.
  Le shader lit la position monde de chaque pixel et le **pied** = origine du sprite (point d'appui de la feuille) ;
  un texel de profondeur, une comparaison.
- Les petits pas et les sauts passent par l'offset du sprite (`EntityVisual.set_lift`) : le pied reste au sol, pas de
  clignotement en marchant le long d'une ligne.
- **Concernés** : le corps du Chasseur, des Échos, des Corrompus, élites, mini-boss et boss (`EntityVisual`), et leur
  ombre au sol (partie cachée non dessinée). **Jamais masqués** : barres de vie, marqueurs de statut, annonces
  d'attaque et télégraphes, projectiles, effets de sorts, ramassables, nombres de dégâts, HUD et portraits.
- Nuit, blizzard, furtivité : la silhouette garde l'opacité de l'entité (une entité invisible le reste) et est
  dessinée dans la couche de l'entité, donc sous le voile de nuit : rien n'est révélé.
- Coût mesuré (`tools/art/preview_occlusion.tscn -- --bench=400`, 400 Corrompus animés à l'écran, rendu logiciel
  llvmpipe du conteneur, le cas le plus défavorable) : 57 ms → 66 ms par image (+15 %, coût du rendu par pixel sur le
  processeur), appels de dessin 466 → 475-503. Sur une carte graphique, une lecture de texture par pixel de sprite.

## Outils de vérification

```
xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 res://tools/art/preview_occlusion.tscn -- --out=<dossier>
xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 res://tools/art/preview_occlusion.tscn -- --bench=400
xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 res://tools/art/occlusion_editor.tscn -- --arena=firefly_woods --capture=<fichier.png>
```

Tests : `tests/unit/test_occlusion.gd` (trous, chevauchement, ligne inclinée, règle devant/derrière avec
`decor_scale`, sauvegarde et reprise, secteur de démonstration, matériau partagé).

## Démonstration

Bois des Lucioles (`environment.firefly_woods`), ruines du sud-ouest : trois piliers, la colonne et le pin qui se
chevauchent, la clôture (ouvertures entre poteaux et traverse, ligne de pied inclinée) et un rocher. Le détourage de
toutes les cartes est un travail séparé (voir `docs/ROADMAP.md`).
