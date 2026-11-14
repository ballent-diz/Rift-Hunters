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
| 5 | `level_city.gd` | Cité Effondrée (ruines, pack donjon, nuit) | **branche `claude/carte-5`, non fusionnée, sans PR** |

Niveau 5 : une première version « ville moderne » (KayKit City Builder, voitures) a été refusée, hors DA et hors
époque, puis supprimée. La seconde, la Cité Effondrée, passe les tests (liaisons, acropole, limites, abris) mais le
propriétaire la juge **incohérente** au vu de la vue d'ensemble (`docs/previews/premier-jet-3d/carte_5.webp` sur la
branche). Mon diagnostic, non confirmé par lui : maisons = pans de mur en carré sans alignement de rue ; pavage en
croix posé sur un sol nu, dalles isolées, rectangle clair au temple ; fragments (murs, colonnes, éboulis) dispersés
sans logique ; acropole nue. Piste proposée : enceinte, rues pavées bordées de façades continues, îlots fermés à
cours, place centrale entièrement dallée, temple complet sur l'acropole. En attente de sa réponse. Tant que la
branche n'est pas fusionnée, le chapitre 5 joue sur la carte 1.

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

- Carte 5 : reprise selon la réponse du propriétaire, puis PR.
- Décision sur la carte 4 (hors DA ?).
- Seconde passe de détail sur les cartes 1 à 4.
- Sols : textures répétables peintes par Codex (prompt à rédiger), à la place des sols unis.
