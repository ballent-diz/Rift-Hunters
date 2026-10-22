# Monstres, élites et boss : planches et mécaniques

Statut : **règle validée par le propriétaire le 22 octobre 2026**, valable à partir du chapitre 2 et pour tous les
chapitres suivants. Le chapitre 1 garde ses sprites et ses animations actuels : c'est le début du jeu.
Cadre : [CARTES.md](CARTES.md) (familles par chapitre, briques de terrain), [../ART_BIBLE.md](../ART_BIBLE.md)
(style des planches), [../../assets/concepts/incoming/README.md](../../assets/concepts/incoming/README.md) (import).

## Principe

- **Les monstres de base restent simples** : déplacement et attaque. Ils font nombre ; leur lisibilité prime.
  Quelques exceptions par famille reçoivent **une** technique dessinée (bond, plongée…).
- **Les élites et les boss sont plus fournis** : chacun a des **techniques propres**, dessinées sur des planches
  dédiées, qui portent une **mécanique** (un comportement de jeu, pas seulement une animation).
- **Progression continue** : la difficulté et l'apparition de nouvelles mécaniques augmentent sans palier plat, d'une
  carte à l'autre et d'un chapitre à l'autre (voir « Montée en puissance »).
- **Rien n'est dessiné pour rien** : chaque rangée d'une planche correspond à une animation jouée en jeu. Une
  animation prévue sans mécanique codée n'est pas commandée.

Piste en attente : donner le Saut et le Tunnel (E1, E2) à quatre élites du chapitre 1, décision reportée au test
complet du chapitre 1 (voir `docs/ROADMAP.md`, « À décider lors du test complet du chapitre 1 »).

## Planches par rang

Toujours **6 colonnes** ; une planche fait **2 ou 3 rangées au maximum** (le générateur d'images est plus fiable). Un
monstre peut avoir plusieurs planches : le `job.json` liste chaque animation avec sa source et sa rangée. Toutes les
planches d'un monstre sont générées avec la planche A en référence, pour garder l'identité.

| Rang | Planche A | Planches suivantes | Mort |
|---|---|---|---|
| Normal | 6 × 2 : déplacement, attaque | — (exception « + technique » : planche A en 6 × 3, rangée 3 = la technique) | effet commun de dispersion, teinté selon la famille |
| Élite | 6 × 3 : déplacement, attaque, mort | B en 6 × 2 : technique 1, technique 2 (puis C à partir du chapitre 3, voir plus bas) | dessinée |
| Boss (Dévoreur) | 6 × 3 : idle, déplacement, attaque de base | 3 à 5 planches : techniques de chaque phase, transformation, mort | dessinée |

- Chaque technique se lit **anticipation lisible → action → retour**.
- Les effets dessinés font partie du corps ou en partent (flammes de la gueule, gerbe au sol de l'impact). **Les
  cercles d'alerte et les zones au sol sont dessinés par le jeu**, jamais dans la planche.
- Les gardiens de fin de carte réutilisent une élite agrandie avec ses techniques ; aucune planche en plus.

## Catalogue des mécaniques ennemies

Codées une fois, réglées en données dans la fiche du monstre (comme les briques de terrain) ; une élite en combine
deux, un boss davantage. Le chapitre indique la première apparition.

| # | Mécanique | Ce qu'elle demande au joueur | Apparition |
|---|---|---|---|
| E1 | **Bond** : saut télégraphié sur la position du Chasseur, au-dessus des foules, dégâts à l'atterrissage | ne pas fuir en ligne droite, Ruée au bon moment | chapitre 2 (normal) |
| E2 | **Enfouissement** : disparaît sous terre, traînée visible, ressort sous le Chasseur | rester en mouvement | chapitre 2 (normal) |
| E3 | **Sol brûlant laissé derrière soi** : plaque temporaire qui blesse | se repositionner, y attirer les hordes | chapitre 2 |
| E4 | **Ponte** : œufs qui éclosent si on ne les casse pas à temps | choisir ses cibles | chapitre 2 |
| E5 | **Projectile entravant** : toile, glue, gel qui ralentit fortement | esquiver plutôt que tanker | chapitre 2 |
| E6 | **Charge en ligne + coup final** : ligne télégraphiée puis attaque circulaire | sortir de l'axe, puis de la zone | chapitre 2 |
| E7 | **Rage** : sous 50 % de PV, plus rapide et plus dangereux (aspect changé) | finir vite ou garder ses sorts | chapitre 2 |
| E8 | **Armure + fenêtre de faiblesse** : dégâts réduits sauf pendant une ouverture après une technique | frapper au bon moment | chapitre 2 |
| E9 | **Envol et piqué** : intouchable en l'air, ombre au sol, retombe sur un point marqué | lire l'ombre | chapitre 2 |
| E10 | **Cône de souffle** | contourner par le flanc | chapitre 2 |
| E11 | **Invocation de petits** | nettoyer avant qu'ils s'accumulent | chapitre 1 (couveuse) |
| E12 | **Mue** : perd son armure à mi-vie, laisse une flaque, devient plus rapide | changer de rythme | chapitre 2 |
| E13 | **Rayon qui balaie** | se placer derrière un abri | chapitre 2 (boss) |
| … | Pistes : bouclier pour ses alliés, vol de vie, reflet de projectiles, téléportation en chaîne, marque qui explose, clones, contrôle du terrain (geler, inonder) | | chapitres 3 à 5 |

Règles : tout est **télégraphié** ; une mécanique a un **temps de recharge** et une **portée minimale** (pas de
répétition au contact) ; elle doit offrir une **occasion** (fenêtre de faiblesse, ennemis pris dans la zone), pas
seulement une punition.

## Montée en puissance

### D'un chapitre à l'autre

| Chapitre | Normaux avec technique | Élites | Boss | Nouvelles mécaniques |
|---|---|---|---|---|
| 1 (actuel) | aucun (comportements de base : chasseur, tireur, chargeur, invocateur, clignoteur, gardien) | attaque de base + affixes | 2 phases | — |
| 2 | 1 par famille | 2 techniques | 2 phases, 4 planches | E1 à E13 en grande partie |
| 3 | 1 à 2 par famille | 2 techniques + 1 trait passif (aura, réaction aux dégâts) ; planche C pour le trait si visible | 3 phases | 3 ou 4 nouvelles, et anciennes **combinées** autrement |
| 4 | 2 par famille | 3 techniques, enchaînables en combo | 3 phases, attaques combinées | 3 ou 4 nouvelles |
| 5 | 2 ou 3 par famille | 3 techniques + trait passif ; certaines élites en duo | 3 phases + phase finale | dernières mécaniques ; finale qui reprend le meilleur des chapitres |

Les mécaniques déjà vues reviennent dans les chapitres suivants **sous un autre habillage ou dans d'autres
combinaisons** (le bond du chien de suie devient le saut d'un loup des glaces qui gèle à l'atterrissage).

### À l'intérieur d'un chapitre (5 cartes)

- **Carte 1** : la nouvelle famille avec ses normaux simples et **une** élite ; ses mécaniques sont présentées seules.
- **Cartes 2 et 3** : les autres élites arrivent, une ou deux mécaniques nouvelles par carte ; les normaux à
  technique apparaissent.
- **Carte 4** : toute la famille, élites en même temps, mécaniques combinées.
- **Carte 5** : finale du chapitre, deuxième famille plus forte (comme les Hautes Terres au chapitre 1) et Dévoreur.
- Les forces des ennemis (PV, dégâts, cadence des vagues) suivent cette même pente ; `enemy_hp_mult` et
  `enemy_damage_mult` des arènes corrigent une famille trop forte ou trop faible pour sa place.

## Application au chapitre 2 « Les Terres dévastées »

Familles et descriptions complètes : prompt Codex du 22 octobre (conservé dans les `job.json` de chaque monstre).

| Famille | Normaux | Normal à technique | Élites (technique 1 / technique 2) |
|---|---|---|---|
| Calcinés (cartes 6 à 8) | Rampe-cendre, Chien de suie, Golem de charbon, Feu-fumée | Chien de suie : **Bond** (E1) | Brute du bûcher : Bûcher écrasé (E3) / Rage du brasier (E7) ; Veuve de cendre : Ponte (E4) / Toile de suie (E5) ; Chevalier calciné : Charge (E6) / Taille tournoyante (E6) |
| Enfants du magma (cartes 9 et 10) | Acarien de magma, Rôdeur de lave, Brute d'obsidienne, Cracheur de braise | Rôdeur de lave : **Plongée** (E2) | Titan de caldeira : Éruption (E3) / Cratère ouvert (E8) ; Wyvernette : Souffle (E10) / Piqué (E9) ; Matrone des scories : Couvée (E11) / Mue (E12) |

Dévoreur **Pyrevorn** (carte 10) : planche A (idle, déplacement, griffes), B phase 1 (souffle de magma, pluie du
cratère, appel de la couvée), C (transformation, mort), D phase 2 (idle, envol et chute avec anneaux de lave, Œil de
la Faille : rayon qui balaie, E13).

Ordre d'introduction : carte 6 Brute du bûcher (sol brûlant, en écho aux plaques de la carte) ; carte 7 Chevalier
calciné et Chien de suie ; carte 8 Veuve de cendre (avec les nids de la carte) ; carte 9 Enfants du magma, Titan et
Rôdeur ; carte 10 Wyvernette, Matrone et Pyrevorn.
