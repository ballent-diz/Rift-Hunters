# Premier jet 3D : le Chasseur seul (draft3d/)

Décision du propriétaire (12-13 novembre 2026) : repartir sur une **base 3D** — décors modulaires en volume, personnages
et monstres en sprites 2D — et y retrouver la boucle d'origine : affronter les hordes → ramasser l'EXP → monter de
niveau → choisir une amélioration → devenir plus fort → affronter un boss. Ce premier jet ne contient **aucun Écho**.
Le jeu 2D reste intact dans le dépôt (campagne, sauvegardes, assets) et sert d'archive et de réserve.

## Lancer

- Windows : double-cliquer sur `lancer_premier_jet.cmd` (Godot 4.3 dans Downloads, comme le prototype).
- Commande : `godot --headless --import --path .` une fois, puis `godot --path . res://draft3d/main.tscn`.
- Le mode n'écrit jamais le profil : la progression de la campagne n'est pas touchée.

| Commande | Touche |
|---|---|
| Se déplacer | ZQSD, WASD ou flèches |
| Ruée (esquive, invulnérable un instant) | Espace ou Maj |
| Attaquer | automatique, sur l'ennemi visible le plus proche |
| Choisir une amélioration | 1, 2, 3 ou clic |
| Zoom / rejouer en fin de partie / quitter | molette / R / Échap |

Options de vérification (après `--`) : `--bot`, `--passive`, `--god`, `--seed=1`, `--boss-at=30`, `--result`,
`--perf=50,100,200`, `--shots=<dossier> --shot-times=40,95 --quit-after-shots`.

## Organisation

| Fichier | Rôle |
|---|---|
| `draft3d/run.gd` | la partie : vagues, attaque automatique, traits, EXP, niveaux, boss, fin, bot et mesures |
| `draft3d/level.gd` | la carte (Cour des Veilleurs), assemblée en modules KayKit, navigation |
| `draft3d/hunter.gd` | le Chasseur : déplacement, Ruée, PV, EXP |
| `draft3d/enemies.gd` | Corrompus et boss : chemins, séparation, contact, techniques |
| `draft3d/hazards.gd` | attaques annoncées au sol (cercle, ligne, onde) |
| `draft3d/upgrades.gd` | catalogue et tirage des améliorations |
| `draft3d/hud.gd` | interface, choix de niveau, écran de fin |
| `draft3d/sprite_view.gd`, `effect.gd` | sprites 2D et PixelFX dans le monde 3D |
| `draft3d/tuning.gd` / `.tres` | réglages propres au mode (vagues, boss, bonus du Chasseur seul) |

**Réutilisé tel quel** (référencé, jamais copié) : `GameDB` (ennemis, boss, améliorations, équilibrage), `Assets` et le
manifeste (feuilles, ancres, échelles, animations), `StatSheet`/`StatKeys`, `UpgradeData` et `StatModifierEffect`,
`CombatSystem.defense_multiplier`, la courbe d'EXP (`BalanceConfig.xp_to_next`), les textes de `i18n/strings.csv`.
**Adapté** : déplacements, collisions, projectiles et techniques, réécrits pour le relief (l'ancienne simulation est
liée au plan 2D). **Repris du prototype KayKit (PR #162)** : modules et collisions, caméra orthographique, corrections
de fluidité (accélération courte, diagonales normalisées, orientation confirmée, image interpolée, caméra calée sur la
position affichée, marche liée à la distance parcourue).

Améliorations : dix cartes de `data/upgrades/` (Puissance, Cadence, Vitalité, Célérité, Magnétisme, Multitrait,
Perforation, Réflexes, Régénération, Éclatement) et deux propres au mode (`draft3d/upgrades/` : Longue portée,
Rempart). `DraftUpgrades.is_valid` refuse toute carte à condition d'Écho, à statistique d'équipe ou dépendante de
l'ancienne simulation.

## Raccordements de l'existant (13 novembre)

Tout est référencé depuis le dépôt (données, manifeste, autoloads), rien n'est copié.

| Lot | Ce qui est branché | Fichier |
|---|---|---|
| Monstres et boss | Bestiaire des cinq chapitres lu dans la campagne (48 monstres mobiles), choix du chapitre au lancement, un gardien du chapitre à 4 min, son Dévoreur à 8 min ; comportements passe-faille et invocateur ; Nebulorax écarté | `roster.gd`, `enemies.gd` |
| Ombres calées | Disque au sol tiré du champ `shadow` du manifeste (empreinte mesurée) | `sprite_view.gd` |
| PixelFX | Effets par famille du catalogue `techniques.json` : tirs, impacts, morts, apparitions, techniques des boss | `pixelfx.gd` |
| Audio | Musiques par contexte (partie, boss, seconde phase, victoire, défaite), douze sons, tempo (les cristaux battent la mesure) | `run.gd` |
| Sorts | Sorts équipés dans l'arbre du profil, ou Taille et Lance par défaut ; ils partent seuls. Pris en charge : Taille, Lance, Rupture, Bond de Faille | `spells.gd` |
| Arbre de compétences | Nœuds actifs du profil qui modifient une statistique du Chasseur ou de ses sorts, en lecture seule | `upgrades.gd` (`apply_tree`) |
| Campagne | Un chapitre s'ouvre quand le précédent est vaincu ; sauvegarde à part `user://draft3d_progress.json` | `progress.gd` |

**Non raccordé, et pourquoi**
- Effets peints des boss et barrières peintes animées : ce sont des scènes 2D ; les afficher en 3D demande un rendu
  intermédiaire par effet. Les boss utilisent les PixelFX à la place.
- Techniques propres à chaque monstre et à chaque boss : les boss partagent quatre techniques communes (griffes, onde,
  pluie, invocation, rayon en seconde phase) avec leurs propres animations ; les élites ne sont pas repris.
- Huit sorts sur douze, les variantes de sorts et les nœuds de l'arbre qui ne sont pas de simples statistiques.
- Écran de l'arbre dans ce mode : l'arbre se règle toujours dans le refuge de la campagne.
- Échos : toujours absents, comme demandé.

## Règles de hauteur et d'obstacles

- **On touche ce que l'on voit** : viser, tirer et cracher demandent une vue dégagée (aucun décor entre les deux),
  à plat comme entre la cour et la terrasse. Murs, piliers, caisses et rebord de terrasse arrêtent les tirs.
- Un trait touche **à sa hauteur** ; contacts et coups de mêlée ne portent pas au-delà de 1 m de dénivelé.
- Une attaque annoncée au sol ne touche que son niveau (1,2 m) : la terrasse abrite de l'onde du boss lancée en bas.
- Une onde en anneau est découpée par le décor, à l'image comme pour les dégâts : chaque tronçon s'éteint sur
  l'obstacle qu'il rencontre, l'onde ne continue que par les ouvertures (toutes les cartes).
- Les ennemis suivent la navigation (trois escaliers), sans traverser le décor.

## Carte : premier niveau, les Ruines des Veilleurs

96 × 56 m, cinq quartiers reliés par des portes et des brèches, sans cul-de-sac (`draft3d/level.gd`) :
- **Parvis** (sud) : départ du Chasseur, dégagé, deux abris ;
- **Cour** (centre) : grande place, arche, murets, piliers ; le boss y apparaît ;
- **Terrasse haute** (nord, 2 m) : trois escaliers, parapets ;
- **Entrepôts** (ouest) : rangées de murs et de caisses en quinconce, couloirs serrés pour semer une horde ;
- **Colonnade** (est) : piliers en quinconce et petite terrasse d'angle avec son escalier.

Murs au nord et sur les côtés, barrières basses au sud (côté caméra). Les ennemis apparaissent sur le pourtour, à
13–32 m du Chasseur. Vue d'ensemble : `docs/previews/premier-jet-3d/carte.webp` (option `--overview`).
Décors : **KayKit Dungeon Remastered**, Kay Lousberg, licence **CC0** (`draft3d/kaykit/LICENSE.txt`). Moteur : Godot 4.3.

## Carte : deuxième niveau, le Cimetière des Cendres

88 × 64 m, en extérieur, de nuit (`draft3d/level_graveyard.gd`), jouée au chapitre 2. Quartiers reliés, sans
cul-de-sac : Portail et allée aux lanternes (sud), Champ des tombes (sud-ouest), Bois mort (sud-est, seuls les troncs
arrêtent les tirs), Crypte et son parvis (centre-nord, lieu du boss), Tertre à 2 m avec deux escaliers (nord-ouest),
Ossuaire (nord-est). Grille tout autour. Vue d'ensemble : `docs/previews/premier-jet-3d/carte_2.webp`.
Décors : **KayKit Halloween Bits**, Kay Lousberg, licence **CC0** (`draft3d/halloween/LICENSE.txt`), importés tels
quels avec une collision simple (`DraftLevel._prop`). Une carte = une classe qui hérite de `DraftLevel` ;
`DraftLevel.create(chapitre)` choisit la carte .

## Carte : troisième niveau, le Hameau du Gué

92 × 64 m, village en plein jour coupé par une rivière (`draft3d/level_village.gd`), jouée au chapitre 3. Place du
village au sud (puits, marché, taverne, maisons), rivière infranchissable sauf par trois ponts (les tirs passent
au-dessus de l'eau), champs et moulin au nord-ouest, butte de l'église à 2 m avec deux escaliers (le boss apparaît à
son pied), bosquet et tour de guet au nord-est. Muret de pierre tout autour. Vue d'ensemble :
`docs/previews/premier-jet-3d/carte_3.webp`. Décors : **KayKit Medieval Hexagon Pack**, Kay Lousberg, licence
**CC0** (`draft3d/medieval/LICENSE.txt`), agrandis cinq fois. Les chapitres 4 et 5 jouent encore sur le niveau 1.

## Vérifications

`tests/unit/test_draft3d.gd` (11 essais, dans `tools/run_tests.sh unit`) : catalogue sans Échos, offres distinctes et
plafonds, seuils d'EXP, pause et reprise du choix, application des cartes, escalier, limites, abris, traits arrêtés,
ennemi qui blesse, EXP ramassée, défaite, victoire sur le boss, partie neuve remise à zéro.

### Performances (mesure du 13 novembre)

Machine disponible : conteneur cloud, 4 cœurs Xeon 2,1 GHz, **sans carte graphique** (rendu logiciel), 1280 × 720,
temps réel. Résultat : 8,6 à 9,2 images/s avec 44, 100, 200 puis 300 ennemis. La cadence ne baisse pas quand la
horde grossit : c'est le rendu logiciel qui plafonne, pas la simulation. Cette mesure ne dit donc rien de la fluidité
sur un PC de jeu ; la limite réelle (nombre d'ennemis à 60 images/s) reste à mesurer chez le propriétaire avec
`godot --path . res://draft3d/main.tscn -- --perf=100,200,300,400` (résultats dans la console).

Capture : `docs/previews/premier-jet-3d/boss.webp` (boss et son onde annoncée, améliorations prises en bas à gauche).

## Limites connues

- Équilibrage volontairement sommaire (le propriétaire juge en jouant) : le bot, peu habile, tient 2 à 4 minutes.
  Réglages dans `draft3d/tuning.gd`.
- Pas de vidéo livrée (rendu logiciel trop lent ici).
- Les raccordements du 13 novembre n'ont été vérifiés que par les essais automatiques, sans affichage.
- Fluidité réelle et lisibilité en mouvement non vérifiables sans carte graphique : à juger sur PC.

## Suite prévue (une PR par lot)

Raccorder l'existant à cette base : Échos, monstres par chapitre, audio, arbre de compétences, autres cartes.
Non repris : cartes peintes, collisions peintes, masques de masquage.
