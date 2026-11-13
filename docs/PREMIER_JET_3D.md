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

## Règles de hauteur et d'obstacles

- **On touche ce que l'on voit** : viser, tirer et cracher demandent une vue dégagée (aucun décor entre les deux),
  à plat comme entre la cour et la terrasse. Murs, piliers, caisses et rebord de terrasse arrêtent les tirs.
- Un trait touche **à sa hauteur** ; contacts et coups de mêlée ne portent pas au-delà de 1 m de dénivelé.
- Une attaque annoncée au sol ne touche que son niveau (1,2 m) : la terrasse abrite de l'onde du boss lancée en bas.
- Les ennemis suivent la navigation (trois escaliers), sans traverser le décor.

## Carte

Cour de 48 × 40 m, terrasse nord à 2 m avec trois escaliers (centre, est, ouest), arche au sud, deux murets, quatre
piliers, quatre groupes de caisses, parapets en hauteur ; murs au nord et sur les côtés, barrières au sud. Décors :
**KayKit Dungeon Remastered**, Kay Lousberg, licence **CC0** (`draft3d/kaykit/LICENSE.txt`). Moteur : Godot 4.3.

## Vérifications

`tests/unit/test_draft3d.gd` (7 essais, dans `tools/run_tests.sh unit`) : catalogue sans Échos, offres distinctes et
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
- Pas de son dans ce mode ; pas de vidéo livrée (rendu logiciel trop lent ici).
- Le boss utilise les données de Nebulorax avec des techniques réécrites, sans ses effets peints.
- Fluidité réelle et lisibilité en mouvement non vérifiables sans carte graphique : à juger sur PC.

## Suite prévue (une PR par lot)

Raccorder l'existant à cette base : Échos, monstres par chapitre, audio, arbre de compétences, autres cartes.
Non repris : cartes peintes, collisions peintes, masques de masquage.
