# Les Saumâtres

Les Saumâtres ont colonisé des salines et des écluses englouties. La croûte de sel ivoire donne les volumes,
le cuivre piqué et le bois humide rappellent les installations abandonnées, et le violet signale la Faille
par petites touches. Le Temple des Marées sert de décor témoin pour juger le contraste.

| Rang | Monstre | Identifiant | Attaque et techniques proposées |
| --- | --- | --- | --- |
| Normal | Griffe-sel | `enemy.salt_scuttler` | Pincement rapide au corps à corps. |
| Normal | Noyé des cordages | `enemy.rope_drowned` | Coup de gaffe courbe. |
| Normal volant | Raie des saumures | `enemy.brine_skate` | Tir après repli des nageoires. L’ombre appartient au moteur. |
| Normal à technique | Siphon de sel | `enemy.salt_siphon` | Coup de siphon et jet de saumure chargé (`brine_jet`). |
| Élite | Gardien de l’écluse | `enemy.floodgate_keeper` | Garde derrière la vanne (`lock_guard`), puis frappe au maillet (`mallet_slam`). |
| Élite | Chantre de saumure | `enemy.brine_choir` | Appel des cloches (`bell_call`) et bénédiction des alliés (`brine_blessing`). |
| Élite | Dragueur de sel | `enemy.salt_dredger` | Charge au godet (`scoop_charge`) et éclatement de la croûte de sel (`salt_crust_burst`). |

Chaque rangée peinte contient six poses. Les trois normaux ont une planche A de deux rangées
(déplacement et attaque). Le Siphon ajoute une troisième rangée pour son jet. Chaque élite a une
planche A de trois rangées (déplacement, attaque, mort) et une planche B avec deux techniques.
Les lettres A et B correspondent aux sources de production. Les morts des normaux utilisent une
rangée transparente pour laisser place à l’effet commun. Les télégraphes et les projectiles
indépendants seront dessinés par le jeu.

Cette livraison contient **10 planches et 144 poses peintes**, sept feuilles de jeu et sept icônes.
Les cellules sont ajustées aux silhouettes et aux poses extrêmes. Les feuilles gardent l’échelle
0,5, le point d’appui au sol et une palette de 32 couleurs au maximum. La Raie a un décalage de vol
et sa propre empreinte d’ombre.

Les sources retenues et les prompts ImageGen sont dans `assets/concepts/incoming/enemy.<id>/source/`.
Chaque planche B reprend la planche A de son élite en référence. Le conditionnement réutilise
le découpage et l’import standard, avec une échelle fixe par planche.

```sh
python3 tools/art/import_saumatre.py --preview-dir <dossier>
```

Le [catalogue visuel](../previews/saumatres/famille.webp) montre les silhouettes à ×3.
Les planches par créature montrent chaque rangée à ×2. L’[aperçu animé](../previews/saumatres/mouvements.gif)
enchaîne les déplacements, les attaques et une technique par élite. Les [dalles](../previews/saumatres/dalles.webp)
et les [berges](../previews/saumatres/berges.webp) présentent le banc Godot au zoom 1,3333 du mode 2D,
avec le Veilleur et un Écho pour l’échelle.

Godot 4.3 a importé les feuilles et le validateur du projet a accepté les sept entrées sur un banc isolé.
Les 144 poses sont distinctes à l’intérieur de leurs cycles, à l’exception des retours de pose voulus.
Le [rapport](../previews/saumatres/controle.json) recense les résultats et les empreintes des fichiers finaux.

Les entrées sont disponibles dans le manifeste. Claude pourra raccorder les rencontres, les tirs,
les techniques et leurs télégraphes aux visuels par identifiant.
