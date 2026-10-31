# Rift Hunters — feuille de route

## Lot du 29 octobre (Claude) : collisions des cartes 7 à 12, cartes 10 à 12 en jeu

- **Collisions peintes par le propriétaire** pour les cartes 7 à 12 ; carte 9 : escalier taillé dans la falaise entre
  les deux zones (rendu provisoire, retouche confiée à Codex). Bot invulnérable : cartes 7, 8 et 9 gagnées, gardien tué.
- **Carte 10** : `caldera_arena` branchée sur le décor `volcano_heart` (nappes et cratères recalés) —
  [fiche](maps/COEUR_DU_VOLCAN.md).
- **Carte 11** `root_mangrove` : trois zones, finale sur l'île, vase — [fiche](maps/MANGROVE_DES_RACINES.md).
- **Carte 12** `tide_temple` : quatre failles, finale dans le bassin sacré, marée sur trois chaussées —
  [fiche](maps/TEMPLE_DES_MAREES.md).
- **Campagne** (31 octobre) : cartes 7 à 9 en vagues par zone, chapitre 2 = cartes 6 à 10, chapitre 3 « Les Marais
  engloutis » = cartes 11 et 12. Gardiens propres des cartes 7 à 9 : Chevalier calciné (cercle du duel), Reine-veuve
  (fils tendus), Matrone des scories (carapace fendue par les roches). Équilibrage des cartes 7 à 12 dans
  [DIFFICULTE.md](design/DIFFICULTE.md).
- **Restent à faire** : gardiens propres des cartes 11 et 12 (Sentinelle des racines et Chimère des brumes en attendant :
  propositions à faire) ; cartes 13 à 15.

## Journée visuelle du 28 octobre — Monstres du chapitre 3 : Livré (Codex)

14 créatures importées, 25 sources, 54 animations peintes (324 poses), deux bancs Godot 720p animés. Sources Work indisponibles au téléchargement : remplacements générés selon l’autorisation du 28 octobre. Import Godot, suites assets et art (qualité cartes incluse) verts. Aucun gameplay. Réserve artistique : Enlisés sombres sur terre. Effets PR #78 déjà fusionnés : lot 2 couvert, raccords Claude à vérifier sans redessiner les effets.


## Sorts des monstres chapitres 3 et 4 — effets améliorés livrés pour revue (Codex, PR #78)

56 scènes autonomes récupérées de Work ; matière, frappe et dissipation reprises avec le vocabulaire peint du Chasseur. 56 scènes contrôlées, 19 groupes capturés dans Godot, mesure de rendu jointe. Aucun gameplay modifié. Raccordement par Claude après validation ; sprites existants conservés.

## B3 — Carte 10, Cœur du volcan : visuels livrés pour revue (Codex)

Nouvelle map-arène multi-lobes, sans reprise de la spirale. Carte 9 renommée Le Seuil du Cataclysme (cataclysm_threshold) sur demande du propriétaire. Ensuite seulement : cartes 11 puis 12, puis sprites chapitre 3. Le propriétaire autorise désormais la poursuite sans attendre de réponses ; choix et contrôles documentés.

## Suite du lot du 26 octobre (Claude) : mécanique phare par boss, Glauquemire, équilibrage des cartes 1 à 6

- **Un Écho par carte** gagnée, les moins forts d'abord ([design/COLLECTION_ECHOS.md](design/COLLECTION_ECHOS.md)).
- **Mécanique phare par boss**, gardiens compris (`BossData.signature`, `test_boss_signatures`) :
  - Astravorn : couronne d'astres ;
  - Sentinelle : séisme ;
  - Chimère : voile de brume ;
  - Dévoreur des Sources : orbes de source ;
  - Gardien du bûcher : charge du bûcher ;
  - Pyrevorn : séquence des cratères ;
  - Glauquemire : miroirs à orienter.
- **Glauquemire**, Dévoreur du chapitre 3 (3 phases, 8 mécaniques nouvelles) : forme provisoire, prompt de Codex dans
  [design/DEVOREUR_CHAPITRE3.md](design/DEVOREUR_CHAPITRE3.md). Les cartes 13 à 15 sont conçues dans
  [design/CARTES.md](design/CARTES.md). Glauquemire et lanterne de brume — **Livré (Codex), 28 octobre** : six planches de corps, trois phases, 14 animations ; lanterne allumée/extinction/éteinte. Import Godot, assets et art verts, captures 720p. Aucun gameplay. Raccords Claude et réserves dans `docs/art/GLAUQUEMIRE_SPRITES.md`.
- **Équilibrage aux règles actuelles** (un Écho au départ, pas de drops) : cartes 1 à 6 mesurées au bot. Multiplicateurs
  de boss par carte (`boss_hp_mult`, `boss_damage_mult`). Tableau dans [design/DIFFICULTE.md](design/DIFFICULTE.md).
- **Navigation** :
  - le bot (et les Corrompus) sortent des recoins plus étroits que la marge de la carte de flux : c'était le blocage de
    la carte 6 ;
  - le Chasseur coincé dans une fente du décor est replacé sur un point libre (carte 1) ;
  - pendant une vague, la flèche ramène à la zone en cours (carte 5).
- **Collisions pré-peintes des cartes 7 à 9** : à corriger par le propriétaire (`assets/concepts/incoming/map.<id>/collision/` ;
  carte 9 : `map.cataclysm_threshold`).
- **Restent à faire** :
  - raccorder à `caldera_arena` le décor de la carte 10 livré par Codex (`volcano_heart`, PR 76) : manifeste,
    collisions, navigation, nappes brûlantes ;
  - collisions définitives des cartes 7 à 9, puis leurs propres gardiens (chacun avec sa mécanique phare) ;
  - arènes des cartes 11 à 15 ;
  - gardiens des cartes 7 à 9 : propositions dans [design/MONSTRES.md](design/MONSTRES.md), à valider.

## Lot du 26 octobre (Claude) : grande arène, chapitre 3, nids

Carte 10 en **grande arène** (`caldera_arena`, en attente du décor de Codex) : 3 paliers, Titan de caldeira et
Wyvernette en gardiens (élites en version boss), Pyrevorn au palier 3, roches lancées depuis les cratères. Mécaniques des
cartes 11 (vase qui colle) et 12 (marée). Mécaniques ennemies du chapitre 3 (E14 à E17, volants, furtifs) et 14 fiches
à formes provisoires. Nids qui pondent (carte 8). Bot : option `--team` / `TEAM` pour partir avec une équipe composée.

## B3 — Carte 9 sélectionnée, volcan carré : détails livrés pour revue (Codex)

Source exacte c9.png. Seize régions 4 × 4, trois tuiles 3762 × 11286 ; contrôle global conforme et chargement Godot 4.3 réussi. Rapport et planche d’échelle dans docs/previews/cataclysm-threshold-detail/. Identifiant visuel cataclysm_threshold (Le Seuil du Cataclysme) ; aucune modification de src/, data/ ou collision. Carte graphique livrée, intégration jouable à faire.


## B3 — Carte 7, Évents de cendre : détails livrés pour revue (Codex)

Branche codex/carte-events-detail depuis main à jour. Plan validé conservé, douze régions, trois tuiles assemblées, contrôle qualité CONFORME et planche d’échelle. Réserve de netteté locale documentée ; pas de qualification finale ni niveau jouable. Aucun changement de collisions ou de gameplay.

## B3 — Carte 12, Temple des marées : détails et masque livrés pour revue (Codex)

Branche codex/carte-tide-temple depuis main. Carte verticale, quatre espaces de faille, chaussées basses et itinéraires hauts permanents. Cartes 10 et 11 publiées dans les PR #76 et #77 ; sprites chapitre 3 déjà créés dans Work ; reprise des effets Godot PR #78 après cette carte. Poursuite autonome autorisée.

## B3 — Carte 8, Tanières de suie : détails livrés pour revue (Codex)

Plan exact c8.png fourni le 25 octobre ; seize régions assemblées en trois tuiles, rapport qualité et planche d’échelle joints ; sans recomposition ni collisions. Carte 9 après publication de cette livraison.


## Décisions du propriétaire du 24 octobre 2026 (Claude, en jeu)

- **Plus aucun drop en partie** hors soins : coffres, reliques et évolutions mis de côté
  (`BalanceConfig.disabled_features`, le contenu reste en données et peut revenir). Plus de capture d'Écho en partie.
- **Collection d'Échos** : on part avec un seul Écho ; chaque carte gagnée en débloque un (récompense de fin de carte) ;
  l'équipe, 3 au plus, se compose au refuge parmi les Échos débloqués. Les jalons de campagne ne recrutent plus.
- **Les deux mains au clavier** : sorts du Chasseur sur les flèches, Techniques des Échos sur A, E, F (AZERTY), visée
  dans la direction du Chasseur. Recharges des Techniques affichées sous le Chasseur.
- Vitesse de base du Chasseur 150 → 180. Cendrelame affaiblie au départ. Campagne : jalons seulement, pas de niveau.
- Le boss de la carte 1 (Nébulorax) est gardé.

## B3 — Tanières de suie, carte 8 — composition et détail livrés pour revue (Codex)

Branche `codex/carte-tanieres-de-suie` depuis main à jour. Composition carrée en zigzag,
nef effondrée en diagonale, nid et œuf de cendre séparés. Composition validée le
24 octobre 2026 : plan figé. Les seize régions de la sélection c8.png sont désormais assemblées ; contrôle global conforme, circulation non testée. Les sprites restent inchangés ;
la validation de composition ne vaut pas validation de ces objets. Nid (18 poses) et œuf (12 poses) importés, GIF et contrôle ciblé
Godot 4.3 réussis. Carte non jouable à ce stade ; régions et peinture des collisions à suivre.
Aucun changement dans `src/`, `data/` ou les collisions.

## B3 — Évents de cendre, carte 7 — composition livrée pour revue (Codex)

Branche `codex/carte-events-de-cendre`, depuis main à jour. Nouvelle composition en U, sans
arène ni pont, et sprite séparé `object.ember_pod`. Les Gorges de cendre sont abandonnées :
aucune reprise de leur plan ou de leurs images. Arrêt avant les régions pour validation du
propriétaire. Quatre groupes de rochers ajoutés à sa demande, douze positions de bulbes proposées.
Sprite peint du bulbe importé (trois animations, 18 poses), GIF et contrôle ciblé Godot 4.3 réussis.
Les régions et collisions restent à faire. Aucun changement dans `src/`, `data/` ou les collisions.

## Sprites des Enfants du magma et Pyrevorn — livré pour revue (Codex)

Branche `codex/monstres-magma`, depuis main à jour. Les sept Calcinés (PR #55), puis les sept
Enfants du magma ont été validés par le propriétaire le 22 octobre 2026. La famille magma est
importée : quatre normaux (dont la Plongée du Rôdeur) et trois élites avec deux techniques chacune.
Contrôle ciblé final après fusion de main : 345/345 visuels chargés, sans remplacement provisoire ; import Godot et contrôle
du pipeline réussis. Voir [art/ENFANTS_DU_MAGMA.md](art/ENFANTS_DU_MAGMA.md).

Pyrevorn : quatre planches livrées, onze animations (66 poses), import et captures Godot réalisés.
Voir [art/PYREVORN_SPRITES.md](art/PYREVORN_SPRITES.md). Apparence du boss à valider ; famille magma validée.
Aucun changement de gameplay ; comportements et données restent à Claude.

## Sprites du chapitre 2 — Calcinés validés (Codex)

Validation des sept Calcinés par le propriétaire le 22 octobre 2026. Famille magma à suivre.
Branche `codex/monstres-chapitre-2` : les sept Calcinés, dont le Bond et six techniques d’élites,
avec import, GIF et contrôle d’échelle dans Godot. Validation du propriétaire avant les Enfants
du magma et Pyrevorn, conformément à la révision du 22 octobre. Complément : Dévoreur des Sources
du chapitre 1, apparence validée et quinze animations préparées. Aucun changement de gameplay.
Suite demandée : quatorze scènes VFX Godot du Dévoreur (dont télégraphes), contrat de raccordement
et prompt pour Claude ; captures et aperçus dans `docs/previews/devourer-vfx/`.
Voir [art/MONSTRES_CHAPITRE2.md](art/MONSTRES_CHAPITRE2.md).

## Reprise de session (Claude, 22 octobre 2026)

Fait : attaque de mêlée jouée au contact et mort visible des ennemis (24 corps au plus, fondu), test
`test_enemy_animations`. Carte 6 : décor, collisions et mini-carte prêts. Prochain lot proposé : intégrer la carte 6
(fiches des 7 Calcinés et leurs mécaniques, arène en zones avec sols brûlants, gardien ; effort high), puis régler le
Dévoreur après l'essai du propriétaire.

## Dévoreur des Sources en jeu (Claude, 22 octobre 2026)

Boss de la Source des Cascades (carte 5, finale du chapitre 1), `data/bosses/source_devourer.tres`. Phase 1 :
griffes et balayage de racines (secteurs), double écrasement, souffle de Faille, appel de Corrompus ; phase 2 à
mi-vie (seuil en données) avec les variantes renforcées. Le souffle s'arrête au premier obstacle réel : les deux
rochers-abris de la cour protègent. Les effets peints de Codex suivent le combat (télégraphe `indicator.tscn`,
impact au repère de contact, 8 effets décoratifs au plus) ; seuls les dangers du jeu font des dégâts. Invocations
sur sol praticable, plafonnées. Rugissement d'entrée, réaction aux gros coups, repos de phase 2. `rift_fragment`
non utilisé (aucune attaque à fragments). Tests : `test_source_devourer`. Captures : option `--finale` de
`tools/screenshot.gd`.

Point d'entrée de toutes les décisions de conception validées par le propriétaire du projet.
Chaque sujet a son document détaillé dans `docs/design/`. **Avant de travailler sur le gameplay,
lire ce fichier puis le document concerné.** Les décisions « validées » ne se remettent pas en cause
sans l'accord du propriétaire ; les « questions ouvertes » se tranchent avec lui.

Dernière mise à jour : 16 octobre 2026.

## Vision

Un survivor-like 2D (attaque automatique, hordes) avec la profondeur de build, la difficulté exigeante
mais juste et la rejouabilité de **Hades**. Une **campagne courte en chapitres** de cartes (3 à 6 h), puis
20 à 30 h de rejouabilité : mode Cauchemar et Pacte, objectifs de cartes, prophéties, modes, et des
**trophées jusqu'au platine**.

## Décisions validées (14 octobre 2026)

| Sujet | Décision | Détail |
|---|---|---|
| Campagne | 6 à 10 h (18 oct.) : 5 chapitres de 5 cartes, une particularité de terrain par carte, Dévoreur à la fin de chaque chapitre ; finir une carte débloque la suivante | [design/CAMPAGNE.md](design/CAMPAGNE.md), [design/CARTES.md](design/CARTES.md) |
| Rejouabilité des cartes | Toute carte débloquée est rejouable à l'infini ; 3 objectifs par carte et par difficulté ; récompenses dégressives | idem |
| Difficultés (16 oct.) | **Tension supprimée** ; Normal, puis **Cauchemar** (New Game+) débloqué en finissant le jeu, sur chaque carte, avec le **Pacte** (malus au choix, score par carte) | [design/LONGEVITE.md](design/LONGEVITE.md) |
| Modes | ~70 % vagues par zone (mode principal), ~30 % variantes (au moins une par chapitre) ; Survie au chrono hors campagne sur la Plaine fracturée | idem, [design/LONGEVITE.md](design/LONGEVITE.md) |
| Vagues par zone | Zones fermées par des barrières qui tombent quand les vagues sont nettoyées, puis arène du boss | [design/MODE_VAGUES_PAR_ZONE.md](design/MODE_VAGUES_PAR_ZONE.md) |
| Ruines des Cascades | Zone 1 : 3 vagues ; zone 2 : 5 vagues avec élites dès la 1re ; arène : Nébulorax (+ Échos et invocations) | idem |
| Attaque de base | Automatique | [design/COMPETENCES_ET_BUILDS.md](design/COMPETENCES_ET_BUILDS.md) |
| Sorts et touches | **Révisé le 24 oct.** : les deux mains au clavier, plus de visée à la souris ; sorts et Techniques partent dans la direction du Chasseur (ennemi le plus proche dans le cône devant lui) ; ZQSD ; sorts du Chasseur → ↑ ← ↓ ; Techniques des Échos A, E, F ; reconfigurables | idem |
| Build (permanent) | Arbre du Chasseur + un arbre par Écho (passifs + compétences), points limités, réversible ; plusieurs builds enregistrés, choisis avant le départ | idem |
| Arbre du Chasseur v2 (16 oct.) | Apprendre (Éclats) / activer (points) ; 4 voies, 12 sorts dont défensifs et techniques, 4 équipés ; passifs transformants ; ≈ 10 500 Éclats, gains −30 % | [design/ARBRE_DU_CHASSEUR.md](design/ARBRE_DU_CHASSEUR.md) |
| Montées de niveau | Conservées et distinctes du build : renforcent temporairement le build pendant l'expédition, avec raretés | idem |
| Longévité | Cauchemar et Pacte, prophéties (défis à long terme), trophées internes reliés aux succès Steam, platine | [design/LONGEVITE.md](design/LONGEVITE.md) |
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
| A2 | Ruines des Cascades configurées (3 + 5 vagues, élites, Nébulorax) et équilibrage XP / durée | Claude | A1 | Fait (15 oct.) — à rééquilibrer après les sorts. 18 oct. : collisions peintes par le propriétaire, arène murée (barrières d'entrée à l'arrivée, sans cercle d'énergie) |
| A3 | Visuels : mur d'énergie violette des barrières + animation de dissolution, flèche de direction, effet d'ouverture de l'arène | Codex | — (intégration avec A1) | Livré (Codex), validation visuelle du propriétaire |

### Étape B — Campagne

| Lot | Contenu | Qui | Dépend de | État |
|---|---|---|---|---|
| B1 | Données chapitre / carte, déblocage en avançant, objectifs par carte, récompenses dégressives, Normal / Cauchemar par carte (suppression de la Tension), migration de sauvegarde | Claude | A1 | Fait (17/10) — chapitre 1 : Ruines des Cascades puis Hautes Terres d'Orage, voir [design/CAMPAGNE.md](design/CAMPAGNE.md) |
| B2 | Refuge : sélection chapitre → carte, objectifs visibles ; Plaine fracturée en mode Survie hors campagne | Claude (code) + Codex (habillage) | B1 | Code fait (17/10) : chapitres en cartes, résumé et départ toujours visibles ; habillage à affiner (Codex) |
| B3 | Cartes 3 à 5 du chapitre 1 puis chapitres 2 à 5 (25 cartes, plan dans [design/CARTES.md](design/CARTES.md)), familles de monstres, particularités de terrain | Codex (images, décor, créatures) + propriétaire (collisions peintes, validation) + Claude (zones, modes, particularités) | A1 pour les cartes en vagues | Plan validé (18 oct.) ; briques B1, B2, B3, B6, gardien et défense d'autel faits (19 oct.). Carte 3 « Bois des Lucioles » jouable dans la campagne (21 oct., qualité conforme). Carte 4 « Gué des Brumes » jouable dans la campagne (21 oct.), sceau de Codex en jeu. Carte 5 : composition (Codex). |

### Étape M — Deux modes de jeu (décision du 21 octobre 2026, [design/MODES.md](design/MODES.md))

| Lot | Contenu | Qui | Dépend de | État |
|---|---|---|---|---|
| M1 | Séparation des modes : campagne par jalons (pas d'XP, un choix par jalon : mutations, Échos, reliques ; jalon renforcé), survie avec les montées de niveau | Claude | — | Fait (21 oct.) : bot comme avant sur les 4 cartes |
| M2 | Campagne de survie (5 étapes sur les cartes existantes, vagues à la suite) + carte bonus géante à vagues infinies débloquée à la fin | Claude | M1 | Fait (21 oct.) : « Épreuves de survie » (piste à part) et « Faille sans fin » ; carte géante dessinée à prévoir (Codex) |
| M2b | Collection d'Échos étalée sur 3 chapitres (16 Échos, les moins forts d'abord ; capture garantie sur une carte, récompenses, boutique), [design/COLLECTION_ECHOS.md](design/COLLECTION_ECHOS.md) | Claude | M2 | Fait (21 oct.) ; Échos de boutique en vente avec M3 |
| M3 | Boutique unique (éclats) : Consommables, Survie, Apparences | Claude (+ Codex pour les apparences) | M1 | Fait (21 oct.) : onglet Boutique (Échos en vente, 3 consommables à emporter, 3 avantages de survie) ; apparences : trois propositions livrées (Codex, 28 octobre), sans import ni prix ; validation avant raccordement |

### Étape C — Sorts et builds

| Lot | Contenu | Qui | Dépend de | État |
|---|---|---|---|---|
| C1 | Visée au curseur, indicateur au sol, lancement de 2 sorts du Chasseur (A, E), touches reconfigurables | Claude | — | Fait (16 oct.) : Taille fendante et Lance prismatique, réticule, aperçu en option, barre de sorts, touches du clavier dans les options |
| C2 | Arbre du Chasseur v2 (passifs + compétences, branches exclusives, réversible) et builds enregistrés au refuge | Claude | C1 | Fait (16 oct.) : apprendre/activer, tronc + 4 voies, 3 builds, 12 sorts et leurs 24 variantes, 8 passifs transformants, 4 clés de voûte, sauvegarde v2, gains d'Éclats −30 % |
| C3 | Arbres des Échos et sorts des Échos visés (1, 2, 3) | Claude | C2 | Fait (17 oct.) : 7 arbres de 5 nœuds, 7 seconds sorts visés, Points d'Écho = 1 + maîtrise, onglet Échos — [design/ARBRES_DES_ECHOS.md](design/ARBRES_DES_ECHOS.md), à valider |
| C4 | Raretés des choix de niveau (commun → héroïque) | Claude | C2 | À faire ; choix de niveau en réserve faits (18/10, sans pause en plein combat, voir design/COMPETENCES_ET_BUILDS.md) |
| C5 | Effets visuels des sorts, icônes des sorts et des nœuds d'arbre | Codex (+ images du propriétaire) | C1, puis au fil des sorts | En cours (Codex) |
| C6 | Équipe à 3 Échos max ; 8 affinités (remplacent « arcane » et « contrôle ») avec bonus à 2 et 3 Échos ; « Prédateurs » devient une synergie d'affinité | Claude | — | Fait (17 oct.) : 16 bonus d'affinité, affinités au bestiaire |
| C7 | Les 9 nouveaux Échos en jeu : données, attaques, sorts, arbres, duos nommés, textes FR/EN | Claude | C3, C6 et les sprites (C8) | Fait (18 oct.) : 9 Échos, 18 sorts, 4 statuts, 8 duos, effets et icônes de Codex raccordés — [design/ECHOS.md](design/ECHOS.md), à valider |
| C8 | Sprites des 9 nouveaux Échos (+ Mirelle) : prompts, génération, import | Codex (génération autorisée, prompts, import, contrôle) | — | Livré (Codex), PR #25 |

C5, habillage fonctionnel de l’arbre après fusion de la PR #16 : **En cours (Codex)**.
Écran 1280 × 720, états et connexions, builds et équipements ; règles de progression inchangées.
Mise à jour du propriétaire : génération des 24 icônes confiée à Codex, puis import par le pipeline commun.

C5, première livraison du 16 octobre : maquettes de l’arbre, 38 éléments graphiques,
24 prompts d’icônes et effets autonomes de Taille fendante / Lance prismatique avec variantes.
Raccordement C2 : [fiche visuelle](art/CHASSEUR_C5.md) et [captures](previews/c5/README.md).
Les images d’icônes et les dix autres familles d’effets ont été livrées dans les suites ci-dessous.
Retour du propriétaire pris en compte : animations enrichies (armé, balayage, filaments, cristaux et dispersion), rendu à valider.
Suite C5 livrée pour validation visuelle : [pilote de Taille fendante](art/TAILLE_FENDANTE_PILOTE.md)
avec textures dessinées, poses du Chasseur, impact sur une cible et démonstration dans la Plaine.
Référence d’intention : rythme et impact de Hades,
avec les personnages et la palette alliée de Rift Hunters. Aucune modification de `src/`.
Vérification en vraie partie ajoutée : HUD, Écho et vagues existants, contacts C1 confirmés,
impact limité en taille et en occurrences ; vidéo 1080p dans `docs/previews/c5/live/`.
Le raccordement au lancement normal reste à réaliser par Claude dans C1/C2.
Suite C5 livrée : dix autres familles et leurs variantes (30 configurations), en réutilisant les textures existantes.
Décision du propriétaire : pas de nouvelle génération d’image ni de vidéo d’aperçu pour cette suite ; contrôle ciblé final.
Les douze familles du Chasseur ont maintenant leurs scènes autonomes ; [contrat des dix suivantes](art/AUTRES_SORTS_C5.md).
Raccordement C1/C2 et validation en jeu à suivre ; les 24 icônes sont désormais intégrées à l’écran fonctionnel.

### Étape D — Longévité

| Lot | Contenu | Qui | Dépend de | État |
|---|---|---|---|---|
| D1 | Trophées internes + platine (reliés à Steam plus tard), à partir des 18 objectifs actuels | Claude | B1 | À concevoir |
| D2 | Modes variantes (défense d'autel, fermeture de failles…), un par chapitre | Claude + Codex | A1, B1 | Fermeture de failles faite (18/10, Hautes Terres) ; visuels des failles livrés par Codex (A3/D2) ; défense d'autel faite (19/10, visuel du sceau : Codex) ; autres modes à concevoir |
| D3 | Le Pacte (≈ 10 malus, score par carte) et prophéties | Claude | B1 | À concevoir |
| D4 | Mode Cauchemar (règles, boss enragés) | Claude | B1, C2 | À concevoir |

### Étape E — Publication

Voir « À faire avant la publication Steam » ci-dessous et [STEAM.md](STEAM.md).

## À décider lors du test complet du chapitre 1

À rappeler au propriétaire quand il teste réellement tout le chapitre 1 (décision du 22 octobre 2026 : mis de côté).

- **Saut et tunnel pour les élites du chapitre 1** ([design/MONSTRES.md](design/MONSTRES.md), mécaniques E1 et E2) :
  Saut pour la Chimère des sommets et le Chevalier fulgurant, Tunnel pour le Gardien des menhirs et la Couveuse ; rendu
  fait par le jeu (arc et ombre, enfoncement et traînée de terre) faute de rangées dédiées, planche B de Codex
  facultative. Effort estimé : high. Appliquer ou non.

## Documents de référence

- Conception : [GDD.md](GDD.md) (état actuel du prototype), [design/CAMPAGNE.md](design/CAMPAGNE.md), [design/ECHOS.md](design/ECHOS.md),
  [design/MODE_VAGUES_PAR_ZONE.md](design/MODE_VAGUES_PAR_ZONE.md),
  [design/COMPETENCES_ET_BUILDS.md](design/COMPETENCES_ET_BUILDS.md), [design/ARBRE_DU_CHASSEUR.md](design/ARBRE_DU_CHASSEUR.md),
  [design/LONGEVITE.md](design/LONGEVITE.md), [design/CARTES.md](design/CARTES.md) (25 cartes et particularités)
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

C5 — En cours (Codex), 17 octobre : réorganisation visuelle par familles de sorts avec bifurcations A/B locales, talents séparés et illustrations HD conservées ; validation visuelle du propriétaire en attente dans la PR #18.

C5 / B2 — En cours (Codex), 17 octobre : 35 illustrations HD des Échos intégrées et Expédition habillé sur codex/echos-expedition ; captures 720p dans docs/previews/echo-expedition/, validation visuelle du propriétaire attendue. Règles des arbres et gameplay inchangés.

C8 — Livré (Codex), 18 octobre, PR #25 (sprites), après la PR #24 (préparation) : 11 créatures (9 nouvelles, Mirelle et Cendrelame), 55 animations et 429 poses importées. Captures Godot des 16, aperçu animé et contrôles réussis ; sensation en partie à confirmer par le propriétaire. Aucun changement de gameplay C7.

A3 + visuels D2 — Livré (Codex), 18 octobre : rideaux continus en hauteur, maillage animé dans Godot et huit poses dessinées à 12 images/s, apparition 0,5 s et dissolution 1,2 s ; flèche, portail du boss, failles et sorties des Corrompus. Cercles au sol retirés à la demande du propriétaire. Captures et contrat dans docs/art/BARRIERES_FAILLES_A3.md ; branche codex/barrieres-failles après PR #26. Règles de jeu inchangées.

C5-bis / préparation C7 — Livré (Codex), 18 octobre : 27 scènes d'attaque/sort, 9 statuts, 9 indicateurs, 45 icônes HD importées. Animations natives Godot, matière animée et détails adaptatifs ; aucune modification de src/ ni des données de gameplay. Contrat : docs/art/ECHOS_C7_EFFETS.md ; 9 captures 720p et 18 GIF dans docs/previews/c7-echos/. Import, contrôles visuels ciblés et tools/run_tests.sh complet verts ; raccordement par Claude (C7), validation artistique du propriétaire à suivre.

C5-ter — Livré (Codex), 18 octobre : 32 scènes autonomes des sept Échos d’origine, contrat C5-bis conservé ; 7 captures 720p, 21 GIF et mesures à 90 Corrompus/24 effets. Import, contrôle du contrat et tools/run_tests.sh complet verts (230 tests). Raccordement des sorts et comportements réservé à Claude ; validation artistique en attente. Contrat : docs/art/ECHOS_ORIGINE_EFFETS.md. Une passe supplémentaire sur les animations des 16 Échos, au niveau des compétences du Chasseur, est demandée après les 30 icônes manquantes.

C5-icônes — Livré (Codex), 18 octobre : 30 illustrations du Chasseur (18 passifs et 12 améliorations du refuge), après C5-ter en PR #32. Icônes 512 px avec mipmaps, planche 112/48 px, cinq captures 720p et contrôle des 78 nœuds ; 231 tests et tools/run_tests.sh complet verts. Seul changement src/ : ICON_ALIASES de HunterTreeSkin. Validation artistique du propriétaire à suivre.

C5 — Reprise des animations des 16 Échos : Livré (Codex), 19 octobre, après PR #32 et #33. Rubans pleins, palettes corrigées, projectiles et impacts plus visibles, détail réduit en saturation ; 16 captures et 48 GIF 720p, exports silencieux. Contrats des 77 scènes, import, manifeste et lint ciblés verts ; mesures à 90 Corrompus/24 effets. Aucun changement de gameplay. Fiche : docs/art/ANIMATIONS_ECHOS_VISIBILITE.md ; validation artistique du propriétaire à suivre.


### Sceau ancien — visuel du mode défense d’autel

Livré (Codex, 21 octobre) : objet peint animé, cinq animations précalculées par Godot, icône 64 px, sources et aperçus dans docs/previews/altar-seal/. Contrôle assets : 313 valides, 0 erreur ; aucune modification de gameplay. En attente de raccordement par Claude.

### Source des Cascades — compositions

Propositions livrées pour revue (Codex, 21 octobre) : deux compositions ; base A retouchée à la demande du propriétaire avec quatre parties et trois ponts uniques. Fiche docs/maps/SOURCE_DES_CASCADES.md ; mesures et courants à valider. Aucune région ni collision produite.

### Source des Cascades — passe de détail

Visuels livrés (Codex, 21 octobre) : 16 régions et retouches de matière, export final contrôlé conforme ; 100 % des secteurs, fidélité 0,986, aucune case résiduelle à référence initiale figée. Plan à quatre parties, trois ponts et deux rochers-abris conservé ; collisions du propriétaire et intégration Claude à suivre.

### Lisière calcinée — carte 6, Terres dévastées

Composition livrée pour validation (Codex, 21 octobre) : lisière brûlée et masque de dix plaques contrôlé. Arène polygonale à deux rochers-abris ; circulation à confirmer par le propriétaire. Arrêt avant régions, collisions et gameplay. Voir docs/maps/LISIERE_CALCINEE.md.

### Passe de détail des cartes 5 et 6

Visuels livrés (Codex, 21 octobre) : 16 régions pour Source des Cascades, 12 pour Lisière calcinée. Arènes distinctes, deux abris espacés chacune ; rapports qualité conformes et comparaisons d’échelle livrés. Collisions du propriétaire et intégration Claude à venir.

Carte 6 : 12 régions assemblées, rapport qualité conforme (94,3 % de secteurs, fidélité 0,978), planche d’échelle et carte de netteté livrées. Deux secteurs de gorge fumante restent signalés. Collisions du propriétaire et intégration Claude à venir.

## B3 — Carte 11, Mangrove des racines : visuels livrés pour revue (Codex)

Branche codex/carte-root-mangrove. Parcours en boucle, lagon et île à accès unique, nappes de vase. Carte 10 publiée dans la PR #76 ; carte 12 après cette livraison. Poursuite autonome autorisée par le propriétaire.
