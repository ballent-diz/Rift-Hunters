# Mode « vagues par zone »

Statut : **validé le 14 octobre 2026**, réalisation en attente. Sert de **base de gameplay** des
niveaux ; d'autres maps pourront utiliser d'autres modes (voir [LONGEVITE.md](LONGEVITE.md)).

## Principe

Le niveau est découpé en zones fermées par des **barrières**. Dans chaque zone, le joueur doit
**nettoyer une suite de vagues** ; à la fin de la dernière vague, les barrières de sortie disparaissent
et la zone suivante s'ouvre. La difficulté monte crescendo jusqu'à l'**arène du boss**.

## Premier niveau : Ruines des Cascades (`three_rifts`)

| Zone | Contenu | Barrières de sortie |
|---|---|---|
| Zone 1 (gauche) | 3 vagues de Corrompus standards | Route du haut et sortie du bas vers la zone 2 (le pont central est cassé, infranchissable) |
| Zone 2 (milieu) | 5 vagues, **élites dès la 1re vague**, difficulté croissante | Entrée du pont de droite et les deux escaliers de l'arène |
| Arène (droite) | Nébulorax en 1v1 (+ Échos du joueur et invocations du boss) | Une barrière se referme derrière le joueur à l'entrée |

Départ présumé : en haut à gauche, devant le bâtiment (à confirmer sur capture).
Placement des barrières : d'après les rectangles rouges tracés par le propriétaire sur la map ;
une capture de validation lui sera soumise avant de figer les positions.

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

## Conception technique (prévue)

- **En données, sans code par map** : une ressource de déroulé de niveau décrit les zones (polygones),
  les barrières (segments ou rectangles + visuel), les points d'apparition par zone, le point de départ,
  et les vagues de chaque zone (composition, nombre, élites, délais). La même mécanique sert aux
  futures maps.
- **Barrières** : obstacles dynamiques ajoutés au champ d'obstacles (`ObstacleField`) et à la carte de
  flux (`FlowField`), retirés à l'ouverture.
- **Directeur de niveau** : remplace le directeur de vagues au chrono pour ce mode ; la Plaine
  fracturée garde le mode survie actuel.
- **Tests** : déroulé complet joué par le bot (zones franchies, barrières ouvertes, boss atteint),
  apparitions toujours dans la zone active, aucune vague bloquante.

## Questions ouvertes

- Récompense exacte entre les zones (coffre de relique, soin, éclats ?).
- Durée de la sécurité « vague qui traîne » et forme des renforts.
