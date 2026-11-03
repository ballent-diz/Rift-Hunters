# Montée en difficulté

Statut : **décisions du propriétaire du 23 octobre 2026** (leviers terrain, monstres, hordes ; règle des abris) et
propositions de Claude acceptées dans le même échange. Complète [MONSTRES.md](MONSTRES.md) (monstres et techniques)
et [CARTES.md](CARTES.md) (briques de terrain).

## Principe

La difficulté augmente **en continu**, d'une carte à l'autre et d'un chapitre à l'autre, en tirant sur plusieurs
leviers à la fois, jamais sur un seul. Chaque carte en pousse **deux ou trois** un cran plus loin que la précédente,
et en apporte au moins **un nouveau** (mécanique de carte, technique de monstre, composition de horde).

## Les leviers

| Levier | Ce qui monte | Exemples |
|---|---|---|
| **Terrain** | nouvelles mécaniques de carte, espaces plus étroits, plus d'obstacles, abris nécessaires | crues, sol brûlant, bulbes de braise ; couloirs, corniches ; rochers-abris contre les souffles |
| **Monstres** | nouvelles techniques, nouveaux monstres, élites plus fournies | Bond, Plongée, Charge, Éruption ; familles par chapitre (MONSTRES.md) |
| **Hordes** | densité, cadence, présents en même temps | `ZoneWaveData.count`, `spawn_rate`, `max_alive` |
| **Composition** | rôles mélangés dans une même vague | tanks devant, tireurs derrière, bondisseurs sur les flancs ; deux familles ensemble en fin de chapitre |
| **Directions d'arrivée** | d'où vient la horde | de face, puis par les flancs, puis encerclement |
| **Soutiens** | ennemis à abattre en priorité | soigneur, porteur de bouclier, totem qui renforce les autres (à créer) |
| **Élites en duo** | techniques qui se combinent | Toile de suie (entrave) + Charge ; Couvée + Éruption |
| **Pression du temps** | moins de répit | pause entre vagues plus courte, dangers de carte plus fréquents |
| **Récupération** | soins plus rares | `LevelZoneData.heal_ratio` : 25 % au chapitre 1, vers 15 % au chapitre 5 |
| **Visibilité** | lecture plus difficile | fumée, cendres, nuit (brique B2) sur certaines cartes |
| **Gardiens et Dévoreurs** | combats plus longs et plus riches | plus de phases, attaques combinées |

Le mode Cauchemar et les pactes restent le lieu des extrêmes ; la campagne Normal suit la courbe ci-dessous.

## Règle des abris (tous les chapitres)

**Personne ne tire à travers le décor** : les tirs des monstres, du Chasseur et des Échos s'arrêtent sur les rochers,
les murs et les falaises (champ de collisions de la carte et obstacles du décor) ; les souffles et les rayons sont
coupés par eux. Les attaques au sol (geysers, écrasements, impacts de bond) et le corps à corps ne le sont pas : on
s'en protège en esquivant. Les cibles en vue sont préférées par le tir automatique et les Échos.

Exceptions : les monstres qui creusent (Plongée) et les unités volantes passent ; un tir peut être déclaré
« fantôme » (`ghost` : tir en cloche, créature volante) et traverser.

Limite connue : le champ de collisions ne distingue pas l'eau des rochers ; une rivière arrête donc aussi les tirs.
Un masque de tir séparé pourra être ajouté si une carte le demande.

Code : `ObstacleField.blocks_shot`, `clear_distance`, `line_clear` ; `ProjectileManager._hits_decor` ;
`HazardManager.add_beam` (rayon tronqué) et secteurs (ligne de vue) ; `EnemyManager.find_nearest_visible`.

**Abris posés par le jeu** (demande du propriétaire, 3 novembre 2026) : les cartes peintes récentes laissent leurs
aires de combat dégagées, sans rocher au milieu. `ArenaData.cover_rocks` (et `cover_radius`) ajoute des rochers
indestructibles au champ d'obstacles avant la navigation (`CoverRocks`) : ils arrêtent le passage, les tirs et les
souffles comme le décor. Placés d'abord dans l'arène de Glauquemire (carte 15) ; dessin provisoire en attendant le
sprite `object.cover_rock` demandé à Codex.

## Garde-fou : la courbe mesurée

La difficulté ne doit jamais dépasser la progression du joueur (jalons, Échos, boutique, arbre). Le jeu vise un défi
réel (décision du propriétaire, 2 novembre 2026) : on galère un peu pour passer une carte, sans se décourager, et on
sent une marge de progression sur son build comme sur son jeu. À chaque carte, mesure au bot
(`tools/balance_sim.sh`, `PROFILE=stage`) :

- **profil d'étape** (`tests/smoke/stage_profile.gd`) : le bot reçoit ce qu'un joueur moyen-bon aurait débloqué en
  arrivant sur la carte (progression rejouée avec les vraies règles : Éclats des victoires, d'environ 1,6 tentative par
  carte et de la moitié des objectifs, 20 % laissés à la boutique ; Points de Chasseur ; emplacements de sorts ; sceau
  d'Écho ; maîtrise et arbres des Échos ; équipe des Échos les plus récents). Carte 1 : 2 sorts, 6 points, Cendrelame
  seule ; carte 13 : 4 sorts et leurs variantes, 24 points, 3 Échos ;
- **bot moyen-bon** (`AutopilotBrain`) : il connaît les mécaniques, réagit à la plupart des tirs, garde sa Taille
  fendante pour les groupes et les cibles fortes ;
- **victoires** autour de **2 sur 3** (entre 50 et 80 %) : un joueur moyen-bon perd parfois, un débutant devra
  progresser ;
- **carte spéciale de nuit** (décision du propriétaire, 3 novembre 2026) : chaque chapitre a une carte de nuit (brique
  B2, ajoutée par-dessus ses mécaniques sans les changer) : chapitre 1 Bois des Lucioles, chapitre 2 Tanières de suie
  (braises flottantes), chapitre 3 Mangrove des racines, chapitre 4 à choisir. Elle se règle **un cran au-dessus** des
  autres cartes : environ **1 victoire sur 2** au bot moyen-bon ;
- **durée** qui augmente doucement d'une carte à l'autre (environ 6 à 9 minutes au chapitre 1, 9 à 12 au chapitre 2) ;
- **dégâts subis** en hausse progressive.

**Chaque nouvelle carte** (décision du propriétaire, 23 octobre 2026) : une passe courte avec le bot sur cette carte
seulement (`PROFILE=stage`, 3 graines, `SIM_TIMEOUT=2400`), avant la pull request. Les cartes
déjà livrées ne sont pas remesurées d'office : le propriétaire les règle pendant ses propres tests.

Une carte qui sort de la courbe est corrigée par ses propres réglages (`enemy_hp_mult`, `enemy_damage_mult`, vagues)
avant de toucher aux monstres eux-mêmes. Les boss et gardiens ont leurs propres réglages (`boss_hp_mult`,
`boss_damage_mult`), car ils ne suivent pas ceux des vagues.

### Réglages mesurés (campagne Normal, profil d'étape, bot moyen-bon : 2 et 3 novembre 2026)

Mesure `PROFILE=stage`, 3 graines par carte (4 pour les Tanières) : le bot reçoit à chaque carte la progression d'un
joueur moyen-bon (sorts, points, Échos les plus récents, arbres ; voir plus haut). Cible : 2 victoires sur 3.
Le 3 novembre, le bot sort aussi des recoins trop étroits pour sa route en revenant sur ses pas (graine 3 des
Hautes Terres, qui tournait en rond).

| Carte | Vagues (PV · dégâts) | Boss ou gardien (PV · dégâts) | Bot (victoires) | Durée |
|---|---|---|---|---|
| 1. Ruines des Cascades | 0,4 · 0,4 | 0,5 · 0,5 (Nébulorax) | 2 sur 3 | 7 min à 7 min 30 |
| 2. Hautes Terres d'Orage | 0,85 · 0,8 | 0,9 · 0,85 (Astravorn) | 2 sur 3 | 6 min |
| 3. Bois des Lucioles | 0,85 · 0,8 | 1 · 1 (Sentinelle des Racines) | 2 sur 3 | 7 à 8 min |
| 4. Gué des Brumes | 0,97 · 0,97 | 1,2 · 1,17 (Chimère des Brumes) | 2 sur 3 | 5 min 30 à 6 min |
| 5. Source des Cascades | 0,6 · 0,55 | 1 · 1 (Dévoreur des Sources) | 2 sur 3 | 6 min 30 |
| 6. Lisière calcinée | 0,85 · 0,8 | 1,4 · 1,15 (Gardien du bûcher) | 2 sur 3 | 6 min |
| 7. Évents de cendre | 1,3 · 0,95 | 2,5 · 1,2 (Chevalier calciné) | 2 sur 3 | 7 min 45 |
| 8. Tanières de suie (nuit) | 1,65 · 1,3 | 3,8 · 1,95 (Reine-veuve) | 2 sur 4 | 7 min 30 à 8 min 45 |
| 9. Le Seuil du Cataclysme | 1,07 · 0,68 | 2,15 · 1,25 (Matrone des scories) | 2 sur 3 | 6 min 15 à 7 min 15 |
| 10. Cœur du volcan | 0,7 · 0,45 | 0,5 · 0,6 (Pyrevorn) | 2 sur 3 | 10 min |
| 11. Mangrove des racines (nuit) | 0,95 · 0,55 | 2,5 · 1,25 (Gardien d'écorce) | 2 sur 4 | 6 min 10 à 6 min 50 |
| 12. Temple des marées | 1,4 · 0,65 | 1,25 · 0,58 (Gueule des marais) | 2 sur 3 | 3 min |
| 13. Jardins de cristal | 1 · 0,5 | 1,9 · 1 (Mère des spores) | 2 sur 3 | 5 min |
| 14. Puits des reflets | 1,3 · 1,8 (autel frappé à 0,36) | 1 · 2,4 (Dame des portails) | 3 sur 4 | 5 min 30 à 6 min 30 |
| 15. Cœur des marais | 1 · 0,7 (marée, vase) | 1,6 · 1,15 (Glauquemire, cinq abris) | 3 sur 4 | 5 min 30 à 6 min 20 |

Tanières de suie et Mangrove des racines (3 novembre) : passées en cartes de nuit, réglées autour de 1 victoire sur 2
(défaites à 2 % et 13 % de PV du gardien). Avant la nuit, Tanières de suie : à 3 sur 3 avec un gardien tombé en une minute, la Reine-veuve passe de 3 · 1,4 à
3,8 · 2,1 et les vagues de 1,2 à 1,4 en dégâts (une défaite à 8 % de PV du gardien sur 4 parties).

Mesures du 26 octobre 2026, avec le bot corrigé :
- il va chercher les derniers Corrompus ;
- la flèche le ramène à la zone en cours ;
- il sort des recoins et des fentes du décor.

Avant ces corrections, des vagues traînaient de 2 à 4 minutes (jusqu'à 15 minutes pour la carte 5), et le bot restait
parfois bloqué. Les cartes 3 et 4, à 4 sur 4, sont au bord haut de la cible : à surveiller en test.

Cartes 7 à 12 mesurées le 31 octobre 2026 (arbre « veteran », 3 graines, Cendrelame + les deux Échos les plus forts
débloqués à ce stade). La carte 12, en fermeture de failles, reste courte comme la carte 2.

## Ce que le bot sait faire (pour lire ses résultats)

Le bot (`AutopilotBrain`) fuit les ennemis proches (plus fort devant les élites et les boss), évite les zones
télégraphiées, les crues et le sol brûlant, esquive de côté les tirs et les charges, utilise la Ruée quand il est
acculé ou menacé, s'écarte du décor, suit la route des zones (et va chercher les derniers Corrompus pendant la
traque, sans fuir les élites), lance ses deux sorts dès qu'une cible est à portée (bouclier
sous 60 % de PV), déclenche les Techniques des Échos dès qu'il y a plus de 8 ennemis et donne l'ordre de focus sur le
boss. Il cherche un abri contre les tirs et les souffles sept fois sur dix (`COVER_REACTION`), casse les
œufs, amorce les bulbes entourés de Corrompus, vise les points faibles et les gardiens, et joue les mécaniques phares
des boss (Ruée dans les orbes, entrée dans la couronne, cases des cratères retenues sept fois sur dix, lanternes
brisées, pas de côté face à la charge, Ruée à travers un miroir). Il n'attire pas les hordes dans les dangers, ne place
pas exprès un rocher derrière lui face à la charge du bûcher et ne gère pas finement ses placements : c'est un joueur
prudent mais peu tactique. Ses taux de victoire sont donc un repère prudent ; un joueur qui exploite les abris et les
mécaniques fait mieux.
