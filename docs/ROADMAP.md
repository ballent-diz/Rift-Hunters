# Rift Hunters — feuille de route

Point d'entrée de toutes les décisions de conception validées par le propriétaire du projet.
Chaque chantier a son document détaillé dans `docs/design/`. **Avant de travailler sur le gameplay,
lire ce fichier puis le document du chantier concerné.** Les décisions marquées « validé » ne se
remettent pas en cause sans l'accord du propriétaire ; les « questions ouvertes » se tranchent avec lui.

Dernière mise à jour : 14 octobre 2026.

## Vision

Un survivor-like 2D (attaque automatique, hordes) avec la profondeur de build, la difficulté exigeante
mais juste et la rejouabilité de **Hades**. Durée visée : **plusieurs heures** de contenu, rejouabilité
par les modes de jeu, le New Game+, les difficultés et un système de **trophées jusqu'au platine**.

## Décisions validées (14 octobre 2026)

| Sujet | Décision | Détail |
|---|---|---|
| Structure des niveaux | Mode « vagues par zone » : zones fermées par des barrières qui tombent quand les vagues sont nettoyées, puis arène du boss | [design/MODE_VAGUES_PAR_ZONE.md](design/MODE_VAGUES_PAR_ZONE.md) |
| Ruines des Cascades | Zone 1 : 3 vagues ; zone 2 : 5 vagues avec élites dès la 1re ; arène : Nébulorax en 1v1 (+ Échos et invocations) | idem |
| Modes de jeu | Le système de niveau est en données ; d'autres maps auront d'autres modes (survie, défense, failles…) | [design/LONGEVITE.md](design/LONGEVITE.md) |
| Attaque de base | Automatique (ADN survivor-like) | [design/COMPETENCES_ET_BUILDS.md](design/COMPETENCES_ET_BUILDS.md) |
| Sorts | On vise avec la souris, la touche lance immédiatement vers le curseur | idem |
| Touches | Déplacement ZQSD (AZERTY) ; sorts du Chasseur **A, E, R, F** ; sorts des Échos **1, 2, 3…** ; reconfigurables | idem |
| Arbres | Un arbre pour le Chasseur et un par Écho : passifs + compétences ; points limités, impossible de tout prendre ; réversibles au refuge | idem |
| Builds | Le build (arbres + compétences équipées) est permanent et se conserve d'une expédition à l'autre ; plusieurs builds enregistrables, choisis avant le départ | idem |
| Montées de niveau en partie | Conservées et **distinctes** du build : elles renforcent temporairement le build pendant l'expédition (variété d'une partie à l'autre) | idem |
| Longévité | Modes, New Game+, difficultés (Tension / pactes), trophées internes reliés aux succès Steam | [design/LONGEVITE.md](design/LONGEVITE.md) |

## Chantiers, dans l'ordre

| # | Chantier | État | Effort estimé |
|---|---|---|---|
| 1 | Mode vagues par zone sur les Ruines des Cascades (barrières, apparitions par zone, carte de flux dynamique, interface de vague, arène du boss) | Validé, en attente (après le travail en cours de Codex) | high |
| 2 | Sorts du Chasseur : visée au curseur, lancement, 2 premiers sorts | Validé, à faire | xhigh (découpé) |
| 3 | Arbre du Chasseur v2 (passifs + compétences, builds enregistrés) | Validé, à faire | |
| 4 | Arbres des Échos et sorts des Échos visés | Validé, à faire | |
| 5 | Raretés des choix de niveau, pactes étendus | Validé, à faire | |
| 6 | Trophées, New Game+, nouveaux modes | Validé dans le principe, à concevoir en détail | |

Chaque chantier est livré par étapes jouables, testées (`tools/run_tests.sh`) et proposées en pull request vers `main`.

## Documents de référence existants

- Conception générale (état actuel du prototype) : [GDD.md](GDD.md)
- Architecture du code : [ARCHITECTURE.md](ARCHITECTURE.md)
- Équilibrage : [BALANCE.md](BALANCE.md)
- Graphismes : [ART_BIBLE.md](ART_BIBLE.md), cartes : [MAP_GUIDELINES.md](MAP_GUIDELINES.md),
  pipeline d'assets : [ASSET_PIPELINE.md](ASSET_PIPELINE.md)
- Publication : [STEAM.md](STEAM.md)

## À faire avant la publication Steam

- Écran des crédits : remplacer « le propriétaire du projet » par le nom du compte développeur / studio Steam.
- Créditer les musiques (selon les conditions des outils qui les ont générées) et vérifier les licences
  tierces (Godot : mention MIT obligatoire ; pack Ninja Adventure : CC0).
- Déclarer l'usage d'IA générative sur la page Steam.
