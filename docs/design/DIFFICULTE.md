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

Une carte qui sort de la courbe est corrigée par ses propres réglages (`enemy_hp_mult`, `enemy_damage_mult`, vagues)
avant de toucher aux monstres eux-mêmes.

## Ce que le bot sait faire (pour lire ses résultats)

Le bot (`AutopilotBrain`) fuit les ennemis proches (plus fort devant les élites et les boss), évite les zones
télégraphiées, les crues et le sol brûlant, esquive de côté les tirs et les charges, utilise la Ruée quand il est
acculé ou menacé, s'écarte du décor, suit la route des zones, lance ses deux sorts dès qu'une cible est à portée (bouclier
sous 60 % de PV), déclenche les Techniques des Échos dès qu'il y a plus de 8 ennemis et donne l'ordre de focus sur le
boss. Il **ne** cherche **pas** les abris, ne vise pas les bulbes ou les œufs exprès, n'attire pas les hordes dans les
dangers et ne gère pas finement ses placements : c'est un joueur prudent mais peu tactique. Ses taux de victoire sont
donc un repère prudent ; un joueur qui exploite les abris et les mécaniques fait mieux.
