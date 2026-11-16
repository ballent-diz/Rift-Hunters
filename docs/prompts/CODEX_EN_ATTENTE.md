# Prompts pour Codex en attente (mis de côté le 3 novembre 2026)

Prompts rédigés par Claude et validés par le propriétaire, à envoyer à Codex après sa réinitialisation. Les envoyer
dans l'ordre ; chacun est autonome. Rappel pour Codex : une branche par tâche depuis `main` à jour, PR vers `main`
(AGENTS.md) ; si l'API GitHub le bloque, pousser la branche et donner son nom et son dernier commit : Claude ouvrira
la PR.

## 1. Carte 15, Cœur des marais : rambarde en double sur le pont nord-ouest

```
Tâche : retouche locale de la carte 15 « Cœur des marais » (environment.marsh_heart). Lis d'abord AGENTS.md,
docs/maps/COEUR_DES_MARAIS.md et docs/maps/QUALITE_DES_CARTES.md. Branche codex/carte-15-rambarde depuis main à jour,
PR vers main, poids indiqué. Aucun changement dans src/ ni data/.

Défaut : sur le pont nord-ouest (monde x de -690 à -540, y de -60 à 0 ; soit les pixels 980 à 1130 × 2450 à 2510 de
la carte à 1 px par unité), un morceau de rambarde est peint en double au milieu du tablier, décalé vers le bas et la
droite par rapport à la vraie rambarde sud, avec un bout de poutre rouge. Efface ce morceau et prolonge le dallage du
pont (mêmes dalles, mousse et lierre que le reste du tablier), puis continue la rambarde sud d'un seul trait jusqu'à
la colonne d'angle. Ne change ni le plan, ni l'emprise du pont, ni le reste de la carte : pixels identiques hors de
la zone retouchée (preuve numérique comme pour la correction d'échelle).

Livraison : master et tuiles régénérés (2,25 px par unité, sans perte), contrôle check_map_quality.py conforme,
capture Godot avant/après au zoom réel avec le Chasseur sur le pont. Ne touche pas à collision.png : Claude
rouvrira la collision du tablier à l'intégration.
```

## 2. Textures pixel art des modules 3D, par chapitre (rendu pixel 3D, lot 2)

```
Tâche : repeindre en pixel art les textures des modules 3D KayKit de la version 2 (draft3d/), une série par
chapitre, sans toucher aux modèles, aux UV, aux collisions ni au code de jeu. Lis d'abord AGENTS.md,
docs/ART_BIBLE.md (§ 3 : lumière haut-gauche, rampes à glissement de teinte, liseré violet) et
docs/art/RENDU_PIXEL_3D.md (rendu pixel, palette par chapitre). Branche codex/textures-pixel-modules depuis main à
jour, PR vers main, poids indiqué.

Contexte : le décor est dessiné en basse résolution, 1 texel = 0,024 m (un pixel d'art des sprites), en aplats
(4 paliers), contours et palette de 32 couleurs par chapitre (draft3d/render/palettes/chapter_<n>.tres). Les
textures d'origine (draft3d/kaykit/*_dungeon_texture.png en 1024 px, draft3d/halloween/halloweenbits_texture.png,
draft3d/medieval/hexagons_medieval.png, draft3d/spacebase/spacebits_texture.png) sont des dégradés lisses.

À faire, chapitre 1 d'abord (Cour des Veilleurs, draft3d/level_ruins.gd, pack Dungeon Remastered), puis 2 à 4 :
1. Pour chaque texture utilisée par la carte, une version pixel art de même disposition (mêmes zones UV, mêmes
   proportions), à la densité du rendu : une face de 4 m couvre environ 166 texels à l'écran, la texture ne doit pas
   être plus fine que cela (taille conseillée : 256 px au lieu de 1024, filtre nearest à l'import).
2. Couleurs prises dans la palette du chapitre (ou ajoutées à cette palette, 64 couleurs au plus) ; détails
   dessinés à la main au pixel : joints de pierre, fissures, mousse, bois veiné ; aucun dégradé ; pas de lumière
   peinte (le shader éclaire) sauf une occlusion légère dans les joints.
3. Fichiers dans draft3d/<pack>/pixel/<chapitre>/ ; renseigner le champ `textures` de
   draft3d/render/palettes/chapter_<n>.tres : chemin res:// de la texture d'origine → texture repeinte.
4. Captures avant/après au même cadrage, rendu pixel actif, pour chaque chapitre (commande de capture dans
   docs/art/RENDU_PIXEL_3D.md, `--look=x,z,20`), dont terrasse, escaliers et horde pour le chapitre 1.
5. tools/run_tests.sh complet vert. Ne touche ni draft3d/*.gd, ni les .tscn/.gltf des modules, ni src/, ni data/.
```

## 3. Eau et marée du Marais des Marées (carte 8) : textures et boucles animées en pixel art

```
Tâche : peindre en pixel art les images de l'eau de la carte 8 « le Marais des Marées » (draft3d/level_marsh.gd),
sans toucher au code, aux collisions ni aux autres cartes. Lis d'abord AGENTS.md, docs/ART_BIBLE.md (§ 3 : lumière
haut-gauche, rampes à glissement de teinte, liseré violet), docs/art/RENDU_PIXEL_3D.md et docs/maps/CARTES_3D.md
(section « Carte 8 »). Branche codex/eau-marais depuis main à jour, PR vers main, poids indiqué.

Contexte : vue de dessus inclinée, 1 texel = 0,024 m. La marée monte toutes les 80 s (montée en 8 s), noie des levées
de terre de 4 à 5 m de large, puis se retire. Le code anime déjà le niveau de l'eau ; il manque les images.

À livrer dans draft3d/marsh/ (PNG sans perte, fond transparent pour les animations) :
1. eau_surface.png : texture d'eau trouble répétable sans couture (256 × 256), vert-de-gris, petites rides ;
2. eau_rides_<1..8>.png : boucle de 8 images des rides (même taille, se raccorde à la première) ;
3. ecume_<1..6>.png : boucle de ligne d'écume le long d'une berge (512 × 32, bord terre en haut) ;
4. vase_mouillee.png : terre détrempée répétable (256 × 256), plus sombre et brillante que la terre sèche ;
5. eclaboussure_<1..6>.png : éclaboussure d'un pas dans l'eau peu profonde (64 × 64), pour les monstres.
Respecte la palette du jeu (pas de réalisme photographique), contours et liseré violet comme les sprites.
Joins une planche de contrôle (toutes les images à l'échelle 2) et un GIF de chaque boucle.
```

## Déjà réglé (ne plus envoyer)

- Barrières de zone peintes, une par chapitre (ancien prompt 4) : livrées par Codex (25 assets `object.barrier_1` à
  `_5`, docs/art/BARRIERES_PEINTES.md), raccordées en jeu par Claude le 9 novembre (le rideau shader est retiré).
- Échelle des décors de la carte 4 et proportions des chapitres 4 et 5 : réglé le 8 novembre par la réduction du
  décor par carte (`decor_scale`, docs/maps/ECHELLE_CHAPITRES_4_5.md), sans repeindre. Proportions des cartes 16 à 25
  (ancien prompt 3) : sans objet.
- Échelle des décors de la carte 15 (ancien prompt 2) : escaliers et colonnes repeints par Codex (PR #136).
- Objets posés sur les cartes (miroirs-portails, cristaux, mannequin) : livrés par Codex (PR #131, fusionnée le
  8 novembre via #132) ; intégration en jeu à faire par Claude.
- Carte 16 : corrections de la composition, devenues sans objet (carte détaillée et intégrée en jeu).
- PR #90 (objets miroirs) et PR #92 (sprites du chapitre 4) : fusionnées.
- Image de référence des collisions de la carte 15 : le propriétaire a peint les collisions, carte intégrée.
- Rochers-abris en sprite séparé (`object.cover_rock`) : abandonné, les abris se peignent dans les décors.
