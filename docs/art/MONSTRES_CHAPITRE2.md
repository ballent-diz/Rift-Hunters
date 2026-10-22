# Monstres du chapitre 2 — première famille

## Livraison et validation

Les sept Calcinés ont été validés par le propriétaire le 22 octobre 2026, conformément à sa révision.
Les Enfants du magma peuvent être réalisés ; Pyrevorn suivra après cette deuxième famille. Les règles,
statistiques, données de monstres, textes de jeu et raccordements restent à Claude.

Le Dévoreur des Sources du chapitre 1 est un complément demandé pendant ce lot : son apparence
a été explicitement validée par le propriétaire. Son identifiant visuel proposé est
`boss.source_devourer` ; aucun identifiant de gameplay n’est créé.

## Calcinés : contrat des animations

Chaque animation compte six poses. Déplacement : 10 images/s en boucle ; autres : 12 images/s,
sans boucle. `idle` réutilise le déplacement. Aucun statut ni effet de gameplay n’est créé.

| Visuel | Nom FR / EN | Hauteur du modèle | Animations |
|---|---|---:|---|
| `enemy.cinder_crawler` | Rampe-cendre / Cinder Crawler | 30 | `move`, `attack` |
| `enemy.ash_hound` | Chien de suie / Soot Hound | 38 | `move`, `attack`, `leap` |
| `enemy.char_golem` | Golem de charbon / Char Golem | 40 | `move`, `attack` |
| `enemy.smoke_wisp` | Feu-fumée / Smoke Wisp | 36 | `move`, `attack` |
| `enemy.pyre_brute` | Brute du bûcher / Pyre Brute | 49 | `move`, `attack`, `death`, `pyre_slam`, `blazing_rage` |
| `enemy.ashen_widow` | Veuve de cendre / Ashen Widow | 46 | `move`, `attack`, `death`, `lay_eggs`, `soot_web` |
| `enemy.cinder_knight` | Chevalier calciné / Cinder Knight | 50 | `move`, `attack`, `death`, `charge`, `spinning_slash` |

Les normaux n’ont aucune animation de mort dessinée : Claude utilisera la dispersion commune.
Une seule pose runtime entièrement transparente, nommée `death`, masque le corps pendant cet
effet et maintient la compatibilité avec le registre actuel qui exige ce nom. Elle est déclarée
par `empty_animations` dans le job ; les planches source restent à deux rangées (trois pour le Bond).
La source initiale du Rampe-cendre conserve sa troisième rangée historique, inutilisée.
Le prototype magma n’appartient pas à cette livraison.

Les cellules runtime de 256 × 256 et l’ancre `[128, 238]` réservent de la marge aux techniques.
Leur espace vide n’agrandit pas le monstre : `scale = 0.5`, et la hauteur cible d’import est le
double de `height`, suivant le conditionnement des Hautes Terres. Chaque animation d’un monstre
partage le même facteur de réduction ; les poses de mort ne sont pas agrandies individuellement.
Le Feu-fumée flotte de 10 pixels d’art au-dessus de l’ancre.

Les fragments d’autres cellules coupés aux bords de grille sont retirés des bandes techniques
par `tools/art/clean_sprite_gutters.py`, sans modifier les sources ni les poses principales.
Les bandes C/E du Dévoreur sont normalisées à ×1,23 pour retrouver l’échelle corporelle de A/B/D
après la retouche qui a raccourci leurs effets. Ce facteur est conservé dans `source_scale`.

Les techniques dessinées sont des supports de raccordement : les dégâts, déplacements du bond,
invocations, plaques brûlantes, ralentissements et changements de phase seront calculés par le jeu.
Le retournement des sprites reste à la charge du moteur.

## Dévoreur des Sources

Quinze animations de six poses, soit 90 poses :

| Source | Animation | Déclenchement prévu |
|---|---|---|
| A | `move` | Marche lourde |
| A | `attack` | Attaque de base |
| A | `death` | Effondrement et extinction du cœur |
| B | `idle` | Respiration et pulsation du cœur |
| B | `roar` | Rugissement d’entrée ou d’intimidation |
| B | `heavy_slam` | Anticipation puis double frappe au sol |
| C | `rift_breath` | Souffle court émis par la gueule |
| C | `summon` | Appel d’invocations |
| C | `root_sweep` | Balayage des racines |
| D | `transform` | Ouverture des plaques, passage en phase 2 |
| D | `phase2_idle` | Respiration en phase 2 |
| D | `phase2_attack` | Attaque renforcée |
| E | `phase2_breath` | Souffle de phase 2 |
| E | `phase2_slam` | Écrasement de phase 2 |
| E | `hurt` | Réaction à un impact important |

Les boucles de repos sont à 7 images/s, les techniques à 9. La marche initiale est à 7 images/s,
l’attaque à 9 et la mort à 8. Cellules 512 × 512, ancre `[256, 480]`, hauteur cible 200 unités,
échelle 1.0. Les effets étendus, projectiles, télégraphes et collisions seront dessinés/calculés
séparément ; aucune zone lumineuse au sol n’est intégrée aux sprites.

L’animation `hurt` est facultative : ne pas interrompre toutes les attaques du boss à chaque coup
reçu. L’animation seule ne définit aucune règle d’interruption.

## Sources, import et contrôle

Toutes les images sont originales, générées avec l’outil imagegen intégré, sans API ni ressource
externe. PNG sources, prompts exacts, références et empreintes SHA256 sont conservés dans chaque
`assets/concepts/incoming/<identifiant>/source/`. Les `job.json` sont directement réimportables
avec `tools/art/import_sheet.py` ; `sheet_source` et `source_row` documentent la rangée d’origine.

Les variantes supplémentaires ont leur planche A en référence d’identité. Les références de style
communes sont Carapace, Jumper et Nébulorax. La corruption principale des Calcinés est gris-blanc ;
quelques braises ont été rendues plus chaudes que le rouge sombre demandé, surtout sur la Brute :
ce point reste soumis à la validation du propriétaire, sans déclarer ces essais définitifs.

Les sept Calcinés sont désormais `final`, après validation du propriétaire. Le Dévoreur et ses
nouveaux effets restent `wip` pour validation des animations supplémentaires. L’import ne crée
aucun `.tres` ni ne modifie `src/`. Les symboles et noms de capture sont des annotations d’atelier,
pas des textes d’interface livrés au joueur.

Aperçus : `docs/previews/chapter2-monsters/` (planche de famille, GIF par animation, rapport de
dimensions et captures Godot dans une partie gelée avec le Chasseur et Mousseroc). La dernière
créature de la capture de famille est le Courser des landes existant, utilisé comme référence
d’échelle. Audio coupé, aucune sauvegarde de partie.
