# Cristal-miroir B5 — scène autonome

Chemin runtime attendu : `res://assets/vfx/objects/mirror_crystal/mirror_crystal.tscn`.
Racine `MirrorCrystal` (Node2D), script `mirror_crystal.gd`, zéro enfant. Origine au pied du socle (0,0). Corps au repos de 72 unités au réglage radius=30 ; socle bas de 52 unités de large. Ombres, facettes, arêtes et stries minérales dessinées ; aucun grand cercle lumineux, collision, dégât ou sélection de cible. Les 12 fragments et 15 étincelles maximaux sont dessinés par la racine, sans nœud par particule.

## API

- `set_state(value: StringName)` / `play(value: StringName = "idle")` : remet l'horloge à zéro, relance et rend visible sauf hidden. États inconnus remplacés par idle.
- `seek_visual(seconds: float)` : positionne et fige l'animation sans émettre de signal. Appeler play pour relancer.
- `release()` : masque la scène et désactive son traitement, sans la détruire. Le propriétaire peut la réutiliser.
- `finished()` et `animation_finished(animation: StringName)` : émis une seule fois à la fin de burst/debris pendant la lecture normale. Pas de signal pour les boucles idle/charged ni lors de seek/release.

## États et durée

| État | Rendu | Durée |
|---|---|---|
| idle | Socle et cristal cyan à facettes, stries fines | Boucle tant que présent |
| charged | Arêtes blanc-cyan pulsantes, huit étincelles montantes plafonnées | Boucle, pulsation charged_pulse_speed=5 |
| burst | Trois rayons et fragments, extinction progressive | duration=0,65 s |
| debris | Petits éclats résiduels qui s'effacent | debris_duration=0,9 s |
| hidden | Rien dessiné, traitement désactivé | Jusqu'à play |

Le contrôleur de gameplay choisit les transitions : le visuel ne passe pas automatiquement de burst à debris et ne fait pas repousser le cristal. Le contrôleur appelle charged après le coup, burst au déclenchement des rayons, puis debris/hidden au moment voulu.

## Paramètres exportés

`radius` (30) calibre le visuel global relativement à sa taille de référence ; `idle_height` (72) fixe sa hauteur. `duration` (0,65), `debris_duration` (0,9), `tint` (cyan), `ray_length` (240 unités), `ray_width` (9) et `direction` (Vector2.RIGHT) sont configurables. Trois rayons dans les directions direction, direction+TAU/3, direction+2TAU/3 ; direction nulle retombe sur RIGHT. Les rayons partent du centre bas du cristal, à y=-0,4*idle_height*radius/30. ray_length est indépendant de radius.

Les paramètres visuels ne règlent aucune portée effective ni cadence de gameplay. Teinte conseillée cyan claire, distincte du magenta des ennemis.

## Vérification

`godot --headless --path <projet> --script res://check.gd` : scène chargée, cinq états accessibles, horloge figée, libération, zéro enfant : OK, sans erreur de script. Journal check.log. Première tentative d'éditeur sous sandbox a produit des erreurs d'accès aux réglages utilisateur ; elle n'est pas comptée comme contrôle réussi. Le contrôle final utilise APPDATA local redirigé et ne rencontre pas ces erreurs. Captures finales et mesure de foule restent au parent.
