# Cartes 3D (v2) : note de passation

Rédigée le 14 novembre 2026 par la session qui a construit les cartes 1 à 5, pour la session « Cartes » qui reprend
la conception des niveaux. Guide général de la v2 : `docs/PREMIER_JET_3D.md`.

## Méthode de construction

- Un niveau = une sous-classe de `DraftLevel` (`draft3d/level.gd`), un fichier `draft3d/level_<nom>.gd`, assemblé
  **en code** dans `build()` (pas de scène `.tscn` par niveau, pas d'éditeur). Il se branche dans le `match` de
  `DraftLevel.create(order)` (numéro de chapitre).
- `build()` règle `bounds_min/max`, `start`, `boss_spot`, l'ambiance (`sky`, `ambient`, `sun`, `sun_energy`), pose
  le sol (`_box`), les quartiers, puis appelle `_setup_navigation()`. `_spawn_candidates()` donne les points
  d'apparition du pourtour (gardés s'ils tombent à moins de 1,5 m de la navigation).
- Deux façons de poser un décor :
  - `_module(id, at, size, yaw)` : scènes `draft3d/modules/*.tscn` (13 pièces du donjon, avec leur
    collision exacte : murs, porte `wall_doorway` ouverte, `stairs_wide`, torche, etc.) ;
  - `_prop(path, at, yaw, size, collision, centered)` : glTF/GLB d'un pack importé tel quel. Collision calculée :
    `"box"` (boîte englobante), `"trunk"` (cylindre de tronc), `"none"`. `centered = true` pose la pièce par le
    centre de son emprise (indispensable : beaucoup de pièces ont leur origine décalée).
- Autres aides : `_fence(at, size, walk_only)` (paroi invisible ; `walk_only` = couche 8, n'arrête que la marche),
  `_torch`, `_light`.
- Les 13 scènes de `draft3d/modules/` viennent du prototype de Codex `prototypes/kaykit_relief/` : son
  `build_modules.gd` les reconstruit depuis les GLB (rampe de collision sous l'escalier, battant de `wall_doorway`
  retiré, collisions d'abris) ; voir son `README.md`. Il n'existe pas de catalogue des pièces : pour connaître
  l'emprise d'une pièce d'un pack, je la mesurais par un script jetable (`godot --headless -s`, fusion des AABB
  des `MeshInstance3D`).
- Packs KayKit (CC0), clonables par `git clone https://github.com/KayKit-Game-Assets/<nom>.git` : Dungeon
  Remastered (`draft3d/kaykit/`, modules), Halloween Bits (`draft3d/halloween/`), Medieval Hexagon
  (`draft3d/medieval/`), Space Base Bits (`draft3d/spacebase/`). Dans le pack donjon les fichiers s'appellent
  `<nom>.gltf.glb`. Ne copier que les pièces utilisées, avec la licence. Réimporter ensuite
  (`godot --headless --import --path .`).

## Échelle et hauteurs

- 1 unité = 1 m ; le Chasseur fait environ 1,6 m ; caméra orthographique fixe au sud, inclinée (offset (0, 18, 17)).
- Cartes de 92 à 96 m × 56 à 64 m. Passages : 4 à 7 m (2 m est le strict minimum ; rayon d'agent 0,4 m).
- Murs du donjon : 4 × 4 × 1 m. Un mur haut au sud cache environ 4 m de jeu derrière lui : limite sud basse.
- Terrasses à 2 m : dalle `_box` + `_module("stairs_wide", …, Vector3(1, 0.5, 1.5))`, deux accès au moins.
  La pièce `stairs` du pack (5 m de haut sur 4 m) est trop raide pour la navigation (pente max 48°, marche 0,3 m).
- Règles de jeu liées au relief : mêlée et contact à 1 m de dénivelé au plus, zones annoncées à 1,2 m.
- Échelle des packs : donjon 1, Halloween 1, médiéval × 5, base spatiale × 4 (miniatures).
- Pas de cul-de-sac : tout quartier a deux issues.

## Collisions et navigation

- Couche 1 : décor plein (arrête marche, vue, tirs ; sert aussi à la navigation). Couche 8 : marche seulement
  (berges). Le Chasseur est sur la couche 4, masque 1 | 8.
- « On touche ce que l'on voit » : `run.sight_clear()` (rayon sur le masque 1) filtre tirs, sorts et dégâts ; les
  ondes en anneau s'éteignent tronçon par tronçon sur le décor. Valable pour toute carte sans rien ajouter, à
  condition que les obstacles aient une collision de couche 1.
- Navigation cuite au lancement (`bake()`, colliders statiques, cellule 0,2 m) ; les ennemis n'ont pas de corps et
  suivent `level.path()`. Un objet au milieu d'une pièce étroite peut la couper du reste : le vérifier par un essai.
- Les limites sont toujours une paroi `_fence` doublée d'un décor visible.
- Un sol décoratif (dalles) se pose avec `"none"` à y = 0,01 ; en dessous de 0 il est caché par le sol.

## Niveaux existants

| Ch. | Fichier | Carte | État |
|---|---|---|---|
| 1 | `level_ruins.gd` | Ruines des Veilleurs (donjon) | dans `main`, validée ; seconde passe de détail à faire |
| 2 | `level_graveyard.gd` | Cimetière des Cendres (Halloween, nuit) | dans `main` ; seconde passe à faire |
| 3 | `level_village.gd` | Hameau du Gué (médiéval, rivière, 3 ponts) | dans `main` ; seconde passe à faire |
| 4 | `level_outpost.gd` | Avant-poste des Glaces (base spatiale) | dans `main` ; **hors DA à mon avis** (science-fiction), question posée au propriétaire, sans réponse |
| 5 | `level_city.gd` | Cité Effondrée (ruines, pack donjon, nuit) | recomposée le 15 novembre (plan en damier), contrôle sans incohérence ; à valider en jeu |
| 7 | `level_pass.gd` | Défilé Hurlant (gorge longue, rochers modelés, pack médiéval) | ébauche montrée le 16 novembre ; lancé par `--chapter=7` en attendant le chapitre 7 |
| 8 | `level_marsh.gd` | Marais des Marées (îlots, levées, marée) | premier jet du 16 novembre ; `--chapter=8` en attendant le chapitre 8 |
| 6 | `level_ring.gd`, `tower.gd` | Tour de la Faille : Garnison, Cellules, Anneau de la Faille (sommet) | sommet validé sur vue d'ensemble ; tour jouable par `--chapter=6` en attendant le chapitre 6 |

Niveau 5 : une première version « ville moderne » (KayKit City Builder, voitures) a été refusée, hors DA et hors
époque, puis supprimée. La seconde, la Cité Effondrée, a été jugée **incohérente** par le propriétaire. Audit du
15 novembre (session « Cartes », outil ci-dessous et captures) :
- deux piliers du cercle du forum encastrés dans le grand escalier de l'acropole ;
- escalier est débouchant dans un vide sans destination (ni rue ni temple), entre deux piliers isolés ;
- 5 m² de l'acropole coupés du reste par un éboulis ; un point d'apparition dans le décor, au pied de l'acropole ;
- maisons en carrés de murs sans alignement de rue, dallage en croix posé sur le sol nu, dalles isolées ;
- arche debout seule au milieu de l'avenue, fragments (murs, colonnes, éboulis) dispersés sans logique ;
- acropole nue, de la couleur du sol : on ne la distingue pas ; hiérarchie illisible (rien ne désigne l'arène).

Recomposition (même thème, mêmes pièces, même ambiance) : plan en damier lu depuis la porte sud — Avenue pavée bordée
de façades → Forum entièrement dallé (arène du boss, colonnes d'abri, portiques) → grand escalier encadré de piliers →
Acropole dallée (colonnade, arches). Rue transversale d'est en ouest ; Voie sacrée pavée du decumanus au pied de
l'escalier est, le long du Temple. Maisons de 8 × 8 m alignées sur les rues, portes donnant sur une rue, murs brisés
avec leurs éboulis à côté, une maison effondrée par quartier. Captures avant/après et cartes de navigation :
`docs/previews/cartes-3d/` (`carte_5_*_avant|apres.webp`, `navigation_5_avant.webp`, `navigation_5_bot.webp`).

## Carte 6 : l'Anneau de la Faille, sommet de la tour (16 novembre)

Commande du propriétaire : une carte différente des autres par sa forme, sa taille et sa composition, sans
« terrasse + escalier ». `draft3d/level_ring.gd`, 100 × 100 m, ronde :
- couronne de terre (rayons 28 → 46,5 m) autour d'un gouffre ; au centre, un îlot de 20 m de rayon (lieu du boss,
  quatre piliers d'abri seulement, deux cercles pavés), relié par deux passerelles de 5 m (210° et 330°) ;
- trois murs radiaux (30°, 150°, 270°) percés d'une brèche de 4 m : la Porte (sud, départ), l'Ossuaire (ouest :
  contreforts et niches à bougies, sarcophages, murs effondrés), les Forges (est : établis, fûts, caisses, foyers) ;
- chemin de ronde pavé (rayon 36 m) ; rempart circulaire, parapet bas au sud ;
- le relief est le vide : ses bords (parois `_edge`, couche 8) arrêtent la marche, pas les tirs ; lueurs violettes
  sous les rebords pour lire le contour. Pour gagner l'îlot, on fait le tour (brèche puis passerelle).
- Construction : dalles en prisme convexe (`_slab`, collision par secteur de 5°, un seul maillage pour l'anneau),
  pièces posées en coordonnées polaires (`polar`, `tangent_yaw`, `radial_yaw`) ; les points d'apparition s'écartent
  de 3,5 m des décors pleins.
- Captures : `docs/previews/cartes-3d/carte_6_*.webp` ; navigation : `navigation_6.webp`.

### La tour du chapitre 6 (16 novembre, construite)

Le chapitre 6 est une tour de trois étages joués à la suite dans la même partie (`draft3d/tower.gd`, `DraftTower`) ;
chaque étage est un `DraftLevelRing` (`floor_index`), l'Anneau ci-dessus en est le sommet.

| Étage | Nom (FR/EN) | Murs radiaux | Rampe (pied → haut) | Arrivée |
|---|---|---|---|---|
| 0 | la Garnison / the Garrison | 0°, 180° | 240° → 276° (nord) | Porte sud (départ) |
| 1 | les Cellules / the Cells (gardien) | 20°, 160°, 230°, 330° | 140° → 102° (sud-ouest) | porte nord (281°) |
| 2 | le Sommet / the Summit (Dévoreur) | 30°, 150°, 270° | aucune | Porte sud (90°) |

- Étages inférieurs : anneau extérieur seul, puits ouvert au centre (ni îlot ni passerelle), décor propre (Garnison :
  tables, fûts, caisses d'abri ; Cellules : niches, murs de cellules effondrés, éboulis).
- **Rampe** (pas d'escalier) : tronçon de l'anneau en pente douce (3 m sur environ 28 m) le long du rempart, palier
  de 10° en haut, porte éclairée dans le rempart (`exit_point`). Une herse au pied (paroi de marche seulement : la
  navigation passe, les monstres se faufilent) la ferme jusqu'à la fin de l'étage.
- **Fin d'étage à la durée** (option A) : `tower_floor_time` (180 s) après l'arrivée, la herse se lève (bannière
  « La herse se lève : montez par la rampe ! ») ; à l'étage des Cellules, il faut aussi avoir vaincu le gardien, qui
  apparaît `tower_guardian_delay` (45 s) après l'arrivée. Atteindre le palier fait monter d'un étage.
- **Sommet** : le Dévoreur apparaît à `boss_time` (8 min), jamais moins de `tower_boss_delay` (30 s) après l'arrivée.
- **Changement d'étage** (`DraftRun.change_level`) : le Chasseur garde niveau, améliorations, sorts et PV ; les
  cristaux restants sont acquis ; ennemis, attaques annoncées et projectiles de l'étage quitté disparaissent ; le
  temps de partie est suspendu pendant la construction et la cuisson de la navigation.
- Réglages : `draft3d/tuning.tres` (groupe « Tour du chapitre 6 »). Vérification : `--chapter=6 --tower-floor=1`
  (partir d'un étage). Le bot monte seul quand la rampe s'ouvre.
- Contrôle : chaque étage passe `DraftLevelAudit`, qui vérifie aussi que le palier de sortie est atteignable depuis
  l'arrivée (`tools/level_audit.tscn -- --chapters=6.0,6.1,6`) ; essai `test_tower_floors_climb_to_the_summit`
  (herse fermée, montée par le bot, gardien, sommet, Dévoreur).
- Captures : `docs/previews/cartes-3d/tour_*.webp` ; navigation : `navigation_6_0.webp`, `navigation_6_1.webp`.
- Reste : raccorder le chapitre 6 (données, nom FR/EN, bestiaire, déblocage après le chapitre 5, palette du rendu
  pixel avec la session « Art et rendu ») ; d'ici là, `--chapter=6` joue la tour avec le bestiaire du chapitre 5.

## Carte 7 : le Défilé Hurlant (16 novembre)

Commande du propriétaire : « dans la même optique », une carte différente des autres. Option A retenue (la plus
longue et la plus étroite) : `draft3d/level_pass.gd`, 170 × 28 m, que la caméra suit d'ouest en est.
- Gorge entre une haute falaise au nord et un rebord de rochers bas au sud (côté caméra) ; ni étage ni escalier.
- Quatre goulets (`NECKS`) : murs de roche qui ferment la gorge sauf leurs passages (5 à 6,5 m) ; deux goulets
  doubles (rocher au milieu, deux passages : pas de cul-de-sac, on contourne la horde), deux simples (côté sud, puis
  côté nord). Torche à l'entrée de chaque goulet.
- Cinq clairières : Campement (départ), Carrière, Cirque (la plus grande, bosquets d'abri), Tour brisée, Arène des
  Pierres levées (cercle de menhirs ouvert vers le goulet, lieu du boss, lueur de la Faille).
- Rochers modelés (`_rock`, `_massif` : prismes convexes à sommet réduit, collision pleine) marqués « décor » : leur
  sommet n'est pas une zone (DraftLevelAudit les ignore comme relief). Pack nature KayKit inaccessible depuis le
  conteneur : arbres, tentes, caisses et ruine viennent du pack médiéval (× 5). Prismes `_slab` et maillages
  `_mesh_of` désormais dans `DraftLevel` (partagés par l'Anneau et le Défilé).
- Contrôle : sans incohérence ; essai `test_seventh_level_pass` (passages ouverts, arène atteinte, roche qui coupe la
  vue, falaise qui tient). Captures : `docs/previews/cartes-3d/carte_7_*.webp`, `navigation_7.webp`.
- Reste : raccordement du chapitre 7 (nom, bestiaire, déblocage, palette) ; d'ici là, `--chapter=7` joue avec le
  bestiaire du chapitre 5.

## Carte 8 : le Marais des Marées (16 novembre)

Option A retenue par le propriétaire : la seule carte qui change pendant la partie. `draft3d/level_marsh.gd`,
90 × 90 m : huit îlots (départ au sud, sanctuaire du boss au centre) reliés par des levées de terre dans une eau
trouble ; ni étage ni escalier.
- **Levées hautes** (au niveau des îlots) : jamais noyées ; elles font le grand tour par l'ouest et l'est jusqu'aux
  îlots du nord, puis au sanctuaire. **Levées basses** (25 cm plus bas, couleur terre claire) : raccourcis (sud →
  sanctuaire, ouest et est → sanctuaire, entre les petits îlots, entre les îlots du nord).
- **Marée** (cycle de 80 s : basse 50 s, montée 8 s, haute 16 s, descente 6 s) : l'eau passe de −0,35 à +0,14 m et
  couvre les levées basses. Bandeaux « La marée monte… » / « La marée se retire… » (FR/EN). À marée haute :
  - une levée noyée sort de la navigation, recalculée en tâche de fond (les monstres font le tour) ;
  - ses deux barrières (parois de marche) se ferment dès que le Chasseur n'est plus dessus : il n'y entre plus, mais
    n'y est jamais piégé ;
  - l'eau n'arrête ni la vue ni les tirs ; le sanctuaire ne s'atteint plus que par le nord.
- Rives : parois de marche calculées sur le contour de la terre (`_shores`), sans gêner la vue. Le fond n'a pas de
  collision (la navigation ne s'y pose pas).
- Vérification : `--chapter=8 --tide-at=61` (partir à marée haute) ; `set_tide(true/false)` pour les essais. Essai
  `test_eighth_level_marsh_tide` (chemin direct à marée basse, détour par le nord à marée haute, contrôle de
  composition à marée haute, levée fermée puis traversable, tir par-dessus l'eau, cycle).
- Animation de l'eau (ébauche) : plan transparent qui monte et descend. Pour une marée qui se lit parfaitement :
  textures et boucles animées en pixel art par Codex (prompt n° 3 de `docs/prompts/CODEX_EN_ATTENTE.md`), shader de
  l'eau (rides, écume le long des rives, vase mouillée après le retrait) par la session « Art et rendu » ; le moteur
  de compatibilité n'offrant pas la profondeur, la ligne d'écume se calculera à partir du contour des terres
  (`_land`), connu de la carte.
- Correctif commun : `DraftLevel._slab` oriente toujours ses polygones dans le même sens (le rendu pixel élimine les
  faces vues de dos) ; les passerelles de l'Anneau, sombres jusque-là, s'affichent enfin.
- Captures : `docs/previews/cartes-3d/carte_8_*.webp`, `navigation_8.webp`.

## Règles de composition

1. **Lecture du parcours** : départ → rue principale → zones → arène finale. L'arène (lieu du boss) est la place la
   plus grande et la mieux dallée, au bout de l'axe qui part du départ ; le relief la domine.
2. **Escaliers** : chaque escalier relie deux surfaces praticables (pied au sol, palier sur la dalle à sa hauteur) et
   prolonge un chemin : il part d'une rue ou d'une place et arrive sur une terrasse où l'on a une raison d'aller.
   Rien à moins de 0,7 m de son pied ni de son palier ; aucun décor dans son emprise visible (le module fait 7 m de
   large pour 5,6 m de collision). Toute terrasse praticable a deux escaliers au moins.
3. **Pas de module flottant ni enterré** : un décor repose sur le sol, sur une dalle ou s'accroche à un autre décor
   (bannière, applique) ; pas de décor plein encastré dans un autre (piliers dans un escalier, caisse dans un mur).
4. **Architecture plausible** : murs alignés sur une grille (4 m pour le pack donjon), bâtiments fermés sur leurs
   angles, ouvertures sur une rue ; ruine = mur brisé ou pan resté debout avec ses éboulis à côté ; pavage continu le
   long des rues (pas de dalles isolées sur le sol nu, sauf usure).
5. **Navigation** : toute zone atteignable depuis le départ, pas de cul-de-sac, passages de 2 m au moins (4 à 7 m
   pour les rues). La porte `wall_doorway` du donjon est trop étroite pour la navigation (rayon d'agent 0,4 m) : une
   porte de maison est un pan de 2 m (`wall_half`) et 2 m d'ouverture. Un éboulis ou une caisse devant une ouverture
   la bouche : les poser contre un mur, à l'intérieur.
6. **Combat** : abris (piliers, murets, caisses) dans les places et sur les rues larges, jamais en travers d'un
   passage étroit ; le lieu du boss reste dégagé dans un rayon de 6 m.
7. **Apparitions** : points sur le pourtour, sur la navigation, atteignables, hors des murs.

## Contrôle automatique

`DraftLevelAudit` (`draft3d/level_audit.gd`), sur une carte construite et cuite, vérifie les règles 2, 3, 5 et 7 :
escaliers (palier et pied sur une surface à la bonne hauteur, praticables, reliés par un chemin court), deux accès par
terrasse praticable, décors flottants / enterrés dans le relief / encastrés (≥ 20 % de l'emprise), surfaces
praticables isolées (≥ 4 m², hors dessus de décor), départ, boss et apparitions (navigation, accès, hors décor).
- Outil : `godot --headless --path . res://tools/level_audit.tscn -- --chapters=1,2,3,4,5 --out=<dossier>` écrit
  `navigation_<n>.png` (gris : praticable selon la hauteur ; rouge : zone isolée ; brun : dessus de décor ;
  traits verts/rouges : escaliers pied → palier ; points bleus : apparitions ; vert : départ ; violet : boss ;
  croix rouges : incohérences). `--bot-seconds=120 --bot --god` ajoute le parcours du bot (orange).
- Essai : `test_level_composition_audit` (`tests/unit/test_draft3d.gd`) : zéro incohérence sur la carte 5 ; pour les
  cartes 1 à 4, le nombre relevé ci-dessous ne doit pas augmenter (`KNOWN_ISSUES`, à baisser à chaque correction).
- Limites : l'outil ne juge pas la lisibilité ni la plausibilité (règles 1, 4, 6) : vue d'ensemble et captures.

### Incohérences relevées sur les cartes 1 à 4 (15 novembre, non corrigées, en attente de validation)

Cartes de navigation : `docs/previews/cartes-3d/navigation_<n>.webp`.
- **Carte 1, Ruines** (8, puis 4 au 16 novembre après des retouches d'une autre session) : petite terrasse d'angle à
  un seul escalier ; deux barrières du rebord de la terrasse à cheval sur le vide (±8, z −11,5) ; une porte encastrée
  dans un mur (1, 20,5).
- **Carte 2, Cimetière** (2) : un sapin enterré dans le tertre (−38, −28) ; une lanterne dans un sapin (30, 10).
- **Carte 3, Hameau** (40) : cinq arbres qui se chevauchent ou traversent la tour de guet (26–30, −13 à −19) ; trois
  points d'apparition dans le décor ou inaccessibles (−20, −30), (−4, 31), (4, 30). À vérifier, probablement faux
  positifs : 19 arbres « enterrés » dans les berges et 11 rochers de la rivière « flottants » ou dans un pont (le lit
  de la rivière n'a pas de sol de collision).
- **Carte 4, Avant-poste** (14, puis 13 au 16 novembre : le tunnel ne flotte plus) : **escalier est du plateau bouché à son pied par des rochers** (14, −25,5) : le
  plateau n'a donc qu'un accès ; camion et remorque enfoncés dans la banquise (11–15, 27–28) ; tunnel à 0,8 m
  au-dessus du sol (0, −4) ; caisses encastrées dans des conteneurs ou des rochers (−25, −24,5), (−22, −12,5) ;
  trois points d'apparition dans le décor (−24, −30), (44,5, 22 et 26).

## Pièges rencontrés

- Proposer le thème et montrer une vue d'ensemble **avant** de détailler une carte (deux cartes 5 refusées).
- Pièces à origine décalée traversant murs et bâtiments (carte 3) : `centered = true`.
- `wall_arched` du pack donjon est un mur plein à relief, pas une arche ouverte : pour passer, `wall_doorway`.
- Aucun objet de la v1 dans le décor (autel, piliers de barrière) : uniquement des modules de packs.
- Bâtiments hauts au sud du départ : ils cachent le Chasseur.
- Pack aux mauvaises couleurs (roches rouges de la base spatiale) : matériau de remplacement par surface.
- Rendu logiciel dans le cloud : captures lentes ; une image suffit
  (`--chapter=N --overview` ou `--look=x,z --shots=<dossier> --shot-times=1 --quit-after-shots --bot --god --passive`).
- Chaque carte a son essai dans `tests/unit/test_draft3d.gd` (points d'apparition, quartiers reliés, montée de la
  terrasse, limites tenues, abris qui coupent la vue) : copier celui de la carte 4.
- L'équilibrage n'est pas à faire sur les cartes : le propriétaire teste lui-même.

## Reste à faire

- Carte 5 : validation en jeu de la recomposition (15 novembre).
- Chapitre 6 : raccordement (données, nom, bestiaire, déblocage, palette) ; la tour est en place.
- Cartes 1 à 4 : corriger les incohérences relevées ci-dessus (après validation du propriétaire).
- Décision sur la carte 4 (hors DA ?).
- Seconde passe de détail sur les cartes 1 à 4.
- Sols : textures répétables peintes par Codex (prompt à rédiger), à la place des sols unis.
