# Rift Hunters — feuille de route

Point d'entrée de toutes les décisions de conception validées par le propriétaire du projet.
Chaque sujet a son document détaillé dans `docs/design/`. **Avant de travailler sur le gameplay,
lire ce fichier puis le document concerné.** Les décisions « validées » ne se remettent pas en cause
sans l'accord du propriétaire ; les « questions ouvertes » se tranchent avec lui.

Dernière mise à jour : 14 octobre 2026.

## Vision

Un survivor-like 2D (attaque automatique, hordes) avec la profondeur de build, la difficulté exigeante
mais juste et la rejouabilité de **Hades**. Une **campagne en chapitres** de cartes (6 à 10 h), puis
des dizaines d'heures de rejouabilité : objectifs de cartes, Tension, New Game+, modes, et des
**trophées jusqu'au platine**.

## Décisions validées (14 octobre 2026)

| Sujet | Décision | Détail |
|---|---|---|
| Campagne | Chapitres de 3-4 cartes, Dévoreur à la fin de chaque chapitre ; finir une carte débloque la suivante | [design/CAMPAGNE.md](design/CAMPAGNE.md) |
| Rejouabilité des cartes | Toute carte débloquée est rejouable à l'infini ; 3 objectifs par carte ; récompenses dégressives ; Tension choisie par carte | idem |
| Modes | ~70 % vagues par zone (mode principal), ~30 % variantes (au moins une par chapitre) ; Survie au chrono hors campagne sur la Plaine fracturée | idem, [design/LONGEVITE.md](design/LONGEVITE.md) |
| Vagues par zone | Zones fermées par des barrières qui tombent quand les vagues sont nettoyées, puis arène du boss | [design/MODE_VAGUES_PAR_ZONE.md](design/MODE_VAGUES_PAR_ZONE.md) |
| Ruines des Cascades | Zone 1 : 3 vagues ; zone 2 : 5 vagues avec élites dès la 1re ; arène : Nébulorax (+ Échos et invocations) | idem |
| Attaque de base | Automatique | [design/COMPETENCES_ET_BUILDS.md](design/COMPETENCES_ET_BUILDS.md) |
| Sorts et touches | Visée au curseur, la touche lance immédiatement ; ZQSD ; sorts du Chasseur A, E, R, F ; sorts des Échos 1, 2, 3… ; reconfigurables | idem |
| Build (permanent) | Arbre du Chasseur + un arbre par Écho (passifs + compétences), points limités, réversible ; plusieurs builds enregistrés, choisis avant le départ | idem |
| Montées de niveau | Conservées et distinctes du build : renforcent temporairement le build pendant l'expédition, avec raretés | idem |
| Longévité | New Game+, Tension / pactes étendus, trophées internes reliés aux succès Steam, platine | [design/LONGEVITE.md](design/LONGEVITE.md) |
| Équipe d'Échos | **3 Échos maximum** (+ le Chasseur) ; départ avec 1 Écho et 2 emplacements, 3e par l'arbre ; un sort actif équipé par Écho | [design/ECHOS.md](design/ECHOS.md) |
| Roster et synergies | **16 Échos** à la sortie (9 à créer) ; 8 affinités portées chacune par 4 Échos (bonus à 2 et 3) ; 20 à 25 duos nommés | idem |

## Répartition du travail

| Qui | Rôle principal | Remarques |
|---|---|---|
| **Claude** | Code et systèmes de gameplay (lots ci-dessous), tests, équilibrage | Prend les lots marqués « Claude » |
| **Codex** | **Sprites, maps, visuels** (effets de sorts, icônes, interface illustrée) ; code quand le propriétaire le lui confie (fin de crédits Claude) | Peut prendre n'importe quel lot de code s'il est libre, en suivant ce document |
| **Propriétaire** | Génère les images (sprites, maps), valide les décisions, teste en jeu | Tranche les questions ouvertes |

Un lot = une branche depuis `main` à jour + une pull request vers `main` avec `tools/run_tests.sh` vert
(voir `AGENTS.md`). Exception pour les retouches visuelles de Codex, demandée par le propriétaire :
contrôles ciblés une fois en fin de lot, captures et essais manuels du propriétaire ; ne pas répéter la suite complète.
Ne pas travailler à deux sur le même lot : le noter « en cours (qui) » ci-dessous.

## Plan, dans l'ordre

### Étape A — Mode vagues par zone (chapitre 1 jouable)

| Lot | Contenu | Qui | Dépend de | État |
|---|---|---|---|---|
| A1 | Système de niveau en données : zones, barrières (obstacles dynamiques + carte de flux), points d'apparition par zone, directeur de vagues par zone, interface « Vague 2/3 · 12 restants », flèches, arène qui se referme | Claude | — | Fait (15 oct.) |
| A2 | Ruines des Cascades configurées (3 + 5 vagues, élites, Nébulorax) et équilibrage XP / durée | Claude | A1 | Fait (15 oct.) — à rééquilibrer après les sorts |
| A3 | Visuels : mur d'énergie violette des barrières + animation de dissolution, flèche de direction, effet d'ouverture de l'arène | Codex | — (intégration avec A1) | À faire |

### Étape B — Campagne

| Lot | Contenu | Qui | Dépend de | État |
|---|---|---|---|---|
| B1 | Données chapitre / carte, déblocage en avançant, 3 objectifs par carte, récompenses dégressives, Tension par carte, migration de sauvegarde | Claude | A1 | À faire |
| B2 | Refuge : sélection chapitre → carte, objectifs visibles ; Plaine fracturée en mode Survie hors campagne | Claude (code) + Codex (habillage) | B1 | À faire |
| B3 | Nouvelles cartes du chapitre 1 et cartes colorées du chapitre 2 (+ famille de monstres associée) | Propriétaire (images) + Codex (intégration, zones, collisions) | A1 pour les cartes en vagues | En cours (Codex) — retours corrigés : textures ×3, détails d’échelle, basalte et escaliers ; PR prête, validation manuelle du propriétaire attendue ; A1/A2 à suivre |

### Étape C — Sorts et builds

| Lot | Contenu | Qui | Dépend de | État |
|---|---|---|---|---|
| C1 | Visée au curseur, indicateur au sol, lancement de 2 sorts du Chasseur (A, E), touches reconfigurables | Claude | — | À faire |
| C2 | Arbre du Chasseur v2 (passifs + compétences, branches exclusives, réversible) et builds enregistrés au refuge | Claude | C1 | À faire |
| C3 | Arbres des Échos et sorts des Échos visés (1, 2, 3) | Claude | C2 | À faire |
| C4 | Raretés des choix de niveau (commun → héroïque) | Claude | C2 | À faire |
| C5 | Effets visuels des sorts, icônes des sorts et des nœuds d'arbre | Codex (+ images du propriétaire) | C1, puis au fil des sorts | À faire |
| C6 | Équipe à 3 Échos max ; 8 affinités (remplacent « arcane » et « contrôle ») avec bonus à 2 et 3 Échos ; « Prédateurs » devient une synergie d'affinité | Claude | — | À faire |
| C7 | Les 9 nouveaux Échos en jeu : données, attaques, sorts, arbres, duos nommés, textes FR/EN | Claude | C3, C6 et les sprites (C8) | À faire |
| C8 | Sprites des 9 nouveaux Échos (+ Mirelle) : prompts, génération, import | Propriétaire (génération) + Codex (prompts, import, contrôle) | — (peut commencer tout de suite) | À faire |

### Étape D — Longévité

| Lot | Contenu | Qui | Dépend de | État |
|---|---|---|---|---|
| D1 | Trophées internes + platine (reliés à Steam plus tard), à partir des 18 objectifs actuels | Claude | B1 | À concevoir |
| D2 | Modes variantes (défense d'autel, fermeture de failles…), un par chapitre | Claude + Codex | A1, B1 | À concevoir |
| D3 | Pactes étendus façon Hades | Claude | — | À concevoir |
| D4 | New Game+ | Claude | B1, C2 | À concevoir |

### Étape E — Publication

Voir « À faire avant la publication Steam » ci-dessous et [STEAM.md](STEAM.md).

## Documents de référence

- Conception : [GDD.md](GDD.md) (état actuel du prototype), [design/CAMPAGNE.md](design/CAMPAGNE.md), [design/ECHOS.md](design/ECHOS.md),
  [design/MODE_VAGUES_PAR_ZONE.md](design/MODE_VAGUES_PAR_ZONE.md),
  [design/COMPETENCES_ET_BUILDS.md](design/COMPETENCES_ET_BUILDS.md), [design/LONGEVITE.md](design/LONGEVITE.md)
- Code : [ARCHITECTURE.md](ARCHITECTURE.md) ; équilibrage : [BALANCE.md](BALANCE.md)
- Graphismes : [ART_BIBLE.md](ART_BIBLE.md), cartes : [MAP_GUIDELINES.md](MAP_GUIDELINES.md),
  [maps/GENERER_UNE_CARTE.md](maps/GENERER_UNE_CARTE.md), [maps/DE_L_IMAGE_AU_NIVEAU.md](maps/DE_L_IMAGE_AU_NIVEAU.md),
  pipeline d'assets : [ASSET_PIPELINE.md](ASSET_PIPELINE.md)
- Publication : [STEAM.md](STEAM.md)

## À faire avant la publication Steam

- Écran des crédits : remplacer « le propriétaire du projet » par le nom du compte développeur / studio Steam.
- Créditer les musiques (selon les conditions des outils qui les ont générées) et vérifier les licences
  tierces (Godot : mention MIT obligatoire ; pack Ninja Adventure : CC0).
- Déclarer l'usage d'IA générative sur la page Steam.
