# Dévoreur des Sources — effets et contrat de raccordement

## Périmètre

Quatorze scènes de présentation Godot, sous `assets/vfx/bosses/source_devourer/`, complètent les
quinze animations du sprite `boss.source_devourer`. Elles réutilisent les brosses peintes et les
rubans facettés des compétences du Chasseur. La matière animée est celle des effets des Échos,
avec une palette propre : pierre grise, racines charbon, mousse et cœur de Faille violet.
Aucune nouvelle image générée n’est nécessaire pour les effets.

Ce sont des scènes autonomes prêtes à être raccordées, pas un boss fonctionnel ajouté à la
campagne. Rien ne choisit une cible, n’invoque un ennemi, ne déplace le boss, ne produit de dégâts
et ne crée de collision. Claude conserve les règles de combat et l’intégration.

## Correspondances

Préfixe des scènes : `res://assets/vfx/bosses/source_devourer/`. Les valeurs ci-dessous sont des
valeurs de démonstration, en unités du monde et secondes ; le gameplay fournit les valeurs finales.

| Scène | Animation du sprite | Position | Paramètres de démonstration | Avertissement |
|---|---|---|---|---|
| `claw.tscn` | `attack` | Origine de la frappe | rayon 150, durée 0,65 | secteur |
| `heavy_slam.tscn` | `heavy_slam` | Impact confirmé des poings | rayon 170, durée 0,9 | zone |
| `rift_breath.tscn` | `rift_breath` | Gueule | longueur 480, largeur 80, durée 1,3 | ligne |
| `summon.tscn` | `summon` | Origine des points d’apparition | rayon local 70, durée 1,1 | points d’apparition |
| `root_sweep.tscn` | `root_sweep` | Origine de l’attaque | rayon 230, demi-angle 45°, durée 1,1 | secteur |
| `transform.tscn` | `transform` | Ancre du boss | rayon 210, durée 2 | aucun danger implicite |
| `roar.tscn` | `roar` | Gueule | rayon 180, durée 1,2 | aucun danger implicite |
| `hurt.tscn` | `hurt` | Impact réel | rayon 55, durée 0,35 | aucun |
| `death.tscn` | `death` | Ancre du boss | rayon 240, durée 2 | aucun |
| `phase2_claw.tscn` | `phase2_attack` | Origine de la frappe | rayon 180, durée 0,75 | secteur |
| `phase2_breath.tscn` | `phase2_breath` | Gueule | longueur 620, largeur 64, durée 1,6 | ligne |
| `phase2_slam.tscn` | `phase2_slam` | Impact confirmé | rayon 230, durée 1,15 | zone |
| `rift_fragment.tscn` | Émission depuis le boss | Projectile réel | largeur 32, déplacement graphique 0 | dépend du tir |
| `indicator.tscn` | Préparation | Même origine et orientation que la zone réelle | zone, ligne ou secteur | uniquement télégraphe |

Repos et marche utilisent le sprite : pas de halo permanent qui masquerait le sol. Une scène
`rift_fragment` ne rend pas obligatoire l’ajout d’un tir : elle est disponible si Claude raccorde
une compétence qui lance des fragments. Les deux variantes de phase 2 renforcent les traits et
les éclats sans créer de disque lumineux rempli.

## Paramètres et cycle de vie

- `radius` : portée radiale graphique ; `travel_distance` : longueur sur l’axe local +X.
- `width` : largeur totale d’un souffle, d’un couloir ou d’un fragment ; `half_angle_degrees` :
  demi-angle du secteur. Transmettre la géométrie réelle de l’attaque, pas une valeur décorative.
- `visual_duration` : durée graphique ; elle ne doit jamais prolonger un statut ou un dégât.
- `phase2` : variante graphique ; aucun changement de règle ou détection des PV.
- `particle_budget` : 20 par défaut, maximum effectif 32. Huit points secondaires au maximum.
- `play(direction)` : origine déjà positionnée, axe +X orienté vers cette direction.
- `play_from(seconds, direction)` : synchronisation avec un événement déjà confirmé.
- `seek_visual(seconds)` : contrôle figé ; n’avance pas la simulation.
- `set_secondary_offsets(points)` : positions locales exactes données par le gameplay, notamment
  les points d’invocation ; aucune sélection de cible ou création d’ennemi dans la scène.
- `loop_visual` : présentation maintenue, notamment télégraphe ; `release()` dissipe les 0,22
  dernières secondes et termine la boucle.
- `destroy_on_finish` et `visual_finished` : durée de vie graphique uniquement. Ne jamais
  déclencher des dégâts ou des invocations depuis ce signal.

Le temps de démonstration comporte une préparation brève, le contact puis une dissipation.
Les griffes partent à 12 % de la durée, la frappe au sol à 30 %, le souffle à 12 %. Si la scène
est créée à l’impact réel, la démarrer directement à ce repère avec `play_from` ; ne pas attendre
à nouveau la préparation. Le télégraphe du gameplay est indépendant de cette chorégraphie.

## Lisibilité, obstacles et performances

Les effets sont au `z_index = 1`, sous les personnages et les projectiles ennemis. Les avertissements
ont une bordure sombre et un tracé corail, distincts des compétences alliées cyan et des impacts
violets. Le remplissage des couloirs et secteurs est à 5,5 % ; les zones n’ont pas de disque plein.
La rotation des deux scènes (télégraphe et impact) doit être identique.

La collision des deux gros rochers de l’arène demeure la source de vérité : Claude doit appliquer
les vraies occultations de souffle/tir. Le dessin ne détecte pas les obstacles. Tronquer la longueur
visuelle d’un rayon au premier obstacle réellement touché ; ne jamais montrer un souffle traversant
un rocher alors qu’il protège le Chasseur. Pour plusieurs impacts, fournir les positions confirmées.

Un effet = un Node2D, aucun nœud par particule. Réutilisation possible avec `destroy_on_finish = false`.
Plafond recommandé : huit effets décoratifs simultanés pour le boss, dont quatre au budget complet,
puis budget réduit à huit éclats. Toujours conserver les télégraphes nécessaires à la lecture d’une
attaque : supprimer en premier les éclats secondaires. Ces plafonds sont un contrat de rendu,
pas une limite sur le nombre d’actions du gameplay.

Le contrôle de performance livré dans `docs/previews/devourer-vfx/performance.json` mesure une
partie gelée avec 90 ennemis visibles et huit effets. Il mesure la présentation et le dessin,
sans prétendre représenter le coût complet de l’IA ou des collisions.

Captures PNG natives 1280 × 720 et aperçus animés WebP (qualité 94, pour limiter le poids du dépôt)
dans `docs/previews/devourer-vfx/`. Les effets du jeu restent dessinés nativement par Godot :
la compression concerne uniquement les aperçus. Le manifeste expose
`vfx.boss.source_devourer.<nom>`. Le champ `sheet` y pointe vers l’icône du boss pour le catalogue ;
la scène est la ressource qui produit réellement l’animation. Les ressources restent `wip` en
attendant leur validation visuelle et leur raccordement.
