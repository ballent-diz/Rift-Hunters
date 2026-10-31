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

## Garde-fou : la courbe mesurée

La difficulté ne doit jamais dépasser la progression du joueur (jalons, Échos, boutique, arbre). À chaque carte,
mesure au bot (`tools/balance_sim.sh`, `META=veteran`) :

- **victoires** autour de **75 %** (entre 60 et 90 %) ;
- **durée** qui augmente doucement d'une carte à l'autre (environ 6 à 9 minutes au chapitre 1, 9 à 12 au chapitre 2) ;
- **dégâts subis** en hausse progressive.

**Chaque nouvelle carte** (décision du propriétaire, 23 octobre 2026) : une passe courte avec le bot « joueur moyen »
sur cette carte seulement (2 Échos de départ × 1 à 2 graines, `SIM_TIMEOUT=2400`), avant la pull request. Les cartes
déjà livrées ne sont pas remesurées d'office : le propriétaire les règle pendant ses propres tests.

Une carte qui sort de la courbe est corrigée par ses propres réglages (`enemy_hp_mult`, `enemy_damage_mult`, vagues)
avant de toucher aux monstres eux-mêmes. Les boss et gardiens ont leurs propres réglages (`boss_hp_mult`,
`boss_damage_mult`), car ils ne suivent pas ceux des vagues.

### Réglages mesurés (campagne Normal, règles du 26 octobre 2026 : un Écho au départ, pas de drops)

Équipe du bot : Cendrelame et les Échos réellement débloqués à ce stade (un par carte gagnée), arbre « veteran » à
partir de la carte 4.

| Carte | Vagues (PV · dégâts) | Boss ou gardien (PV · dégâts) | Équipe du bot | Bot (4 graines) | Durée |
|---|---|---|---|---|---|
| 1. Ruines des Cascades | 0,4 · 0,4 | 0,5 · 0,5 | Cendrelame seule | 3 sur 4 | 6 à 7 min |
| 2. Hautes Terres d'Orage | 0,6 · 0,55 | 0,65 · 0,6 | + Sylvécaille | 3 sur 3 | 3 min 30 à 5 min |
| 3. Bois des Lucioles | 0,85 · 0,8 | 1 · 1 | + Sylvécaille, Scoriade | 4 sur 4 | 6 min 30 |
| 4. Gué des Brumes | 0,75 · 0,75 (autel 5 500 PV) | 1 · 1 | + Sylvécaille, Lueurine | 4 sur 4 | 6 min |
| 5. Source des Cascades | 0,6 · 0,55 | 1 · 1 | + Lueurine, Sporelune | 3 sur 4 | 5 à 7 min |
| 6. Lisière calcinée | 0,7 · 0,6 | 1,2 · 1 | + Lucivelle, Sporelune | 3 sur 4 | 3 min 30 à 6 min |
| 10. Cœur du volcan | 0,7 · 0,45 (vagues de moitié, une élite par palier) | 0,5 · 0,6 (Pyrevorn) | + Gravelune, Pyraile | 3 sur 3 | 9 à 11 min 30 |
| 11. Mangrove des racines | 0,7 · 0,35 (une élite par zone) | 1,2 · 1 (gardien provisoire) | + Solgriffe, Gravelune | 2 sur 3 | 6 min 30 |
| 12. Temple des marées | 1 · 0,5 (45 à 120 en vie, élites des failles toutes les 140 s) | 1,2 · 1 (gardien provisoire) | + Ronceline, Solgriffe | 2 sur 3 | 3 min |

Mesures du 26 octobre 2026, avec le bot corrigé :
- il va chercher les derniers Corrompus ;
- la flèche le ramène à la zone en cours ;
- il sort des recoins et des fentes du décor.

Avant ces corrections, des vagues traînaient de 2 à 4 minutes (jusqu'à 15 minutes pour la carte 5), et le bot restait
parfois bloqué. Les cartes 3 et 4, à 4 sur 4, sont au bord haut de la cible : à surveiller en test.

Cartes 10 à 12 mesurées le 31 octobre 2026 (arbre « veteran », 3 graines). La carte 12, en fermeture de failles, reste
courte comme la carte 2 ; ses gardiens (et ceux des cartes 7 à 9) sont provisoires. Les cartes 7 à 9 restent à mesurer
avec leurs gardiens propres.

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
