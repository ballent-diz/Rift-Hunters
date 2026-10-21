# Cartes de campagne et particularités

Statut : **proposition du 18 octobre 2026, à valider carte par carte par le propriétaire**. Cadre : [CAMPAGNE.md](CAMPAGNE.md)
(structure, modes, rejouabilité), [../MAP_GUIDELINES.md](../MAP_GUIDELINES.md) et
[../maps/GENERER_UNE_CARTE.md](../maps/GENERER_UNE_CARTE.md) (fabrication des images).

## Décisions

- **Jeu plus long** : **5 chapitres de 5 cartes**, soit 25 cartes et une campagne d'environ 6 à 10 heures, plus le
  Cauchemar, les objectifs et les trophées.
- **Une particularité par carte** (sauf les deux premières, cartes d'apprentissage) : une règle de terrain qui
  change la façon de jouer, présentée en une phrase sur la fiche de la carte.
- **Production tenable** : une famille de monstres par chapitre, plus 1 ou 2 créatures liées au décor de chaque
  carte ; un **Dévoreur** (nouveau boss) en dernière carte du chapitre ; ailleurs, un **gardien** (élite renforcée
  qui réutilise un sprite, avec ses propres attaques) ou le boss d'une carte précédente.
- **Familles du chapitre 1** (décision du propriétaire, 21 octobre 2026) : la famille violette de la Faille (grouillard,
  bondisseur, carapace, cracheur ; élites rôdeur d'ombre, couveuse, gardienne de cristal) sur les cartes 1 à 3 ; la
  famille des Hautes Terres (coureur des landes, triton de cendre, scarabée d'ardoise, harpie argentée ; élites
  chevalier fulgurant, gardien des menhirs, chimère des sommets) en **finale du chapitre**, cartes 4 et 5. Le sceau
  du Gué retenait la première bête des Hautes Terres : le briser ouvre la finale. La carte 2 (Hautes Terres) garde son
  décor et son boss Astravorn, avec les hordes violettes.

## Règles des particularités

1. **Une particularité principale par carte.** Les cartes 4 et 5 d'un chapitre peuvent en combiner deux.
2. **Jamais la même brique deux cartes de suite.**
3. **Une brique revient d'un chapitre à l'autre sous un autre habillage** (les crues du chapitre 1 deviennent des
   coulées de lave au chapitre 3) : presque le même code, une autre expérience pour le joueur.
4. **Pas de frustration** : tout danger est télégraphié et toute gêne touche aussi les ennemis. La particularité
   doit offrir une occasion tactique, pas seulement une punition.
5. **Données, pas de code par carte** : chaque brique est un système réglé dans `ArenaData` (comme les zones et les
   failles) ; une carte choisit ses briques et leurs réglages.

## Catalogue des briques

| # | Brique (codée une fois) | Déclinaisons selon le décor | Occasion tactique |
|---|---|---|---|
| B1 | **Terrain qui change le mouvement** | gué (ralentit), glace (glisse), courant (pousse), boue (colle), ronces (blessent) | attirer les hordes dans le terrain lent |
| B2 | **Vision réduite** | nuit et lucioles, brume, tempête de sable, pluie de cendres | les sources de lumière deviennent des points d'appui |
| B3 | **Danger périodique télégraphié** | crues, éboulements, éclairs, geysers, coulées de lave | placer les ennemis sous le danger |
| B4 | **Passages qui changent** | ponts qui s'effondrent, marée qui découvre des chemins, portes runiques qui tournent | choisir son itinéraire au bon moment |
| B5 | **Éléments à utiliser** | tonneaux explosifs, totems de soin à activer, cristaux à faire éclater, cloches qui étourdissent | déclencher au cœur des groupes |
| B6 | **Raccourcis** | troncs creux, téléporteurs de faille, tyroliennes, courants à suivre | se dégager ou traverser vite |
| B7 | **Ressource limitée** | chaleur (braseros dans la neige), oxygène (grottes inondées), lumière qui s'épuise | gérer ses déplacements entre les refuges |
| B8 | **Ennemis liés au lieu** | nids qui pondent, statues qui s'éveillent, créatures qui fuient la lumière | choisir ses cibles prioritaires |
| B9 | **Règle de la carte** | gravité basse (projectiles lents), écho (chaque sort se relance faiblement), sol corrompu (renforce qui y reste) | adapter son build |
| B10 | **Objectif secondaire facultatif** | Échos piégés à libérer, sceaux à briser, élite rare à traquer avant sa fuite | récompense contre prise de risque |

## Les 25 cartes

Thèmes et particularités des chapitres 2 à 5 : pistes, à remplacer par les images et idées du propriétaire. Chaque
chapitre a son propre type de paysage (terrain, architecture, végétation, couleurs).

### Chapitre 1 — Le Val des Cascades

Identité : vallée tempérée et humide. Pierre grise moussue, ruines anciennes, pins et feuillus, cascades et rivières,
herbes dorées en altitude ; touches violettes de la Faille. Famille : les Corrompus des Ruines et des Hautes Terres.

| Carte | Mode | Format | Particularité | Fin |
|---|---|---|---|---|
| 1. Ruines des Cascades | Vagues par zone | 3 cases | aucune (apprentissage) | Nébulorax |
| 2. Hautes Terres d'Orage | Fermeture de failles | 9 cases | aucune pour l'instant (éclairs B3 possibles plus tard) | Astravorn |
| 3. Bois des Lucioles | Vagues par zone | 6 cases | **B2 Nuit et lucioles** : vision réduite ; les clairières de lucioles éclairent et révèlent les ennemis | Gardien |
| 4. Gué des Brumes | Défense d'autel (nouveau mode) | 6 cases | **B1 Gués** : l'eau peu profonde ralentit tout le monde ; y attirer les hordes | Gardien |
| 5. Source des Cascades | Vagues par zone, plus dure | 9 cases | **B3 Crues** télégraphiées et courant qui pousse, + **B6** courants à suivre | **Dévoreur du chapitre** |

### Chapitre 2 — piste : les Terres colorées (images annoncées par le propriétaire)

| Carte | Mode | Particularité |
|---|---|---|
| 6 | Vagues par zone | B5 Cristaux à faire éclater |
| 7 | Variante (escorte ou zone qui se resserre) | B4 Ponts qui s'effondrent |
| 8 | Vagues par zone | B8 Nids qui pondent |
| 9 | Fermeture de failles | B9 Gravité basse |
| 10 | Vagues + Dévoreur | B2 Tempête de couleurs + B5 |

### Chapitre 3 — piste : les Forges volcaniques

| Carte | Mode | Particularité |
|---|---|---|
| 11 | Vagues par zone | B3 Coulées de lave |
| 12 | Défense d'autel | B5 Tonneaux de poudre |
| 13 | Vagues par zone | B1 Cendres chaudes qui brûlent |
| 14 | Variante | B6 Wagonnets / rails |
| 15 | Vagues + Dévoreur | B3 Éruptions + B8 Statues de lave |

### Chapitre 4 — piste : le Glacier silencieux

| Carte | Mode | Particularité |
|---|---|---|
| 16 | Vagues par zone | B1 Glace qui fait glisser |
| 17 | Fermeture de failles | B7 Chaleur des braseros |
| 18 | Vagues par zone | B2 Blizzard |
| 19 | Variante | B4 Banquise qui se fend |
| 20 | Vagues + Dévoreur | B9 Écho des sorts + B1 |

### Chapitre 5 — piste : la Cité de la Faille

| Carte | Mode | Particularité |
|---|---|---|
| 21 | Vagues par zone | B9 Sol corrompu |
| 22 | Défense d'autel | B4 Portes runiques |
| 23 | Vagues par zone | B6 Téléporteurs de faille |
| 24 | Fermeture de failles | B8 Statues qui s'éveillent + B10 |
| 25 | Vagues + Dévoreur final | Combinaison des briques du jeu |

## Réalisé

### Brique B2 « nuit et lucioles » (19 octobre 2026)

- Réglages dans `ArenaData` (groupe « Nuit et lucioles ») : `night` (opacité du voile, 0 = jour), `light_radius`
  (lumière du Chasseur), `echo_light_radius`, `firefly_glades` (centres des clairières) et `firefly_radius`.
- `src/run/night_director.gd` : voile dessiné dans le monde (shader `assets/shaders/night_veil.gdshader`), percé de
  halos autour du Chasseur, des Échos, du boss et des clairières (16 lumières au plus) ; lucioles animées au-dessus.
- **On ne cible que ce qu'on voit** : tirs automatiques, Échos et sorts à cible automatique ne visent que les ennemis
  éclairés, Révélés ou le boss. Les sorts visés au curseur et les zones touchent tout le monde.
- Les clairières **révèlent** les ennemis qui y passent (statut Révélé, +12 % de dégâts subis) : Lueurine et ses
  lucioles prennent tout leur sens de nuit.
- Les télégraphes de danger sont dessinés au-dessus du voile (et désormais au-dessus des Corrompus sur toutes les
  cartes) : aucun danger caché.
- Essai sans carte dédiée : `--night` sur `tests/smoke/autoplay.tscn` et `tools/screenshot.tscn` (clairières placées
  aux points clés de la carte choisie, `tools/test_arena.gd`).

### Gardien de fin de carte

- `BossData.guardian` et `BossData.visual_scale` : boss de carte en une phase, sur le sprite d'une élite agrandi,
  avec barre verte « Gardien · nom » et annonce « Le gardien … s'éveille ! ».
- Premier gardien : **Sentinelle des Racines** (`data/bosses/root_sentinel.tres`), menhir habité par les racines,
  pour le Bois des Lucioles : griffes, ruée tellurique, séisme à deux anneaux, appel de Corrompus du sous-bois.
- Essai : `--boss=root_sentinel` (avec `--boss-at=20` sur la Plaine fracturée).
- Deuxième gardien : **Chimère des Brumes** (`data/bosses/mist_chimera.tres`), ce que le sceau du Gué retenait, sur
  le sprite de la chimère des sommets agrandi : griffes de givre, **pas de brume** (motif `blink` : elle se dissout et
  surgit près du Chasseur, frappe télégraphiée à l'arrivée ; elle parcourt ainsi toute la carte), bond des cimes,
  rugissement d'orage (anneaux à trois brèches), appel de la meute des Hautes Terres.

### Mode « défense d'autel » (carte 4)

- Réglages dans `ArenaData` (groupe « Défense d'autel ») : `altar_waves` (0 = désactivé), `altar_point`, `altar_hp`
  (2000), `altar_radius`, `altar_wave_duration` (40 s), `altar_wave_pause` (8 s), `altar_spawn_rate` (1,3 par seconde,
  +20 % par vague), `altar_damage_mult` (part des dégâts de contact subie par l'autel, 0,3), `altar_raider_share`
  (0,4) et `altar_spawn_points` (arrivées des vagues ; vide = tout autour de l'autel).
- `src/run/altar_director.gd` : vagues de durée fixe ; une partie des Corrompus de corps à corps (les **pillards**) suit
  sa propre route vers l'autel et l'abîme à son contact (6 à la fois au plus). Entre deux vagues, le sceau se répare
  (+15 %) et un coffre tombe (il ouvre aussi les choix de niveau en réserve). Après la dernière vague, **le sceau se
  brise** : son onde purifie les Corrompus restants, le gardien de la carte en sort, et le sceau disparaît avec sa
  collision (`ObstacleField.remove`, la navigation rouvre ses cases) : le combat s'étend à toute la carte.
  Autel détruit pendant les vagues : défaite.
- HUD : barre du sceau, vague en cours ou à venir et secondes restantes ; flèche vers l'autel si le Chasseur s'en
  éloigne. Visuel : sceau ancien peint par Codex (`object.altar_seal`) — intact, fendu sous 50 % de PV, éclat à chaque coup, onde qui s'efface quand il se brise ; barre de vie juste au-dessus du sceau. Le sceau
  entier est **solide** (personne ne le traverse) ; les pillards le frappent depuis son bord. Feuille agrandie ×2
  (`tools/art/upscale_sheet.py object.altar_seal 2`, à relancer après une nouvelle cuisson) pour avoir la finesse du
  décor peint ; teinte accordée aux cartes et ombre portée vers le bas à droite.
- Essai : `--altar` sur la Plaine fracturée (sceau au centre, 5 vagues, Sentinelle des Racines à la fin). Bot
  (graine 3) : 4 victoires sur 4 (Mousseroc, Cendrelame, Lueurine, Solgriffe) en 4 min 17 à 4 min 39.

### Brique B1 « gués » (carte 4)

- Réglages dans `ArenaData` (groupe « Terrain lent ») : `slow_zones` (rectangles d'eau peu profonde, dans le repère
  de la carte) et `slow_zone_mult` (vitesse dans l'eau, 0,6).
- `src/run/terrain_director.gd` : ralentit **tout le monde** dans l'eau, Chasseur, Échos et Corrompus
  (`RunContext.terrain_speed`). **La Ruée garde sa pleine vitesse** : c'est la porte de sortie. Tactique : attirer
  les hordes dans le gué et les y frapper pendant qu'elles pataugent.
- Lisibilité : teinte, bord et ondulations animées par-dessus le sol (sur la carte définitive, l'eau sera peinte
  dans l'image ; les rectangles suivront les gués du dessin).
- Même code pour les déclinaisons futures (boue, neige, cendres) : seul l'habillage change.
- Essai : `--shallows` (trois gués sur la Plaine fracturée, combinable avec `--altar`). Bot Cendrelame (graine 3,
  autel + gués) : victoire en 4 min 25.

### Briques B3 « crues » et B6 « courants » (carte 5)

- **Crues** (groupe « Crues » d'`ArenaData`) : `flood_lanes` (lits de rivière, rectangles) et `flood_dirs` (sens du
  flot), `flood_first` (30 s), `flood_interval` (18 s de calme), `flood_warning` (3 s), `flood_duration` (3,5 s),
  `flood_push` (300 px/s), `flood_damage` (6 toutes les 0,5 s, × dégâts ennemis de la difficulté) et
  `flood_enemy_ratio` (12 % des PV max d'un Corrompu toutes les 0,5 s).
- `src/run/flood_director.gd` : les lits débordent **à tour de rôle**. Alerte de 3 s (l'eau monte, bord de danger
  clignotant et chevrons dans le sens du flot, dessinés au-dessus des Corrompus et du voile de nuit), puis la crue
  emporte et blesse tout ce qui s'y trouve. Le Chasseur en sort par le côté ou par la **Ruée** (invulnérable, sans
  dérive) ; un Corrompu qui reste dans la crue en meurt presque toujours. Boss et Échos épargnés. Annonce à la
  première crue.
- **Courants** (groupe « Courants ») : `currents`, `current_dirs` et `current_speed` (140 px/s). Le Chasseur et les
  Corrompus y dérivent (les lourds moins, selon leur résistance au recul) : le suivre est un **raccourci**, le
  remonter coûte cher. Pas de dérive pendant la Ruée ; boss et Échos (liés au Chasseur) épargnés.
- Code commun : `RunContext.terrain_drift` (courants + crue) et `RunContext.danger_vector` (le bot sort du lit
  pendant l'alerte). Les déclinaisons futures (coulées de lave, éboulements) réutilisent `FloodDirector` avec un
  autre habillage.
- Essai : `--rivers` (deux lits qui se croisent et un courant sur la Plaine fracturée, première crue à 15 s).

### Échelle des cartes 3 et 4 (21 octobre 2026)

- Pavés, rochers et socles des cartes 3 et 4 étaient environ 1,5 fois trop gros pour le Chasseur (comparés aux Ruines
  au même zoom). Les deux mondes sont réduits ×0,8 par `tools/art/rescale_arena.py <arène> 0.8` : tuiles
  rééchantillonnées (toujours 2,25 pixels par unité), manifeste et positions du `.tres` mis à l'échelle. Taille :
  4013 × 2675 unités. Contrôle de qualité toujours conforme (détails fins 421 pour le Bois, 433 pour le Gué).

### Carte 3 « Bois des Lucioles » en jeu (21 octobre 2026)

- Plan : composition peinte et validée par le propriétaire (`map_source.png`), collisions peintes dessus.
- Image : 12 régions générées par Codex, assemblées par `tools/art/map_regions.py` (netteté native calibrée) ;
  contrôle `check_map_quality.py` conforme (détails fins 333, secteurs 97 %, fidélité au plan 0,99).
- Niveau (`data/arenas/firefly_woods.tres`) : 3 zones (Prairie du Sous-bois, Clairière du Sanctuaire, Plateau de
  Mousse) séparées par 3 barrières (chemin nord, tête ouest du pont, entrée de la clairière du gardien) ; arène du
  gardien murée ; nuit 0,82 et 6 clairières de lucioles ; gardien : Sentinelle des Racines. Carte 3 du chapitre 1.
- Traque : quand le dernier Corrompu d'une vague est loin (> 700 unités), la flèche de route mène à lui.
- Bot (graine 3) : Cendrelame 6 min 19, Lueurine 6 min 20, Solgriffe 7 min 00, Mousseroc 6 min 21 à 7 min 46
  (graines 3, 5, 7), après remplacement de l'élite Gardien-menhir de la dernière vague par la Gardienne de cristal.

### Carte 4 « Gué des Brumes » en jeu (21 octobre 2026)

- Image : 12 régions de Codex assemblées (`map_regions.py`), contrôle conforme (détails fins 353, fidélité 0,99).
- Collisions peintes par le propriétaire sur la carte détaillée ; l'eau profonde est peinte, les gués restent
  praticables (`collision_mask.py overlay mist_ford … --no-water`).
- Niveau (`data/arenas/mist_ford.tres`) : défense d'autel, sceau sur le cercle peint du centre (-1, -163), 5 vagues
  de 50 s, sceau à 4000 PV (2400 avant qu'il devienne solide : son bord plus large l'expose davantage), 1,2 apparition par seconde, 6 arrivées en bord de carte ; 4 gués en terrain lent (B1, déjà
  peints : `slow_zones_painted`) ; XP × 1,4 ; hordes et élites de la famille des Hautes Terres ; gardien : Chimère des
  Brumes, qui sort du sceau brisé. Carte 4 du chapitre 1.
- Bot : 8 victoires sur 8 (4 Échos, graines 3, 5, 7), 5 min 03 à 5 min 56, niveau 17 à 18. Après la mise à
  l'échelle et le sceau solide : 8 sur 8 (Mousseroc et Cendrelame, graines 1 à 4), 5 min 04 à 5 min 20 ; Bois 4 sur 4.
  Avec les Hautes Terres et la Chimère des Brumes : 7 sur 8 (graines 1 à 4), 5 min 05 à 5 min 19.
- Carte 2 avec les hordes violettes : 2 victoires sur 8 au bot (sans bonus d'arbre), contre 0 sur 8 avec ses
  monstres d'origine : la carte était déjà la plus dure pour le bot ; son équilibrage reste à revoir à part.

## Ordre de réalisation

1. Chapitre 1, carte 3 (Bois des Lucioles) : image (Codex), collisions peintes (propriétaire), zones, brique B2 et
   gardien (Claude).
2. Carte 4 : mode défense d'autel et brique B1.
3. Carte 5 : briques B3 et B6, Dévoreur du chapitre.
4. Chaque brique codée devient réutilisable pour les chapitres suivants.
