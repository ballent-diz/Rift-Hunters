# Échelle du décor peint — chapitres 4 et 5 (et cartes 15 et 4)

Retour de test du 8 novembre : sur plusieurs cartes, les personnages paraissent trop petits face au décor peint.
Décision validée (« solution 2 ») : **on ne grossit pas les personnages, on réduit le décor par carte** avec le réglage
`decor_scale` d'`ArenaData` (1 par défaut).

## Fonctionnement

- Les `.tres` restent en **coordonnées peintes** (celles de l'éditeur de niveau et des collisions du propriétaire).
- Au chargement, `GameDB` remplace chaque arène par `ArenaData.scaled_copy()` : taille de l'arène, finale (centre,
  rayons, murs), failles, zones (ancres, barrières), autel, terrains (lent, vase, marée, courants, crues, glace),
  plaques brûlantes (position et rayon), nids, bulbes, abris, portails, cristaux, cratères, braseros, clairières
  sont multipliés par `decor_scale`.
- L'image, le masque de collisions et la mini-carte sont posés sur le rectangle de l'arène : ils suivent la taille.
  `ArenaGround` réduit aussi le point de départ et le pas du champ de distance (`field_step × decor_scale`).
- Ne changent pas : personnages, vitesses, portées, rayons d'effet (chaleur d'un brasero, lumière, souffle d'un
  bulbe, rayon d'apparition), taille des abris et des portails, cellule de navigation, équilibrage.
- Une arène qui réutilise le décor d'une autre doit porter le même `decor_scale` (survival_ford = mist_ford).

## Mesures (8 novembre 2026)

Densité des décors : 2,25 px par unité. Chasseur : cellule 80 px × `scale` 0,65 = 52 unités (vérifié dans le
manifeste). Mesures sur les images en pleine résolution, gabarit du Chasseur posé à côté.
Facteur = taille attendue (milieu de la fourchette d'`ART_BIBLE.md`) / taille mesurée, arrondi.

| Carte | Élément mesuré | Mesure (unités) | Attendu | Facteur |
|---|---|---|---|---|
| 1 Ruines des Cascades (étalon) | marches / pavés / pilier | 13 / 20 / 53 | 12-16 / 15-26 / 30-45 | 1 (référence) |
| 4 Gué des Brumes (mist_ford) | dalles de la place, pavés du pont | 28-30 / 24 | 15-26 | **0,8** |
| 15 Cœur des marais (marsh_heart) | marches centrales / dalles / colonnes | 21 / 36 / 75 | 14 / 20 / 38 | 1 (repeinte par Codex, prompt 2) |
| 16 Entrée du Glacier (glacier_entry) | blocs de glace (abris), pas d'escalier ni de dallage | 160 × 210 | 110-160 | **0,9** |
| 17 Col des Braseros (brazier_pass) | pavés du pont / marches / arche | 22 × 11 / 15 / 84-98 | — | 1 (à l'échelle) |
| 18 Lac gelé des Tempêtes (storm_lake) | marches de l'escalier de bois / porte de cabane / caisse | 21 / 93 / 67 | 14 / 80 / 30-40 | **0,7** |
| 19 Banquise du Phare (lighthouse_floe) | pavés du pont / porte du phare / marches | 22 / 75 / 11 | — | 1 |
| 20 Cœur du Silence (silent_heart) | lattes du pont / piliers de glace | 11 / 67 | — | 1 (0,9 si jugé gros en jeu) |
| 21 Faubourgs brisés (shattered_outskirts) | marches / pavés | 12 / 16 | — | 1 |
| 22 Sanctuaire des Runes (rune_sanctum) | marches / colonnes | 17 / 44 | 14 / 38 | **0,9** |
| 23 Quartiers suspendus (suspended_quarters) | planches du pont / pavés | 21 / 20 | — | 1 |
| 24 Panthéon brisé (shattered_pantheon) | marches / pavés / colonnes / porte | 15 / 16 / 40 / 71 | — | 1 |
| 25 Œil de la Faille (rift_eye) | pavés / amas de blocs | 31 / 115 | 20 / 110-160 | **0,85** |

Captures au zoom réel, avant (gauche) / après (droite), Chasseur et Cendrelame posés sur un escalier (cartes 15, essai
abandonné, et 18), un dallage (carte 4) et près d'un bloc de glace (carte 16) : [echelle_avant_apres.webp](echelle_avant_apres.webp).
Test : `tests/unit/test_decor_scale.gd`.

## État

- Appliqué en jeu : mist_ford et survival_ford (0,8), glacier_entry (0,9), storm_lake (0,7). brazier_pass reste à 1.
- marsh_heart (carte 15) : non réduite à la demande du propriétaire, Codex la repeint (prompt 2). Une réduction
  de 0,65 avait été essayée (ligne du haut des captures) avant cette consigne. Mesurer à nouveau après livraison.
- Cartes 19 à 25 pas encore intégrées : à l'intégration, poser `decor_scale` selon la colonne « Facteur »
  (rune_sanctum 0,9 ; rift_eye 0,85 ; les autres 1), puis valider par une capture au zoom réel.
