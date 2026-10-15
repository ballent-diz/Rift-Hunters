# Mode « vagues par zone »

Statut : **validé le 14 octobre 2026**, **réalisé le 15 octobre 2026** (lots A1 et A2) ; visuels définitifs des barrières : lot A3. Sert de **base de gameplay** des
niveaux ; d'autres maps pourront utiliser d'autres modes (voir [LONGEVITE.md](LONGEVITE.md)).

## Principe

Le niveau est découpé en zones fermées par des **barrières**. Dans chaque zone, le joueur doit
**nettoyer une suite de vagues** ; à la fin de la dernière vague, les barrières de sortie disparaissent
et la zone suivante s'ouvre. La difficulté monte crescendo jusqu'à l'**arène du boss**.

## Premier niveau : Ruines des Cascades (`three_rifts`)

Carte finale du chapitre 1 de la campagne (voir [CAMPAGNE.md](CAMPAGNE.md)).

| Zone | Contenu | Barrières de sortie |
|---|---|---|
| Zone 1 (gauche) | 3 vagues de Corrompus standards | Route du haut et sortie du bas vers la zone 2 (le pont central est cassé, infranchissable) |
| Zone 2 (milieu) | 5 vagues, **élites dès la 1re vague**, difficulté croissante | Entrée du pont de droite et les deux escaliers de l'arène |
| Arène (droite) | Nébulorax en 1v1 (+ Échos du joueur et invocations du boss) | Une barrière se referme derrière le joueur à l'entrée |

Départ : en haut à gauche, devant le bâtiment. Barrières (coordonnées du monde, `data/arenas/three_rifts.tres`),
placées d'après les rectangles rouges du propriétaire puis vérifiées par connexité sur la carte des collisions :

| Barrière | Rectangle (x, y, largeur, hauteur) | Rôle |
|---|---|---|
| Route du haut | (-840, -836, 120, 276) | Zone 1 → zone 2 |
| Sortie du bas | (-1134, 690, 344, 146) | Bord de carte (ferme la route qui sort de l'image) |
| Escalier nord de l'arène | (1337, -447, 138, 356) | Zone 2 → arène |
| Entrée du pont | (777, -41, 88, 218) | Zone 2 → arène |
| Passage sud de l'arène | (1225, 360, 120, 95) | Zone 2 → arène (déplacé à l'endroit le plus étroit du passage réel) |

Vagues réglées (`three_rifts.tres`) : zone 1 = 35, 50 et 65 Corrompus ; zone 2 = 50 à 120 Corrompus et 1 à 3
élites par vague (Rôdeur, Nuée-mère, Gardien). XP des Corrompus × 1,5 sur cette carte (`xp_mult`).
Mesure au bot de test (tension 0, avant les sorts et builds) : 2 victoires sur 3 en ~7 min 30, niveau ~24 ;
à rééquilibrer quand les compétences existeront.

## Règles validées

1. **Fin de vague** : la vague est terminée quand tous ses monstres sont morts.
   - Interface : « Vague 2/3 · 12 restants ».
   - Quand il reste peu de monstres, ils sont signalés par une flèche au bord de l'écran et se
     rapprochent plus vite du joueur.
   - Sécurité : si une vague traîne trop, renforts pour relancer l'action (jamais de blocage).
2. **Apparitions** : uniquement dans la **zone en cours**, sur des points prévus de la map (jamais
   derrière une barrière, jamais dans le décor).
3. **Barrières** : mur d'énergie violette (thème Faille) qui bloque le joueur, les Échos et les
   monstres ; animation de dissolution et son quand il tombe ; une flèche indique ensuite où aller.
   La carte de flux des ennemis tient compte des barrières et se recalcule quand elles tombent.
4. **Respiration entre les zones** : quelques secondes de calme quand les barrières tombent, avec une
   récompense (coffre ou soin) ; la zone suivante démarre quand le joueur y entre.
5. **Arène** : barrière qui se referme derrière le joueur, apparition du boss avec son titre.
6. **Équilibrage** : un nombre fini de monstres rapporte moins d'XP qu'une survie au chrono ; l'XP et
   la composition des vagues sont recalibrées pour garder une progression de niveaux satisfaisante.
   Durée visée : ~3 min (zone 1), ~5 min (zone 2), 2-3 min (boss), soit 10-12 min par expédition.

## Conception technique (réalisée)

- **En données, sans code par map** : `ArenaData.zones` (`LevelZoneData` : nom, point d'ancrage, vagues
  `ZoneWaveData`, barrières de sortie, récompense). Les régions sont retrouvées par connexité sur la grille de
  navigation, barrières fermées : pas de polygone à dessiner. `ArenaData.xp_mult` compense le nombre fini
  d'ennemis. La même mécanique sert aux futures maps.
- **Barrières** : obstacles dynamiques ajoutés au champ d'obstacles (`ObstacleField`) et à la carte de
  flux (`FlowField`), retirés à l'ouverture.
- **Directeur de niveau** : `ZoneDirector` (`src/run/zone_director.gd`) remplace les vagues au chrono, les
  événements et le boss chronométré ; affichage dans `ZoneOverlay` (barrières, flèche de route) et le HUD.
  Après la dernière zone, la finale de Codex (`ArenaFinale`) ferme l'arène et fait apparaître le boss.
  La Plaine fracturée garde le mode survie (hors campagne).
- **Tests** : `tests/unit/test_zone_mode.gd` (zones séparées, ruée bloquée, apparitions dans la zone active,
  progression complète jusqu'à la finale, traque et sécurité) ; partie complète du bot :
  `godot --headless --fixed-fps 60 --path . res://tests/smoke/autoplay.tscn -- --arena=three_rifts`.

## Questions ouvertes

- Récompense entre les zones : **réalisé provisoirement** (25 % des PV + un coffre), à confirmer.
- Sécurité : **réalisé** — traque quand il reste peu de Corrompus (accélération + flèches au bord de l'écran),
  et réapparition près du Chasseur si plus aucun ne meurt pendant 20 s.
