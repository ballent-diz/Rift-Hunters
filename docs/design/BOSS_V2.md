# Boss de la v2 (3D) : état d'import depuis la v1

Audit du 15 novembre 2026 (session « Boss »), sans code. Sources : `draft3d/roster.gd`, `draft3d/enemies.gd`
(`_boss_brain`), `draft3d/run.gd`, `draft3d/tuning.gd` pour la v2 ; `data/bosses/*.tres`,
`src/entities/bosses/*.gd`, `docs/design/MONSTRES.md`, `DEVOREUR_CHAPITRE3.md` et le manifeste d'assets pour la v1.
Retour de test à traiter : « **Boss de fin de chapitre pas assez dynamiques** » (`docs/RETOURS_DE_TEST.md`, 10 nov.).

## 1. Comment la v2 choisit ses boss

- **Une carte 3D par chapitre** (`DraftLevel.create`). Le bestiaire est lu dans les cinq cartes v1 du chapitre
  (`DraftRoster.for_chapter`) : chaque `ArenaData.boss_id` devient un gardien, le dernier (carte 5) devient le boss final.
- **4 min** (`guardian_time`) : un gardien **tiré au hasard** parmi ceux du chapitre, PV × 0,55 × 0,45 ; le vaincre ne
  termine pas la partie.
- **8 min** (`boss_time`) : le **Dévoreur** du chapitre au lieu d'apparition de la carte (`level.boss_spot`), PV × 0,55,
  dégâts × 0,8 ; le vaincre donne la victoire.
- **Nébulorax** est écarté (`EXCLUDED_BOSSES`, décision du 13 novembre) : sa carte v1 n'a pas d'équivalent.

## 2. Carte → boss

| Ch. | Carte 3D (fichier) | Gardien à 4 min (un au hasard) | Boss final à 8 min |
|---|---|---|---|
| 1 | Ruines des Veilleurs (`level_ruins.gd`) | Astravorn, Sentinelle des racines, Chimère des brumes | **Dévoreur des Sources** |
| 2 | Cimetière des Cendres (`level_graveyard.gd`) | Gardien du bûcher, Chevalier calciné, Reine-veuve, Matrone des scories | **Pyrevorn** |
| 3 | Hameau du Gué (`level_village.gd`) | Gardien d'écorce, Gueule des marais, Mère des spores, Dame des portails | **Glauquemire** |
| 4 | Avant-poste des Glaces (`level_outpost.gd`) | Patriarche des cimes, Chaman ancestral, Loup alpha des tempêtes, Colosse de la banquise | **Nivorath** |
| 5 | Cité Effondrée (`level_city.gd`) | Commandant déchu, Golem du sanctuaire, Gardienne du Panthéon, Grand Héraldiste | **Abyssarque** |

Absent de la v2 : Nébulorax (v1 carte 1). Astravorn, boss à 2 phases en v1 (carte 2), n'est en v2 qu'un gardien
tiré au hasard.

## 3. Ce que fait un boss v2 aujourd'hui (identique pour les 24)

Un seul cerveau commun (`DraftEnemies._boss_brain`) ; seuls PV, dégâts, vitesse, rayon, feuille de sprites et
famille PixelFX viennent des données v1.

| Point | v2 actuelle |
|---|---|
| Sorts | 5 techniques communes : griffes (cercle devant, < 4,5 m), onde d'ombre (anneau, doublé en phase 2), pluie (3 puis 5 cercles sur le Chasseur), invocation (4 puis 6), rayon du vide (ligne, phase 2 seulement) |
| Phases | 2, seuil fixe à 50 % PV ; la phase 2 ne change que le temps de recharge (2,6 → 1,9 s) et les nombres |
| Stratégie | tirage aléatoire ; immobile 1 à 1,6 s pendant chaque technique, sinon poursuite en ligne droite (navigation) ; ni charge, ni bond, ni repositionnement, ni enchaînement, aucune mécanique phare |
| Données ignorées | `phases` (seuils, `patterns`, poids, recharges, annonces, `move_speed_mult`, `defense_override`, `transition_time`, `mechanics`), `signature`, `intro_animation`, `hurt_ratio`, `vfx_dir`, `death_visual_id` |
| Animations | idle / move automatiques ; à chaque technique, premier clip présent parmi une liste fixe (`_clip`) ; mort : clip `death` 0,6 s, corps retiré après 2,5 s |
| Non joué | `transform` au changement de phase, `phase2_idle` / `phase3_idle`, `swap_visual` par phase, intro, `hurt`, clip de mort dédié, effets peints (`assets/vfx/bosses/source_devourer`, `glauquemire`) |
| Effets | PixelFX par famille (`techniques.json`, `boss_families`) : charge d'anneau, éclat d'anneau, pluie, griffes, apparition |

C'est la cause directe du retour « pas assez dynamiques » : un boss v2 avance, s'arrête, frappe, recommence.

## 4. Boss → état d'import

Légende : **C** importé complet · **P** partiel · **N** non importé. Les « sorts » de la v2 étant communs, aucun boss
n'a ses sorts propres : P signifie que ses stats et sa feuille sont repris, avec les techniques communes.

### Dévoreurs (boss finaux)

| Boss | Sorts et phases v1 | Stratégie / mécanique phare v1 | Animations v1 | Sorts | Strat. | Anim. | Manques précis |
|---|---|---|---|---|---|---|---|
| **Dévoreur des Sources** (ch. 1) | 2 phases (50 %) : griffes, balayage racinaire, double écrasement, souffle (arrêté par les rochers), invocations ; phase 2 : versions `phase2_*` | **Orbes de source** : orbes lents qui suivent le Chasseur, renvoyés au boss par une Ruée, l'orbe doré l'étourdit ; touchés sans Ruée : dégâts + ralenti | feuille de 15 clips (`roar` d'intro, `hurt`, `transform`, `phase2_idle`, `phase2_slam`, `phase2_breath`, `root_sweep`) + effets peints (`vfx_dir`) | P | N | P | orbes et renvoi par Ruée, étourdissement ; souffle en cône bloqué par le décor ; double écrasement ; balayage ; intro `roar`, `transform`, `phase2_*` ; effets peints |
| **Pyrevorn** (ch. 2) | 2 phases : griffes, pluie du cratère, couvée ; phase 2 : envol et chute, Œil de la Faille (rayon qui balaie), + 2 mini-boss | **Séquence des cratères** : grille 3 × 3, cases allumées une à une puis éruption dans le même ordre | 12 clips (`brood_call` d'intro, `crater_rain`, `skyfall`, `rift_eye`, `transform`, `phase2_idle`) | P | N | P | grille de cratères à mémoriser (à poser sur le parvis de la crypte) ; envol et chute (invulnérable en l'air, anneaux de lave) ; rayon qui balaie ; mini-boss ; intro, `transform`, `phase2_idle` |
| **Glauquemire** (ch. 3, refonte PR #156) | 3 phases (66 / 33 %) : griffes, écrasement ; P1 vase qui durcit en murs, racine jaillissante, sangsues (soin plafonné) ; P2 carapace à facettes, miroirs ; P3 tourbillon, raz-de-marée à traverser | **Miroirs à orienter** : une Ruée tourne le miroir ; le rayon de prisme suit les miroirs, renvoyé sur le boss il brise la carapace et l'étourdit | 15 clips (`mud_spit`, `root_lash`, `leech_call`, `prism_beam`, `whirlpool`, `swallow`, `phase2_idle`, `phase3_idle`) + effets peints | P | N | P | les 8 mécaniques de `GlauquemireMechanics` (789 lignes, en 2D) ; 3e phase ; `swallow` (engloutit un Écho) à remplacer, pas d'Échos en v2 ; idle par phase ; effets peints |
| **Nivorath** (ch. 4) | 3 phases (66 / 33 %) : griffes, pics de glace (ligne), souffle de blizzard, invocations ; P3 banquise qui éclate, plongée sous la glace | **Écho des sorts** (`spell_capture`) : gueule ouverte, chaque sort lancé est aspiré puis renvoyé en couronne ; aucun sort : il s'étouffe, sonné | 12 clips (`spell_capture`, `spell_release`, `frozen_dive`, `shatter_floor`, `ice_spikes`, `blizzard_breath`, `transform`) | P | N | P | capture des sorts (colle aux sorts actifs de la v2) ; pics en ligne ; banquise ; plongée ; 3e phase ; `transform`, `spell_release` |
| **Abyssarque** (ch. 5) | **6 formes** (82 / 64 / 46 / 30 / 14 %) : griffes partout ; base : onde d'ombre ; racines : laisse de racines ; magma : souffle, envol et chute ; cristal : pluie de roches ; glace : pics, sol qui éclate ; faille : rayon qui balaie, onde, invocations | **Échos des mondes** (`abyss_echoes`) : invoque tour à tour les monstres des 5 chapitres, en vague qui s'étend | 7 feuilles : `boss.abyssarch` (4 clips seulement), `.roots`, `.magma`, `.crystal`, `.ice`, `.rift` avec leur clip d'entrée, et `.death` (`collapse`, `eye_close`) | P | N | **P (faible)** | aucun `swap_visual` : il reste toute la partie sur la forme de base (4 clips) ; 6 phases ; Échos des mondes ; entrées de forme ; mort dédiée `boss.abyssarch.death` |

### Gardiens (tirés au hasard à 4 min)

Tous : 2 phases à 50 % en v1 (sauf Sentinelle et Chimère : 1), feuille d'élite agrandie (`enemy.*`), mécanique phare
dans `GuardianSignatures`, `AshGuardians`, `MarshGuardians`, `SporeGuardian`, `PortalGuardian`, `FrostElder` ou
`BossSignatures`. En v2 : techniques communes, aucune mécanique phare, clips propres non joués (la liste de `_clip`
ne les contient pas). Statut commun : **sorts P · stratégie N · animations P**.

| Gardien | Ch. | Techniques v1 | Mécanique phare v1 manquante | Clips propres non joués |
|---|---|---|---|---|
| Astravorn | 1 | griffes, onde d'ombre, invocations, rayon du vide (P2) | **Couronne d'astres** (anneau tournant à brèches, coups extérieurs absorbés à 85 %) | `phase2_attack` partiel ; pas de 2e phase propre |
| Sentinelle des racines | 1 | griffes, charge, invocations | **Séisme** : anneaux sans brèche à franchir d'une Ruée | — (4 clips) |
| Chimère des brumes | 1 | griffes, pas de brume, bond, onde, invocations | **Voile de brume** : 3 lanternes à briser, sinon intouchable et soin | — (4 clips) |
| Gardien du bûcher | 2 | balayage, bûcher écrasé, invocations ; P2 charge | **Charge du bûcher** : s'assomme contre un obstacle | `pyre_slam`, `blazing_rage` |
| Chevalier calciné | 2 | charge, taille tournoyante, invocations | **Cercle du duel** (feu, coups × 1,5 dedans ; volet Échos sans objet) | `charge`, `spinning_slash` |
| Reine-veuve | 2 | toile, ponte, P2 charge | **Fils tendus** : collent 1,2 s, la Ruée les tranche, bond sur la proie | `soot_web`, `lay_eggs` |
| Matrone des scories | 2 | écrasement, couvée | **Carapace à fendre** : seule une roche qui tombe la fend 10 s | `slag_molt`, `brood` |
| Gardien d'écorce | 3 | balayage, racines, invocations | **Garde d'écorce** : bouclier frontal pivotant (× 0,1 de face, × 1,5 de dos) | `bark_shield`, `roots`, `armor_break` |
| Gueule des marais | 3 | charge ventrale, balayage, invocations | **Plongée** : ride qui suit, onde de sortie, sonnée 2 s | `belly_charge`, `dive`, `rage` |
| Mère des spores | 3 | tapis de spores, pulsation, balayage | **Voile de spores** brûlé par le rayon d'un cristal-miroir (cristaux absents de la carte 3D) | `spore_carpet`, `pulse` |
| Dame des portails | 3 | saut de portail, reflets, balayage | **Saut de portail** + reflets | `blink`, `reflections`, `mirror_guard` |
| Patriarche des cimes | 4 | avalanche, bond, rage, balayage | **Avalanche** : boule qui grossit, éclate contre le décor | `avalanche`, `pounce`, `rage` |
| Chaman ancestral | 4 | gel profond, brume, prison de glace | **Gel profond** : souffle les braseros (froid et braseros absents de la v2) | `snuff`, `frost_mist`, `ice_prison` |
| Loup alpha des tempêtes | 4 | glissade, chasse dans la tempête, balayage | **Chasse dans la tempête** | `slide` |
| Colosse de la banquise | 4 | charge, fissure, balayage | **Séisme de banquise** (fissures qui ralentissent) | `charge`, `ice_crack`, `armor_break` |
| Commandant déchu | 5 | charge, cri de ralliement, invocations | **Cri de guerre** (renforce ses Corrompus) | `rallying_cry`, `shield_wall` |
| Golem du sanctuaire | 5 | écrasement, barrage de runes | **Barrage de runes** + armure de dalles | `slab_armor` |
| Gardienne du Panthéon | 5 | onde de pierre, éveil des statues | **Éveil du panthéon** (statues qui s'animent) | `stone_wave`, `awaken_statues` |
| Grand Héraldiste | 5 | charge, chaîne d'âme, invocations | **Chaîne d'âme** (lien à briser) + sceau | `soul_link`, `corruption_seal` |

Écarté : **Nébulorax** (absorption puis cœur exposé) : non importé, par décision.

## 5. Ce qui manque en commun (socle)

1. **Cerveau piloté par les données** : lire `BossData.phases` (seuils réels : 3 phases pour Glauquemire et
   Nivorath, 6 pour l'Abyssarque), `patterns` pondérés avec recharge et durée d'annonce propres, `pattern_interval`,
   `move_speed_mult`, `defense_override`. Les techniques communes deviennent des `kind` parmi d'autres.
2. **Mouvement** (retour de test) : charge annoncée, bond / chute sur le Chasseur, recul et repositionnement entre deux
   techniques, enchaînements (2 ou 3 techniques à la suite en phase haute), course autour du Chasseur ; tout passe par
   la navigation et les règles de hauteur (`hazards` limités à 1,2 m de dénivelé).
3. **Transitions** : invulnérabilité courte et clip `transform` / d'entrée, `swap_visual` (feuille par phase), idle de
   phase, intro (`intro_animation`), bandeau du nom de phase, clip `hurt` selon `hurt_ratio`.
4. **Mort** : clip de mort complet (durée de la feuille, pas 0,6 s), `death_visual_id`, fondu du corps, PixelFX de mort.
5. **Mécaniques persistantes** : équivalent 3D de `BossMechanics` (état, mise à jour, nettoyage à la mort, aide au bot),
   sans dépendre de `RunContext` ni du plan 2D.
6. **Effets peints** (Dévoreur des Sources, Glauquemire) : scènes 2D, à afficher par `Sprite3D` + `SubViewport` ou à
   remplacer par des PixelFX dédiés.
7. Mécaniques liées aux **Échos** (engloutissement de Glauquemire, volet Échos du Cercle du duel, « laisser les Échos
   occuper » le Gardien d'écorce) : à remplacer, pas d'Échos en v2 ; mécaniques liées à un **décor v1** absent des
   cartes 3D (cristaux-miroirs, braseros, pluie de roches de la carte 9, grille de cratères) : à poser dans la carte.

## 6. Efforts estimés

S : une demi-session · M : une session · L : deux sessions ou plus. Chaque lot : tests unitaires + partie bot.

| Lot | Contenu | Effort |
|---|---|---|
| 0 | Socle : cerveau data, mouvement et enchaînements, transitions, intro, mort, mécaniques persistantes 3D | **L** |
| 1 | Dévoreur des Sources : orbes renvoyés par la Ruée, souffle bloqué par le décor, double écrasement, `phase2_*` | M |
| 2 | Gardiens ch. 1 : Couronne d'astres, Séisme, Voile de brume (lanternes) | M |
| 3 | Pyrevorn : grille de cratères, envol et chute, Œil de la Faille, mini-boss | M |
| 4 | Gardiens ch. 2 : charge du bûcher, cercle du duel, fils tendus, carapace à fendre | M |
| 5 | Glauquemire : 3 phases, vase-murs, racine, sangsues, facettes et miroirs, tourbillon, raz-de-marée ; remplacer l'engloutissement | **L** |
| 6 | Gardiens ch. 3 : garde d'écorce, plongée, voile de spores (cristaux à poser), saut de portail | M |
| 7 | Nivorath : capture des sorts actifs, pics, banquise, plongée, 3 phases | M |
| 8 | Gardiens ch. 4 : avalanche, gel profond (froid à adapter ou remplacer), chasse, fissures | M |
| 9 | Abyssarque : 6 formes et `swap_visual`, Échos des mondes, techniques de chaque forme, mort dédiée | **L** |
| 10 | Gardiens ch. 5 : cri de guerre, barrage de runes, éveil du panthéon, chaîne d'âme | M |
| — | Effets peints en 3D (Sources, Glauquemire) | S à M |

## 7. Plan d'import proposé (ordre de priorité)

1. **Lot 0, le socle**, d'abord : il rend tous les boss plus dynamiques d'un coup (réponse directe au retour de test)
   et permet de brancher ensuite chaque boss en données plus une mécanique.
2. **Chapitre 1** : Dévoreur des Sources (lot 1), puis ses trois gardiens (lot 2). Premier boss vu par tous les
   joueurs : il sert de référence de « boss dynamique » à valider en jouant avant la suite.
3. **Chapitre 2** : Pyrevorn (lot 3), gardiens (lot 4).
4. **Chapitre 3** : Glauquemire refondu (lot 5), gardiens (lot 6).
5. **Chapitre 4** : Nivorath (lot 7), gardiens (lot 8).
6. **Chapitre 5** : Abyssarque (lot 9), gardiens (lot 10).

Une session et une PR par lot (règle 7). Chaque Dévoreur avant ses gardiens : c'est lui qui conclut la partie.
Feu vert du propriétaire le 16 novembre (« go pour tout »). Choix retenus par défaut, à revoir en jouant :
- un seul gardien, tiré au hasard, à 4 min (inchangé) ;
- Nébulorax reste écarté (décision du 13 novembre) ;
- mécaniques liées aux Échos : remplacées par un équivalent pour le Chasseur seul, précisé dans chaque lot ;
- mécaniques liées à un décor v1 absent (cristaux-miroirs, braseros, roches qui tombent, grille de cratères) : le
  boss pose lui-même ces éléments dans l'arène 3D.

## 8. Avancement

### Lot 0 — socle commun (16 novembre)

`draft3d/boss_brain.gd` (`DraftBossBrain`) remplace le cerveau commun ; `draft3d/boss_mechanic.gd`
(`DraftBossMechanic`) est la base des mécaniques phares des lots suivants.
- **Données** : phases et seuils d'origine (3 pour Glauquemire et Nivorath, 6 pour l'Abyssarque), techniques pondérées
  avec leurs recharge, annonce et dégâts, `pattern_interval` (× `DraftTuning.boss_pace`, 0,8), `move_speed_mult`,
  `defense_override`, `params.anim`.
- **Gestes 3D** : chaque `kind` des données (47 au total) joue un geste : griffes, balayage en arc, écrasement (double
  dès la phase 2), onde, séisme (trois anneaux), pluie, invocation (Échos des mondes de l'Abyssarque : monstres des
  cinq chapitres), rayon, rayon qui balaie, souffle en cône, ligne de pics, sol qui éclate, charge, bond, saut de faille.
  Les mécaniques phares pas encore importées jouent le geste le plus proche (`GESTURES`).
- **Mouvement** : poursuite, tournoiement autour du Chasseur à 4-6 m, recul après un gros coup ; de loin (> 11 m),
  rapprochement annoncé : charge si la voie est libre, sinon bond ou saut de faille. Une charge arrêtée par le décor
  ou un mur de faille **assomme** le boss 1,6 s (coups × 1,5) : se placer devant un obstacle paie.
- **Enchaînements** : 25 % de chances en phase 1, + 20 % par phase (70 % au plus), 1 à 3 techniques de suite.
- **Transitions** : onde annoncée, clip de transition, changement de feuille (`visual_id`, les six formes de
  l'Abyssarque), idle de phase (`phase2_idle`, `phase3_idle`), nom de la phase en bandeau ; coups × 0,2 pendant la
  transition (jamais d'invulnérabilité totale), × 0,25 en l'air.
- **Intro** (`intro_animation` ou `roar`), réaction aux gros coups (`hurt_ratio`), **mort** : feuille dédiée
  (`death_visual_id`), clip joué en entier, corps retiré après.
- Essais : `tests/unit/test_boss3d.gd`.

### Lot 1 — Dévoreur des Sources (16 novembre)

- **Orbes de source** (`draft3d/bosses/source_orbs.gd`, `DraftSourceOrbs`) : orbes lents à hauteur de poitrine qui
  suivent le Chasseur (données d'origine : nombre, écart, vitesse, durée, orbe doré). Une Ruée ou une Parade dedans le
  renvoie : 3 % des PV du boss, l'orbe doré l'étourdit 2,5 s (coups × 1,5). Touché sans Ruée : dégâts. Le décor arrête
  un orbe. Explication en bandeau la première fois (`BOSS_ORB_INTRO`).
- **Souffle arrêté par le décor** : `DraftHazards.line(..., covered)` ; un obstacle entre la gueule et le Chasseur
  l'abrite.
- Double écrasement, balayage racinaire, clips `phase2_*`, `roar` d'intro, `transform` et `phase2_idle` : socle (lot 0).
- Orbe touché sans Ruée : dégâts et ralenti 1,5 s (`DraftHunter.hinder`, ajouté au Chasseur 3D).
- Reste : effets peints (`assets/vfx/bosses/source_devourer`), remplacés par des PixelFX.
- Bot (peu habile, ne vise pas les orbes) : défaite 70 s environ après l'arrivée du boss, à juger en jouant.

### Lot 2 — gardiens du chapitre 1 (16 novembre)

- **Astravorn, Couronne d'astres** (`bosses/star_crown.gd`) : 16 étoiles, 2 brèches de 2, rayon 11,4 → 5,4 m, rotation
  qui accélère ; contact : dégâts ; de l'extérieur, coups × 0,15 ; concentré, le boss ne marche ni n'attaque ; à la fin,
  les étoiles partent en tirs vers l'extérieur (`DraftRun.hostile_shot`, nouveau tir hostile générique).
- **Chimère des brumes, Voile de brume** (`bosses/mist_veil.gd`) : 3 lanternes (`object.mist_lantern`) à 11 m, coups ×
  0,05 tant qu'une brûle ; toutes brisées : sonnée 2,5 s, coups × 2 pendant 4 s ; voile tenu 12 s : + 4 % de PV.
- **Sentinelle des racines, Séisme** : anneaux des données (nombre, écart, vitesse), un de plus à chaque phase,
  bandeau `BOSS_QUAKE_INTRO` (nouvelle clé FR/EN). Les anneaux restent coupés par le décor (règle commune des cartes 3D).

### Lot 3 — Pyrevorn (16 novembre)

- **Séquence des cratères** (`bosses/crater_sequence.gd`) : grille 3 × 3 de cases de 7,8 m posée autour du Chasseur
  (cases recalées sur la navigation), cases allumées une à une (données : nombre, écarts, pause), puis éruptions dans le
  même ordre, chacune précédée d'un éclair de 0,2 s seulement ; le boss se concentre pendant l'allumage.
- **Envol et chute** (geste `leap` avec `airborne`, commun) : il quitte l'écran (coups × 0,25), suit le Chasseur, la
  zone de chute s'annonce sous lui, puis anneaux de lave à l'atterrissage (données `rings`). Sols brûlants de la v1
  non repris (pas de système de brûlure en 3D).
- **Œil de la Faille** (geste `sweep_beam`, commun) : arc, nombre de traits et durée du balayage des données, rayon
  arrêté par le décor.
- **Mini-boss** : à sa seconde phase, Pyrevorn appelle le Titan de caldeira et le Wyrmeau de flammes (gardiens de
  palier de la carte 10 en v1), PV × 4, agrandis.

### Lot 4 — gardiens du chapitre 2 (16 novembre)

- **Gardien du bûcher, Charge du bûcher** : la charge commune lit `speed`, `length` et `stun` des données (21 m/s,
  28 m, assommé 1,8 s contre le décor), bandeau `BOSS_RAM_INTRO`.
- **Chevalier calciné, Cercle du duel** (`bosses/duel_circle.gd`) : cercle de feu de 10,5 m au moins entre lui et le
  Chasseur, 8 s (9 s en phase 2) ; dedans, coups × 1,5 ; dehors, brûlure toutes les 0,5 s. Bandeau sans les Échos
  (`BOSS_DUEL_INTRO_3D`, nouvelle clé FR/EN).
- **Reine-veuve, Fils tendus** (`bosses/silk_threads.gd`) : 4 fils (6 en phase 2) de 12,6 m autour du Chasseur, 14 s ;
  un fil touché englue 1,2 s (`DraftHunter.stick`, seule une Ruée libère) et la Reine bondit dessus ; une Ruée à
  travers un fil le tranche.
- **Matrone des scories, Carapace à fendre** (`bosses/slag_shell.gd`) : coups × 0,15 ; sa pluie de scories fait tomber
  des roches autour du Chasseur ; une roche qui tombe sur elle la fend 10 s (coups × 1,5, sonnée 1 s).

### Lot 5 — Glauquemire (16 novembre)

`bosses/glauquemire.gd` (`DraftGlauquemire`), d'après la refonte du 11 novembre (rien ne retient ni n'enferme).
- **Phase 1** : vase (3 flaques qui ralentissent, puis **murs solides** 7 s : ils bloquent le Chasseur, les tirs, les
  ondes et le rayon), racine jaillissante (ligne annoncée, éruption 1,3 s plus tard là où se tenait le Chasseur),
  sangsues qui rampent vers le boss (`Foe.follow`) et le soignent de 0,5 % chacune, 6 % au plus sur le combat.
- **Phase 2** : carapace à quatre facettes fixes (droite, bas, gauche, haut ; 30 % des coups par une face intacte,
  brisée après 3,5 % des PV, repousse 14 s) ; quatre miroirs solides à 10,8 m. **Rayon de prisme** : balaie l'arène
  (lancer de rayon physique : décor, vase durcie et miroirs l'arrêtent) ; un miroir touché alors que le Chasseur se
  tient à moins de 3,6 m le renvoie : 4 % des PV, facettes brisées, étourdi 3 s, coups × 2.
- **Phase 3** : facettes tombées, tourbillon qui aspire 4,5 s puis se referme, raz-de-marée (deux vagues : Ruée ou
  vase durcie), rayon double. **Engloutissement** : sans Échos, il avale jusqu'à 4 Corrompus proches, se soigne
  (même plafond) et les recrache en gerbe de tirs ; 5 % de ses PV en coups pendant la digestion l'étranglent (sonné).
  Bandeau `BOSS_SWALLOW_INTRO_3D` (nouvelle clé FR/EN).
- Reste : vagues du raz-de-marée sans ralenti ni recul (dégâts seuls) ; effets peints remplacés par des PixelFX et des
  formes simples (vase, murs, miroirs, rayon).

### Lot 6 — gardiens du chapitre 3 (16 novembre)

- **Gardien d'écorce, Garde d'écorce** (`bosses/bark_guard.gd`) : enraciné 7 s (8 en phase 2), bouclier qui pivote à
  0,9 rad/s vers le Chasseur ; de face (60°) coups × 0,1, de dos ou de flanc × 1,5 ; racines qui ralentissent au
  lever de la garde. Bandeau sans les Échos (`BOSS_GUARD_INTRO_3D`, nouvelle clé).
- **Gueule des marais, Plongée** (`bosses/maw_dive.gd`) : sous la surface (invisible, sans contact, coups × 0,05), une
  ride suit le Chasseur 2,5 s, l'onde de sortie s'annonce 0,9 s, puis elle ressurgit sonnée 2 s (coups × 2).
- **Mère des spores, Voile de spores** (`bosses/spore_veil.gd`) : voile dès l'arrivée (× 0,2) ; elle fait pousser
  trois cristaux solides autour d'elle (pas de cristaux-miroirs en 3D) ; une **Ruée dans un cristal** tire un rayon
  vers elle : sans décor entre les deux, le voile brûle (sonnée 5 s, coups × 2) et repousse 12 s plus tard. Tapis de
  spores autour du Chasseur. Bandeau `BOSS_SPORE_VEIL_INTRO_3D` (nouvelle clé).
- **Dame des portails, Saut de portail** (`bosses/portal_hop.gd`) : trois portails ouverts à son arrivée ; elle
  plonge 2,4 s et ressort par le portail le plus proche du Chasseur (illuminé) ; le Chasseur dedans la piège (sonnée
  5 s, coups × 2), sinon onde de prisme.
- Miroirs de Glauquemire placés en vue directe du boss (le décor 3D pouvait en cacher un).

### Lots 7 et 8 — Nivorath et gardiens du chapitre 4 (16 novembre)

- **Nivorath, Écho des sorts** (`bosses/spell_capture.gd`) : gueule ouverte 3,5 s ; chaque sort lancé
  (`DraftSpells.casts`) est aspiré puis renvoyé en couronnes de 12 tirs (3 au plus, + 25 % par sort) ; aucun sort :
  il s'étouffe, sonné 3 s, coups × 2. Gueule ouverte, tous les coups ne portent qu'à moitié (les coups de sort ne se
  distinguent pas encore des traits en 3D). Pics de glace : geste `spikes` paramétré (`lines`, `spread`, `radius`,
  `length`, une ligne de plus en phase 3) ; banquise (`burst`) et plongée (`leap`) en phase 3 ; trois phases.
- **Gardiens** (`bosses/frost_guardians.gd`, une classe, une instance par signature) :
  - **Patriarche des cimes, Avalanche** : boules de neige en éventail, annoncées par des lignes, qui grossissent en
    roulant et éclatent contre le décor ;
  - **Chaman ancestral, Grand gel** : sans braseros en 3D, un refuge de chaleur s'allume à 7 m du Chasseur ; dehors à
    la fin de l'annonce : dégâts et prison de glace (Ruée pour s'en libérer). Bandeau `BOSS_DEEP_FREEZE_INTRO_3D` ;
  - **Loup alpha des tempêtes, Chasse dans la tempête** : 3 charges (4 en phase 2), chacune d'un autre côté du
    Chasseur sur une ligne annoncée, vulnérable entre deux ; une charge contre le décor l'assomme ;
  - **Colosse de la banquise, Séisme de banquise** : onde autour de lui, plaques sous le Chasseur qui se fendent
    1,6 s puis s'ouvrent 4 s sur l'eau noire (ralenti, dégâts). Bandeau `BOSS_FLOE_QUAKE_INTRO_3D`.
- Froid et braseros de la v1 non repris.
