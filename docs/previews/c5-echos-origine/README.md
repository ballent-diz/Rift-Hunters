# Échos d’origine — contrôle C5-ter

Rendus natifs Godot 4.3 en 1280 × 720, dans une vraie partie gelée des Ruines des Cascades.
Les effets sont déclenchés par l’outil de présentation ; les dégâts ne sont pas simulés.
Les sorts encore absents du raccordement C7 nécessitent l’intervention de Claude : voir le
[contrat de raccordement](../../art/ECHOS_ORIGINE_EFFETS.md).

| Écho | Capture | Attaque | Sort d’origine | Second sort |
|---|---|---|---|---|
| Cendrelame | [Image](ashblade.png) | [Bond et taille](ashblade_attack.gif) | [Danse](ashblade_ash_dance.gif) | [Ruée](ashblade_cinder_dash.gif) |
| Mousseroc | [Image](mossback.png) | [Frappe](mossback_attack.gif) | [Puits](mossback_gravity_well.gif) | [Rempart](mossback_stone_taunt.gif) |
| Lucivelle | [Image](glimmerwing.png) | [Orbe](glimmerwing_attack.gif) | [Détonation](glimmerwing_prism_flare.gif) | [Pluie](glimmerwing_spark_rain.gif) |
| Ronceline | [Image](thornweave.png) | [Ronces](thornweave_attack.gif) | [Mur](thornweave_briar_wall.gif) | [Floraison](thornweave_bloom.gif) |
| Fulgurine | [Image](voltwisp.png) | [Arc](voltwisp_attack.gif) | [Orage](voltwisp_ion_storm.gif) | [Chaîne](voltwisp_chain_arc.gif) |
| Gueule-d’ombre | [Image](gloommaw.png) | [Morsure](gloommaw_attack.gif) | [Festin](gloommaw_feast.gif) | [Gouffre](gloommaw_maw_pit.gif) |
| Mirelle | [Image](mirrorling.png) | [Éclat et renvoi](mirrorling_attack.gif) | [Garde miroir](mirrorling_reflection.gif) | [Éventail](mirrorling_mirror_shards.gif) |

`animations.json` conserve les durées et nombres d’images. `performance.json` mesure le rendu avec
90 Corrompus et 24 émetteurs, limité à quatre détails par effet. Sur l’Intel Iris Xe de contrôle :
temps médian de 37,3 à 45,3 ms avec effets, contre 32,0 à 33,1 ms sans effets. Ce test de saturation
hors écran ne démontre donc pas 60 images/s ; il exclut l’IA et les collisions. Les effets excédentaires
sont refusés par la couche commune, sans empêcher une action de gameplay.

La prochaine passe artistique demandée par le propriétaire reprendra les animations des seize Échos
dans Godot pour viser le niveau de finition des compétences du Chasseur.
