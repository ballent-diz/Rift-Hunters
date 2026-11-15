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
- **Carte 1, Ruines** (8) : petite terrasse d'angle à un seul escalier ; quatre barrières du rebord des terrasses
  posées à cheval sur le vide (−8 / 8 / 35 / 45, z −11,5) ; une porte encastrée dans un mur (1, 20,5) ; deux points
  d'apparition inaccessibles au pied des escaliers latéraux de la terrasse (±14, −19).
- **Carte 2, Cimetière** (2) : un sapin enterré dans le tertre (−38, −28) ; une lanterne dans un sapin (30, 10).
- **Carte 3, Hameau** (40) : cinq arbres qui se chevauchent ou traversent la tour de guet (26–30, −13 à −19) ; trois
  points d'apparition dans le décor ou inaccessibles (−20, −30), (−4, 31), (4, 30). À vérifier, probablement faux
  positifs : 19 arbres « enterrés » dans les berges et 11 rochers de la rivière « flottants » ou dans un pont (le lit
  de la rivière n'a pas de sol de collision).
- **Carte 4, Avant-poste** (14) : **escalier est du plateau bouché à son pied par des rochers** (14, −25,5) : le
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
- Cartes 1 à 4 : corriger les incohérences relevées ci-dessus (après validation du propriétaire).
- Décision sur la carte 4 (hors DA ?).
- Seconde passe de détail sur les cartes 1 à 4.
- Sols : textures répétables peintes par Codex (prompt à rédiger), à la place des sols unis.
