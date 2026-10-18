# Effets peints des sept Échos d'origine — C5-ter

## Ressources et raccordement

32 scènes dans `assets/vfx/echoes/<écho>/`, registre `origin_scenes.json` et clés
`vfx.echo.<écho>.<nom>`. Les affiches SVG sont des repères de catalogue uniquement.
Le script `origin_effect.gd` hérite de `echo_effect.gd` : mêmes paramètres, shader peint,
méthodes et cycle de vie que [ECHOS_C7_EFFETS.md](ECHOS_C7_EFFETS.md).
Les neuf nouveaux Échos et les fichiers de `src/` / `data/` restent inchangés.

Les palettes proviennent des sprites du manifeste, contrôlés côte à côte : Cendrelame braise/ambre ;
Mousseroc basalte/braise ; Lucivelle cyan/blanc ; Ronceline vert feuille/paille ;
Fulgurine acier bleu/or électrique ; Gueule-d'ombre violet fumé/lilas pâle ; Mirelle glace/blanc.
Pas d'accent principal magenta. Matériaux et rubans peints du jeu réutilisés, aucune nouvelle
image générée ni ressource tierce. Le statut `wip` conserve la validation artistique du propriétaire.

## Catalogue et moments de déclenchement

Les dimensions et durées ci-dessous sont des **défauts visuels**, remplacés par les données réelles
fournies à `EchoVfx`. Aucun dégât, soin, statut, recul ou déplacement réel n'est déduit de l'animation.
Les fichiers ci-dessous sont relatifs au dossier de l'Écho et portent l'extension `.tscn`.

| Écho | Scène | Défauts : rayon / durée / trajet | Déclenchement et mouvement |
|---|---|---|---|
| ashblade | `attack` | 42 / 0,65 s / 140 | Au bond confirmé : traînée courbe, puis double épaisseur de taille et braises. Aucun déplacement de l'Écho par la scène. |
| ashblade | `ash_dance` | 48 / 1,6 s / 0 | À l'armé de la danse ; jusqu'à six positions réelles transmises par `set_secondary_offsets`. Tailles et liaisons décalées dans le temps. Sans cibles : taille locale uniquement. |
| ashblade | `cinder_dash` | 48 / 0,75 s / 240 | Au départ de la ruée ; ruban incandescent, tailles opposées, dispersion. Départ et direction fournis par C7. |
| mossback | `attack` | 95 / 0,6 s / 0 | À la frappe au sol : fissures ramifiées et éclats de basalte qui montent puis retombent. |
| mossback | `status` | 20 / 1,2 s / 0 | À l'application confirmée de Fracture ; fissures compactes sous la cible. |
| mossback | `gravity_well` | 110 / 2,4 s / 0 | À l'ouverture du puits ; éclats aspirés et filaments en spirale, puis contraction et implosion fissurée. |
| mossback | `stone_taunt` | 100 / 1,6 s / 0 | Au point de provocation confirmé ; trois plaques de basalte émergent, sans collision ni obstacle réel. |
| glimmerwing | `attack` | 30 / 0,6 s / 180 | Au lancement de l'orbe : noyau prismatique et sillage souple. Premier offset = position locale réelle de la cible, actualisable. |
| glimmerwing | `status` | 20 / 1,2 s / 0 | À l'application de Marque ; petit losange prismatique au-dessus de la cible. |
| glimmerwing | `prism_flare` | 95 / 1,1 s / 0 | À la détonation confirmée ; offsets des ennemis marqués, jusqu'à huit. Éclats radiaux à chaque contact, sans recherche de cible. |
| glimmerwing | `spark_rain` | 95 / 1,6 s / 0 | Au lancement vers la zone : cristaux descendants décalés et petits éclats au sol. |
| thornweave | `attack` | 75 / 4 s / 0 | À la plantation : tiges peintes qui se déploient, épines, maintien puis retrait. |
| thornweave | `status` | 20 / 1,2 s / 0 | À Racines ; entrelacs au pied de la cible. La même scène accepte le rayon et la durée d'une zone persistante. |
| thornweave | `briar_wall` | 44 / 4 s / 240 | À la plantation de la ligne ; exactement cinq bouquets, échelonnés sur `travel_distance`. Aucun obstacle ajouté. |
| thornweave | `bloom` | 95 / 1,6 s / 0 | À la floraison confirmée ; racines, pétales et lumière montante. Offsets des bénéficiaires réellement soignés pour les liaisons. |
| voltwisp | `attack` | 30 / 0,5 s / 180 | Au départ de la chaîne ; positions locales des contacts réels, dans leur ordre, via `set_secondary_offsets`. |
| voltwisp | `status` | 20 / 1,2 s / 0 | À Électrisé ; trois petits arcs peints, sans grand anneau. |
| voltwisp | `ion_storm` | 110 / 1,8 s / 0 | À l'armé de l'orage ; huit offsets réels requis pour les huit télégraphes et frappes. Sans offsets : préparation locale uniquement. |
| voltwisp | `chain_arc` | 30 / 0,75 s / 240 | Aux rebonds confirmés ; offsets dans l'ordre des contacts. Rubans ramifiés, cœur or et impacts brefs. |
| gloommaw | `attack` | 32 / 0,65 s / 0 | À la morsure/dévoration confirmée : mâchoires peintes et dents pâles qui se referment. Poser à la cible ou fournir le trajet réel. |
| gloommaw | `feast` | 100 / 1,1 s / 0 | Autour de l'Écho au festin : plusieurs mâchoires et flux convergents. |
| gloommaw | `maw_pit` | 95 / 1,8 s / 0 | Au gouffre confirmé au curseur : filaments aspirés et mâchoire centrale, sans disque opaque. |
| mirrorling | `attack` | 30 / 0,65 s / 180 | Au tir : éclat perçant et sillage. Pour un renvoi confirmé, fournir deux offsets : point de contact puis destination réelle du renvoi. Aucun renvoi n'est décidé par l'effet. |
| mirrorling | `reflection` | 65 / cycle 2 s / 0 | Sur le Chasseur quand le bouclier est accordé ; facettes translucides et lueurs mobiles, `loop_visual=true`. Appeler `release()` au retrait du bouclier. |
| mirrorling | `mirror_shards` | 30 / 0,8 s / 240 | Au lancement de l'éventail : cinq éclats. Cinq offsets facultatifs définissent leurs directions et longueurs réelles ; sinon motif visuel de référence à ±20,6°. |

Il n'existe **aucune** scène `status.tscn` pour ashblade, gloommaw ou mirrorling.
Chaque dossier a son `indicator.tscn` : rayon 95, durée 1,6 s et trajet 240 par défaut.
Passer `target_shape="line"` pour `cinder_dash`, `briar_wall`, `chain_arc`, `mirror_shards` ;
`"area"` pour les autres. L'indicateur est segmenté et fin, sans grand cercle lumineux rempli.

## Paramètres et API conservés

- `radius`, `visual_duration`, `travel_distance`, `color`, `accent`, `target_shape` : mêmes unités et sens que C5-bis.
- `play(direction)` oriente depuis +X, direction nulle = droite ; `play_between(from,to)` règle le trajet visuel.
- `set_secondary_offsets(points)` : positions locales obtenues avec `effect.to_local(point_monde)`, maximum huit.
  Les cibles et les positions de frappe viennent toujours de C7.
- `play_from(seconds,direction)` reprend une phase pour synchroniser un contact déjà confirmé.
- `loop_visual`, `release()`, `destroy_on_finish`, `visual_finished` et `seek_visual()` : contrat C5-bis inchangé.
  La fin visuelle ne pilote aucune règle. Reflection ne se détruit pas toute seule tant que sa boucle reste active.

Placer les effets au `z_index=1` de la **couche commune** `effect_layer.gd`, sous les personnages et projectiles.
`EchoVfx` le fait déjà. Ne pas créer une couche par Écho : plafond partagé de 24, détails adaptatifs 18/8/4,
un Node2D par effet et aucun nœud par particule. Les nouveaux effets héritent de cette réduction de détails.
Le refus d'un effet excédentaire ne change jamais l'action de jeu.

Synchronisation : préparation sur les premiers 8–12 %, fin de déplacement vers 50 % pour Cendrelame,
78 % pour orbes/éclats ; dissipation dans les derniers 22 %. La danse répartit ses six contacts entre
10 et 92 % du cycle. L'orage place ses huit frappes entre 16 et 91 %. C7 reste propriétaire des horloges réelles.

## Suite pour Claude

Les scènes respectent les chemins recherchés par `src/entities/allies/echo_vfx.gd` de la PR #29.
Les attaques/statuts déjà raccordés y trouveront leurs ressources après redémarrage de la partie.
Pour Ronceline, `ZoneBehavior` joue déjà une pousse de 0,6 s puis `status_at` avec la durée de la zone (4 s par défaut).
Les polygones de plaques ne sont dessinés qu'après le début effectif de leur croissance ; la garde anti-surface
nulle du renderer commun est conservée.

Raccordements demandés au lot de Claude : `ash_dance`, `prism_flare`, `briar_wall`, `ion_storm`, `feast`,
`reflection`, `stone_taunt`, `spark_rain`, `bloom`, `chain_arc`, `mirror_shards`, ainsi que les comportements
`devour` et `mirror`. Fournir les cibles réellement résolues pour danse, marques, orage, chaîne et renvoi,
et appeler `release()` quand la garde miroir est retirée. Aucune donnée ni règle n'est ajoutée ici.

## Reproduction et contrôle

1. `python3 tools/art/prepare_origin_effects.py` recrée les 32 scènes et leurs entrées de manifeste.
2. Importer Godot, puis lancer `res://tools/art/check_origin_effects.tscn` : chargement des 32 scènes,
   paramètres, fin et retrait de boucle, absence des trois statuts et plafond partagé.
3. Lancer `res://tools/art/origin_echo_preview.tscn` avec le moteur graphique ;
   `ORIGIN_FRAME_DIR` désigne le dossier temporaire des images. L'outil rend hors écran sans prendre le focus.
4. `python3 tools/art/encode_origin_effects.py --frames <dossier>` assemble 21 GIF (7 attaques + 14 sorts),
   palette commune et définition native 1280 × 720. Les effets longs ont jusqu'à 64 images ; durée exportée
   proche du temps réel, arrondie à la résolution temporelle du format GIF.
5. `tools/run_tests.sh` complet en fin de lot ; contrôles ciblés pendant les réglages.

Captures : sept vraies parties gelées des Ruines des Cascades, chaque Écho réellement recruté et nommé au HUD,
90 Corrompus visibles ; profils en lecture seule. Les poses sont figées pour isoler les effets.
Les sorts encore à raccorder sont joués par l'outil de présentation, sans simulation de leurs dégâts.
`performance.json` : 60 images sans/avec 24 effets, géométrie animée à chaque image, pour chaque Écho.
Ces mesures de rendu ne représentent pas le coût de toute l'IA ou des collisions.

## Résultats du 18 octobre

Base actualisée avec main après la PR #31. Import Godot 4.3 réussi ; contrat des 32 scènes vérifié ;
232 scripts chargés, 230 tests unitaires réussis, persistance, 281 ressources graphiques sans erreur,
pipeline d’import, partie automatique et lint verts. Lint supplémentaire du renderer dans assets/ réussi.
Les captures ne signalent aucune erreur de triangulation. Le nettoyage de l’outil de présentation
signale encore des ressources en usage à la fermeture ; ce message ne vient pas des scènes d’effet.

Sur Intel Iris Xe, le test hors écran à 90 Corrompus et 24 émetteurs mesure 37,3–48,1 ms médians avec
effets, contre 32,0–32,7 ms sans eux. Ces chiffres ne valident pas 60 images/s. Le plafond et les détails
adaptatifs sont effectifs ; la passe artistique suivante devra aussi surveiller ce coût de saturation.
Les [captures et GIF](../previews/c5-echos-origine/README.md) restent à la validation du propriétaire.

Retour du propriétaire après aperçu : Cendrelame manquait de visibilité. Ses coupes utilisent désormais
un croissant plein effilé, un bord ivoire, une traînée orange et une gerbe d’impact, dans le rayon fourni
par C7. Une matière dédiée réutilise la brosse du Chasseur en supprimant sa teinte cyan. Les trois GIF
et la capture sont réexportés ; contrat et lint recontrôlés après cette retouche, sans nouvelle suite complète.
La mesure de Cendrelame passe à 48,1 ms médians avec 24 effets simultanés ; la plage globale est donc
37,3–48,1 ms, et non une validation de fluidité à 60 images/s.
