# Fiches visuelles du gameplay v2 (combos, passifs, cartes) — à produire par ChatGPT

Session « Gameplay », lot 5 de `docs/design/GAMEPLAY_V2_ARCHITECTURE.md`. Claude Code ne dessine aucun visuel
définitif : ces fiches décrivent **ce que le jeu attend** (déclencheur, dimensions, durée, images, ancrage, format,
chemin). Tant qu'un fichier manque, le jeu joue l'effet existant indiqué en « repli » : rien ne casse.

## 1. Conventions communes

### Effets en jeu (feuilles PixelFX)

- **Vue** : caméra 2,5D orthographique en plongée (environ 46° au-dessus de l'horizontale), décor 3D, personnages en sprites 2D.
  Les effets sont des **sprites face caméra** (billboard) : dessiner l'effet **tel que vu par cette caméra**. Un
  effet au sol (onde, traînée) se dessine donc en **ellipse aplatie** (rapport hauteur/largeur ≈ 0,7), pas en cercle.
- **Style** : pixel art, lumière haut-gauche, liseré violet bas-droite (`docs/ART_BIBLE.md`), fond **transparent**,
  pas de texte, palette « Faille » (violets, cyan prismatique `#8fe6ff`, or `#ffd27a`).
- **Format** : une planche PNG RGBA (images de même taille, rangées de gauche à droite puis de haut en bas, sans
  marge) + un JSON au format PixelFX du dépôt (exemple : `assets/vfx/pixelfx/ring_burst/violet.json`) :
  `frames[].frame {x, y, w, h}` dans l'ordre de lecture et `meta.pixelfx {fps, loop, frames, frameSize, columns}`.
- **Chemin** : `assets/vfx/pixelfx/<id>/violet.png` et `assets/vfx/pixelfx/<id>/violet.json` (famille par défaut,
  utilisée pour tous les ennemis).
- **Ancrage** : le centre de l'image est posé au point indiqué (« ancrage ») ; prévoir l'effet centré.
- **Échelle** : le jeu met automatiquement la largeur de l'image à la **largeur en jeu** de la fiche ; seules les
  proportions et la lisibilité comptent. Taille d'image conseillée : environ
  **64 px par mètre** (une image de 128 px pour un effet de 2 m).
- **Raccord** : déposer les deux fichiers au bon chemin suffit (`DraftRun.fx_or`, `DraftPixelFx.has_sheet`). Lancer
  ensuite `godot --headless --import --path .`.

### Illustrations de cartes (récompenses)

- **Format** : PNG carré **1254 × 1254 px**, même rendu que les illustrations existantes
  (`assets/ui/items/upgrades/might.png`) : objet ou geste central, fond sombre en vignette, sans texte.
- **Chemin** : `assets/ui/items/upgrades/<id de carte>.png` + entrée `"upgrade.<id de carte>": {"image": "res://…"}`
  dans `assets/ui/items/catalog.json` (Claude Code l'ajoute à l'intégration). Le panneau de choix les affiche
  automatiquement (`ItemArt.texture("upgrade", id)`).

## 2. Combos (prioritaires)

Déclenchement et règles : `draft3d/combos.gd`. Chaque combo affiche aussi son nom en bandeau (texte traduit).

| id (dossier) | Déclencheur | Effet à montrer | Largeur en jeu | Durée / images / fps | Boucle | Ancrage | Repli actuel |
|---|---|---|---|---|---|---|---|
| `combo_prismatic_execution` | Une Rupture frappe un ennemi touché par la Lance prismatique depuis moins de 2 s ; joué **sur chaque cible** (6 au plus) | Éclat prismatique qui « se referme » sur la cible puis explose : lignes cyan convergentes (0-40 %), flash blanc-or (40-55 %), éclats qui retombent | 2,0 m | 0,6 s · 12 images · 20 fps | non | centre de la cible, 0,6 m au-dessus du sol | `ring_burst` (reflets) |
| `combo_prismatic_deluge` | Une Lance prismatique traverse un Cristal réfracteur ; joué **sur le cristal** | Le cristal se fend et projette une gerbe d'éclats en éventail (4 traits partent dans la direction de la Lance, ± 18°) ; dominante cyan, cœur blanc | 3,0 m | 0,5 s · 12 images · 24 fps | non | centre du cristal, 0,8 m au-dessus du sol | `ice_shatter` (reflets) |
| `combo_gravity_blade` | Une Taille fendante atteint un puits de Singularité actif ; joué **sur le puits** | Onde de choc circulaire au sol (ellipse aplatie) partant du centre du puits, bord violet sombre et lueur intérieure, distorsion en anneau, petites particules aspirées puis repoussées | 2 × rayon du puits × 1,3 (≈ 5 à 7 m ; dessiner pour 6 m) | 0,55 s · 14 images · 24 fps | non | centre du puits, 0,6 m au-dessus du sol | `dark_explosion` |

À prévoir ensuite (non branché, pour décision) : un **repère de cible** pour l'Exécution prismatique (petit prisme
cyan au-dessus d'un ennemi touché par la Lance pendant 2 s, 48 × 48 px, 8 images en boucle à 10 fps, ancré 1,6 m
au-dessus du sol) ; il rendrait la fenêtre lisible avant la Rupture.

## 3. Passifs techniques

| id (dossier) | Déclencheur | Effet à montrer | Largeur en jeu | Durée / images / fps | Boucle | Ancrage | Repli actuel |
|---|---|---|---|---|---|---|---|
| `passive_dash_blade` | Ruée tranchante : chaque ennemi traversé pendant la Ruée | Entaille horizontale nette, blanc-violet, orientée de gauche à droite (le jeu ne la retourne pas) | 1,4 m | 0,25 s · 6 images · 24 fps | non | centre de l'ennemi, 0,6 m au-dessus du sol | `hit` |
| `passive_void_wake` | Sillage du vide : un point de traînée toutes les 0,08 s de Ruée | Flaque d'ombre violette au sol (ellipse) qui ondule ; se superpose bien à elle-même | 1,8 m | 2,0 s · 8 images · 8 fps | **oui** (le jeu la retire au bout de 2 s) | point de passage, 0,2 m au-dessus du sol | `shadow_hands` |
| `passive_counter_cut` | Contre-taille : un coup esquivé pendant la Ruée (le sort suivant est renforcé) | Anneau or qui se contracte autour du Chasseur puis étincelle | 2,2 m | 0,45 s · 10 images · 22 fps | non | poitrine du Chasseur (≈ 1 m) | `ring_burst` |

L'**Ancre** réutilise le puits de Singularité (aucun visuel propre nécessaire).

## 4. Illustrations des nouvelles cartes

| id de carte (fichier) | Rareté (couleur de bordure en jeu) | Sujet |
|---|---|---|
| `passive_dash_blade` | Rare (bleu) | Silhouette en pleine ruée, une lame de lumière la prolonge |
| `passive_void_wake` | Rare (bleu) | Traînée d'ombre au sol derrière des pas, volutes qui retiennent une griffe |
| `passive_counter_cut` | Épique (violet) | Projectile frôlant un corps en esquive, éclair or en contre |
| `passive_anchor` | Épique (violet) | Ennemi entravé qui s'effondre en petit trou noir |
| `rule_extra_slot` | Légendaire (or) | Cinquième gemme qui s'enchâsse dans un bracelet de quatre |

Les cartes de sort et de mutation réutilisent déjà les icônes existantes.

## 5. Retour attendu de ChatGPT

Pour chaque fichier : le chemin, la planche PNG et son JSON (ou l'illustration), et une capture de contrôle de
l'animation. Claude Code intègre, ajuste la largeur ou l'ancrage si besoin, puis fournit des captures en jeu.
