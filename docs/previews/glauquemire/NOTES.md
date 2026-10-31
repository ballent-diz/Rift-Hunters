# Résultat du banc natif

Poster : comparison_native.png, 1280 × 720. Quatorze clips boss : boss_<animation>.webp ; clip lanterne : mist_lantern.webp. Chaque WebP est inférieur à 3 000 000 octets. Les quatorze clips boss conservent leurs six poses et durées réelles du manifeste : 750 ms à 8 fps, 600 ms à 10 fps, 500 ms à 12 fps. La lanterne enchaîne six poses allumées à 8 fps, six poses d'extinction à 12 fps, six poses éteintes à 8 fps, soit 2000 ms. exports_validation.json vérifie les durées finales des WebP. Les clips répètent la séquence uniquement pour inspection ; aucune phase n'a été normalisée.

Tous les sprites sont issus du manifeste du checkout Glauquemire, appliqué à scale déclaré × zoom 4/3, ancres inchangées. Le sol est un extrait direct à densité 2,25 texels/unité, 2160 × 1215 texels rendu 1280 × 720 pour 960 × 540 unités du monde. Ce sont des bancs de sprites sur place, pas du combat. Aucun gameplay, VFX de mécanique, déplacement d'IA ou collision n'est exécuté.

Sources réellement lues et auditées :

| Entrée | Dimensions | SHA256 |
|---|---|---|
| boss.glauquemire | 3072 × 7168 | cee3bdfa91a5e539add7c2edb472c694973a340b0f60b03aa66a135c12abc132 |
| object.mist_lantern | 768 × 384 | eeae0468ee373e3d4675be3b4daef47cfcea28ac53eec508874e6bd0ee59d6af |
| player.hunter | 672 × 400 | 99965593a5ce61179d9bc602b1a813bcd432614e0d0c692b77782d85705f9325 |
| monster.mossback | 384 × 352 | 90cacb854b96d3ddff19ee45e57cef380408d5332ead05d62a80384d98efa79e |

Audit de toutes les régions déclarées, alias inclus : 90 frames boss, 30 lanterne, 39 Chasseur, 20 Mousseroc ; aucune région hors feuille ni contact avec les deux pixels de bord à alpha >=8. Le rapport détaillé est frame_validation.json. Le Mousseroc est le sprite actuel du dépôt, à l'aspect orange/noir préexistant, conservé comme témoin.

Inspection visuelle des six sources A/B/C/D/E/F à travers les captures de toutes leurs animations : anatomie, ancrage et échelle cohérents, sans rupture majeure ni clipping visible. La mort se tasse naturellement jusqu'à la carcasse. audit_native_contact.webp juxtapose les six poses natives de chaque animation pour cette vérification (aperçu de contrôle réduit, pas une capture de partie).

Réserves : phase 1 très sombre sur la terre, avec texture fine et contraste limité ; les cristaux rendent phases 2 et 3 plus lisibles. Le cœur de phase3_idle reste petit et son mouvement faible. transform montre seulement vase → cristal ; aucune transition distincte vers la phase 3 n'a été créée. La fissure de la lanterne reste discrète à l'échelle jeu, mais le petit feu allumé et son absence séparent clairement les états. Aucun effet de combat externe n'est attendu dans ces clips.

Godot 4.3 a rendu nativement sur Intel Iris Xe avec gl_compatibility et AudioDriverDummy, dans un projet TEMP/caches propres au sous-lot. Les rendus ont terminé avec code 0 et toutes les images produites, mais stderr a signalé une erreur initialize dans shader_gles3.cpp:798 ; ce résultat n'est pas assimilé à un contrôle GPU sans erreur. Les journaux natifs sont conservés. Aucune suite headless du parent n'a été exécutée ou remplacée.

À chaque encodage, seuls les PNG intermédiaires vérifiés sous glauquemire-preview/frames/<animation> ont été supprimés, six au maximum à la fois. Les trois parties temporaires de la lanterne ont été supprimées après assemblage. Aucune source, aucun checkout ni cache du parent n'a été modifié.
