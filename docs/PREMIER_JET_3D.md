# Premier jet 3D : le Chasseur seul (draft3d/)

Décision du propriétaire (12-13 novembre 2026) : repartir sur une **base 3D** — décors modulaires en volume, personnages
et monstres en sprites 2D — et y retrouver la boucle d'origine : affronter les hordes → ramasser l'EXP → monter de
niveau → choisir une amélioration → devenir plus fort → affronter un boss. Ce premier jet ne contient **aucun Écho**.
Le jeu 2D reste intact dans le dépôt (campagne, sauvegardes, assets) et sert d'archive et de réserve.

## Lancer

- Windows : double-cliquer sur `lancer.cmd` (Godot 4.3 dans Downloads, comme le prototype).
- Commande : `godot --headless --import --path .` une fois, puis `godot --path .` (menu principal,
  `draft3d/menu.tscn`) ou `godot --path . res://draft3d/main.tscn` (partie directe).
- Le mode n'écrit jamais le profil : la progression de la campagne n'est pas touchée.

| Commande | Touche |
|---|---|
| Se déplacer | ZQSD, WASD ou flèches |
| Ruée (esquive, invulnérable un instant) | Espace ou Maj |
| Sorts (4 emplacements) | flèches au clavier seul ; A E R F ou clic gauche avec la souris ; reconfigurables (Options → Touches et visée) |
| Attaquer | automatique, sur l'ennemi visible le plus proche |
| Choisir une amélioration | 1, 2, 3 ou clic |
| Zoom / rejouer en fin de partie / pause | molette / R / Échap, P ou Start |
| Rendu pixel 3D / rendu lisse d'origine | F4 |

**Raccourcis de test** (versions de développement seulement, invisibles dans une version exportée ; la partie ne compte
alors ni victoire de chapitre ni gain de Fragments) : **F9** ou **Pause → Aller au boss (test)** retire la vague en cours
et fait venir le boss de la carte tout de suite (sommet de la tour compris) ; `--boss-test --chapter=N` démarre
directement sur le boss du chapitre N avec un Chasseur monté de 15 niveaux (`--boss-level=N` pour changer,
`DraftTuning.test_boss_levels`) ; `--boss=<id>` impose un Dévoreur (et sa famille de monstres) quel que soit le chapitre. Dans tous les cas, l'arsenal est rempli : emplacement en plus, tous les sorts (ordre
tiré au hasard, les autres en réserve), tous les passifs et des mutations tirées au hasard (deux au plus par sort).
Code : `draft3d/boss_test.gd`.

Options de vérification (après `--`) : `--bot`, `--spells=hunter_mark,void_rend`, `--cast-at=20`, `--passive`, `--god`, `--seed=1`, `--boss-at=30`, `--result`,
`--perf=50,100,200`, `--shots=<dossier> --shot-times=40,95 --quit-after-shots`, `--look=x,z[,hauteur]`,
`--pixel=0`, `--pixel-palette=0`, `--pixel-scale=2` (rendu pixel : docs/art/RENDU_PIXEL_3D.md).

## Organisation

| Fichier | Rôle |
|---|---|
| `draft3d/run.gd` | la partie : vagues, attaque automatique, traits, EXP, niveaux, boss, fin, bot et mesures |
| `draft3d/level.gd` | la carte (Cour des Veilleurs), assemblée en modules KayKit, navigation |
| `draft3d/hunter.gd` | le Chasseur : déplacement, Ruée, PV, EXP |
| `draft3d/enemies.gd` | Corrompus et boss : chemins, séparation, contact, techniques |
| `draft3d/boss_brain.gd`, `boss_mechanic.gd` | cerveau des boss piloté par leurs données v1 (phases, techniques, déplacements, transitions, mort) et base des mécaniques phares ([BOSS_V2.md](design/BOSS_V2.md)) |
| `draft3d/hazards.gd` | attaques annoncées au sol (cercle, ligne, onde) |
| `draft3d/upgrades.gd` | catalogue et tirage des améliorations |
| `draft3d/hud.gd` | interface, choix de niveau, choix du chapitre, pause, écran de fin |
| `draft3d/menu.gd`, `options.gd` | menu principal (scène de démarrage) et fenêtre d'options |
| `draft3d/unlock_screen.gd` | écran des déblocages (sorts, variantes, sorts de départ), lit `DraftUnlocks` |
| `draft3d/sprite_view.gd`, `effect.gd` | sprites 2D et PixelFX dans le monde 3D |
| `draft3d/render/` | rendu pixel 3D : vue basse résolution, aplats, contours, palette par chapitre (docs/art/RENDU_PIXEL_3D.md) |
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
| Sorts | Sorts actifs lancés à la touche, visée souris / manette / clavier seul, barre de sorts ; départ : toujours Taille et Lance, les autres s'apprennent au choix de niveau. Raccordés : 15 sorts (Taille, Lance, Rupture, Bond, Parade, Singularité, Mur, Égide, Cristal et six sorts propres à la v2), leurs variantes et rangs en cartes de niveau ([SORTS_ACTIFS_V2.md](design/SORTS_ACTIFS_V2.md)) | `spells.gd`, `spell_bar.gd`, `controls.gd` |
| Arbre de compétences | Nœuds actifs du profil qui modifient une statistique du Chasseur ou de ses sorts, en lecture seule | `upgrades.gd` (`apply_tree`) |
| Campagne | Un chapitre s'ouvre quand le précédent est vaincu ; sauvegarde à part `user://draft3d_progress.json` | `progress.gd` |

**Non raccordé, et pourquoi**
- Barrières peintes animées (scènes 2D). Les effets peints des boss sont affichés au sol depuis le 16 novembre
  (`draft3d/painted_fx.gd`, rendu intermédiaire par effet, [BOSS_V2.md](design/BOSS_V2.md)).
- Techniques propres aux monstres de la campagne 2D ; leurs élites ne sont pas repris. Les familles propres à la v2
  (chapitres 6, 8, 9) jouent les leurs depuis le 20 novembre (`draft3d/foe_techniques.gd`, volants compris,
  [BOSS_V2.md](design/BOSS_V2.md) section 9). Boss : phases et techniques de leurs données
  jouées en gestes 3D depuis le 16 novembre ; mécaniques phares importées lot par lot ([BOSS_V2.md](design/BOSS_V2.md)).
- Appel de meute et Permutation (Échos), Failles jumelles ; les nœuds de l'arbre qui ne sont pas de simples statistiques.
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
**CC0** (`draft3d/medieval/LICENSE.txt`), agrandis cinq fois.

## Carte : quatrième niveau, l'Avant-poste des Glaces

92 × 64 m, base technique sur la banquise (`draft3d/level_outpost.gd`), jouée au chapitre 4. Aire d'atterrissage au
sud (départ), base de quatre modules reliés par un tunnel au centre, dépôt de fret à l'ouest, champ solaire et
éoliennes à l'est, plateau de forage à 2 m avec deux escaliers au nord (le boss apparaît à son pied). Falaise de
glace tout autour. Vue d'ensemble : `docs/previews/premier-jet-3d/carte_4.webp`. Décors : **KayKit Space Base
Bits**, Kay Lousberg, licence **CC0** (`draft3d/spacebase/LICENSE.txt`), agrandis quatre fois ; roches et falaises
repeintes en glace.

## Carte : cinquième niveau, la Cité Effondrée

96 × 60 m, ville de pierre en ruine, de nuit (`draft3d/level_city.gd`), jouée au chapitre 5, recomposée le 15 novembre
(plan en damier, règles : `docs/maps/CARTES_3D.md`). Porte sud (départ), Avenue pavée bordée de façades jusqu'au
Forum dallé (arène du boss, quatre colonnes d'abri), Rue transversale d'est en ouest, Acropole dallée à 2 m (grand
escalier depuis le Forum, escalier est depuis la Voie sacrée), Temple à péristyle au nord-est, îlots de maisons
alignés sur les rues à l'ouest, entrepôts au sud-est, une maison effondrée par quartier. Rempart sur trois côtés,
parapet bas au sud. Vue d'ensemble : `docs/previews/premier-jet-3d/carte_5.webp` ; avant/après :
`docs/previews/cartes-3d/`. Décors : **KayKit Dungeon Remastered**, Kay Lousberg, licence **CC0**
(`draft3d/dungeon/LICENSE.txt`), vingt-six pièces importées telles quelles (taille réelle).

## Carte : sixième niveau, l'Anneau de la Faille

100 × 100 m, ronde, sans étage ni escalier (`draft3d/level_ring.gd`) : couronne de terre autour d'un gouffre, îlot
central du boss (20 m de rayon, quatre piliers) relié par deux passerelles, trois secteurs (Porte, Ossuaire, Forges)
séparés par des murs radiaux à brèche. Les bords du gouffre arrêtent la marche, pas les tirs. Sommet de la future tour
du chapitre 6 : trois étages en anneau joués à la suite (`draft3d/tower.gd`) — la Garnison, les Cellules (gardien),
le Sommet (Dévoreur). Chaque étage dure 3 min, puis une herse se lève au pied d'une rampe le long du rempart ;
atteindre le palier fait monter d'un étage, le Chasseur garde tout. Détails : `docs/maps/CARTES_3D.md`. En attendant
le raccordement du chapitre, `--chapter=6` lance la tour avec le bestiaire du chapitre 5 (`--tower-floor=1` : partir
d'un étage).

## Carte : septième niveau, le Défilé Hurlant

170 × 28 m, gorge longue et étroite suivie d'ouest en est (`draft3d/level_pass.gd`) : cinq clairières (Campement,
Carrière, Cirque, Tour brisée, Arène des Pierres levées où apparaît le boss) séparées par quatre goulets de roche,
dont deux doubles. Falaise au nord, rochers bas au sud ; ni étage ni escalier. `--chapter=7` la lance avec le
bestiaire du chapitre 5 en attendant le chapitre 7.

## Carte : huitième niveau, le Marais des Marées

90 × 90 m, îlots reliés par des levées dans une eau trouble (`draft3d/level_marsh.gd`). Toutes les 80 s, la marée
monte et noie les levées basses : on n'y entre plus, les monstres font le tour, on tire toujours par-dessus l'eau.
Sanctuaire du boss au centre, jamais noyé. `--chapter=8` (famille des Saumâtres, Dévoreur : Saumor),
`--tide-at=61` pour partir à marée haute. Détails : `docs/maps/CARTES_3D.md`.

## Carte : neuvième niveau, les Corniches

68 × 112 m, falaise en gradins gravie vers le nord (`draft3d/level_cliffs.gd`) : la Grève (0 m), le Guet (3 m), le
Promontoire (6 m) et la Couronne (9 m, boss), reliés par des rampes en lacets, des éboulis et des escaliers ; trois
perchoirs à 1,5 m hors de portée de la mêlée. `--chapter=9` (bestiaire du
chapitre 5 en attendant le chapitre 9). Détails : `docs/maps/CARTES_3D.md`.

## Vérifications

`tests/unit/test_draft3d.gd` (11 essais, dans `tools/run_tests.sh unit`) : catalogue sans Échos, offres distinctes et
plafonds, seuils d'EXP, pause et reprise du choix, application des cartes, escalier, limites, abris, traits arrêtés,
ennemi qui blesse, EXP ramassée, défaite, victoire sur le boss, partie neuve remise à zéro, contrôle de composition
de toutes les cartes (`DraftLevelAudit`, outil `tools/level_audit.tscn`, voir `docs/maps/CARTES_3D.md`).

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
