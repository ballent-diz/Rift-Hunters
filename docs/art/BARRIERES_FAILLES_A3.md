# A3 et visuels D2 — barrières et failles

Livraison graphique après la fusion de la PR #26, branche codex/barrieres-failles.
Aucun changement des collisions, vagues, PV, minuteries de combat, positions ou cadences d’apparition.

## Barrières

- Atlas peint généré avec imagegen : **8 poses à 12 images/s**, interpolation entre poses.
- Vagues d’énergie violette, éclairs et filaments ; shader commun avec bord lumineux et particules.
- Les rectangles voisins sont regroupés par connexité. Chaque chaîne devient **un ruban courbe continu**,
  porté par un MeshInstance2D : aucun panneau carré ni contour interne sur les escaliers.
- Le maillage monte à 108 unités du sol ; un shader Godot déforme réellement ses sommets.
  Des arcs électriques et des fragments mobiles complètent les huit poses de texture.
- À l’apparition, le rideau se déploie depuis le sol ; à la dissolution, ses fragments se dispersent
  sans replier tout le mur en un bloc. La texture est répétée en miroir pour éviter une couture entre tuiles.
- Géométrie reconstruite seulement quand l’état des barrières change ; pas de reconstruction par image.
- Apparition des entrées de l’arène : **0,5 seconde** ; dissolution des sorties de zone : **1,2 seconde**.
- Flèche : deux chevrons clairs avec contre-contour sombre et pulsation lente.
- Aucune grande enceinte circulaire ajoutée aux arènes murées.

La texture animée reste appliquée au même ruban pendant les transitions ; le visuel ne modifie jamais
ObstacleField ni FlowField. Les minuteries visuelles sont séparées des règles d’ArenaFinale.

## Failles

- enemy.rift_breach : repos ouvert 8 poses à 10 images/s, impact 8 à 20 images/s, fermeture 8 à 12 images/s.
- Cellule 192 × 192, ancre (96, 174), hauteur cible 128 pixels d’art, scale 0,75 : environ 96 unités du monde.
- Violet/indigo et reflets lavande ; aucun accent magenta principal.
- **Retour du propriétaire appliqué : cercle au sol et jauge circulaire supprimés.**
  Quelques fissures courtes restent au pied de la déchirure ; les PV utilisent une petite barre droite.
- Une copie graphique joue la fermeture quand la cible quitte la simulation ; elle est libérée à la fin.
  Cette copie n’a ni PV ni collision. Les fissures s’éteignent avec elle.
- Les Corrompus apparaissent avec une brève montée d’échelle et une impulsion d’énergie,
  sans déplacer leur point réel ni retarder leur entrée en combat. Événements graphiques plafonnés à 32.
- La faille centrale du boss réutilise le portail, grandit pendant l’ouverture existante puis se dissipe
  derrière Nébulorax pendant une demi-seconde.

Les sources sont générées, sans ressource tierce ajoutée. Les prompts exacts sont conservés dans
assets/concepts/incoming/enemy.rift_breach/source/generation.json et
assets/concepts/incoming/vfx.barrier_energy/source/generation.json.
Ces dossiers sont sous le .gdignore commun ; aucun .import n’y est versionné.

## Reproduire

~~~bash
python3 tools/art/prepare_rift_breach.py
python3 tools/art/prepare_barrier_energy.py
godot --headless --import --path .
godot --path . res://tools/art/a3_preview.tscn
tools/run_tests.sh
~~~

Les captures de a3_preview sont prises dans les vraies scènes des deux niveaux, avec une partie de test
gelée aux états à examiner et un profil en lecture seule. Elles ne modifient pas la sauvegarde du joueur.
La variable A3_FRAME_DIR permet de conserver les images intermédiaires pour les aperçus animés.

## Contrôles visuels

Captures 1280 × 720 dans docs/previews/a3-failles/ :

| Fichier | Contenu |
|---|---|
| 01-barriere-fermee.png | Sortie fermée des Cascades |
| 02-dissolution.png | Dissolution à mi-parcours |
| 03-fleche.png | Route vers la zone suivante |
| 04-arene-materialisation.png | Entrées de l’arène en train d’apparaître |
| 05-arene-mur-continu.png | Chaîne des escaliers réunie |
| 06-faille-boss.png | Ouverture centrale |
| 07-sortie-nebulorax.png | Boss devant la faille |
| 08-faille-ouverte.png | Hautes Terres, sans cercle au sol |
| 09-faille-impact.png | Réaction au coup |
| 10-faille-fermeture.png | Déchirure qui se referme |
| 11-sorties-corrompus-90.png | Apparitions avec 90 Corrompus affichés |

barriere-animation.gif montre les huit poses dessinées ; barriere-en-jeu.gif et fermeture-en-jeu.gif
montrent le rendu capturé. Les PNG conservent la qualité des captures, sans la palette limitée du GIF.

performance.json compare les effets visibles et masqués avec 90 Corrompus affichés.
La simulation est gelée pour comparer la même scène et le même nombre d’ennemis.
Ces mesures locales du rendu ne sont pas un benchmark de toute l’IA ou une garantie sur tout matériel.
Les essais de sensation en partie restent à faire par le propriétaire.


## Vérification et entretien

Deux contrôles couvrent la connexité des rectangles ; un troisième vérifie la continuité du ruban des escaliers.
Le test existant test_player_cannot_enter_obstacles tirait au hasard un point pouvant tomber au milieu
d’une grande zone totalement bloquée. Sa fixture choisit désormais, de façon déterministe, un point
réellement enfoncé de 20 à 30 unités dans une lisière ; le critère de répulsion est conservé et la présence
du point de départ est vérifiée. Aucun masque de collision ni code de déplacement n’a été modifié.


## Résultat final des vérifications

Import Godot sans erreur, puis tools/run_tests.sh complet : **code 0**.
222 scripts chargés, **215/215 tests unitaires**, persistance, **159/159 assets**, art, smoke et lint réussis.
Les suites test_zone_mode, test_arena_finale, test_map_passages et test_rift_mode passent,
ainsi que les trois contrôles du regroupement et du ruban des barrières.
La faille contient 24 poses non vides, sans rognage ni fond vert résiduel détecté.

Mesure locale avec 90 Corrompus affichés, simulation gelée : médiane 16,76 ms pour les murs
et 16,79 ms pour les failles avec effets, contre 16,71 ms et 16,60 ms masqués.
Ces écarts restent dans le bruit de mesure ; ils n’établissent pas les performances de toute l’IA.


### Retouche des barrières à la demande du propriétaire

La silhouette utilise désormais une crête irrégulière, des extrémités adoucies et une ondulation plus ample.
Deux arcs lumineux parcourent le mur ; la matière indigo est plus contrastée, avec des filaments lavande.
Un émetteur natif Godot de 32 particules par chaîne détache des éclats au-dessus du rideau
(un seul nœud par émetteur, aucun nœud individuel par particule). Les émissions suivent la montée
puis s’éteignent pendant la dissolution. Les captures et le GIF principal montrent maintenant la barrière
du pont en entier. Aucune nouvelle génération d’image ni modification des collisions.

La nouvelle comparaison de rendu reste autour de 16,7 ms avec ou sans effets pour 90 Corrompus affichés ;
voir performance.json pour les valeurs actuelles. Cette retouche est vérifiée par les tests unitaires,
le lint et les captures Godot ; la suite complète précédente reste consignée ci-dessus.
