# Les Vernissés et Faïron

Dans un atelier déserté, la Faille anime les pièces oubliées dans les fours. La glaçure
cobalt signale les surfaces dures. Les cassures laissent voir le grès sombre, avec
des réparations ocre et quelques lueurs violettes aux jointures.

| Rang | Nom | Identifiant | Gestes proposés |
| --- | --- | --- | --- |
| Normal | Tesson sauteur | `enemy.hopping_shard` | Petite tasse brisée à quatre pattes, morsure basse. |
| Normal | Pèlerin de faïence | `enemy.faience_pilgrim` | Silhouette voûtée au long masque, balayage d'un éclat tenu en main. |
| Normal volant | Rosace flottante | `enemy.floating_rosette` | Trois ailettes de porcelaine se replient avant son tir. |
| Normal à technique | Verseur fendu | `enemy.cracked_pourer` | Coup du bec et jet de pigment (`pigment_spit`). |
| Élite | Juge de glaçure | `enemy.glaze_judge` | Barrage de carreau (`tile_barrier`) et verdict frappé verticalement (`verdict`). |
| Élite | Potière creuse | `enemy.hollow_potter` | Assemblage de l'argile (`clay_assembly`) et lancer de tesson (`sherd_cast`). |
| Élite | Mille-patte de mosaïque | `enemy.mosaic_crawler` | Enroulement avant la charge (`roll_windup`) et crête de carreaux (`tile_ridge`). |

Chaque rangée contient six poses. Déplacement et attaque occupent la planche A des
normaux. Le Verseur ajoute une rangée de technique. Les élites ont chacune une mort
sur A et deux techniques sur B. Le moteur dessine la dispersion des normaux, l'ombre
de la Rosace, les projectiles et les télégraphes.

[Silhouettes des Vernissés](../previews/vernisses/famille.webp) · [Cycles animés](../previews/vernisses/mouvements.gif) · [Banc Godot](../previews/vernisses/dalles.webp)

## Faïron, Dévoreur des Émaux

Faïron porte un four rond sur des pieds de terre cuite. Une cheminée sombre couronne
sa coque de porcelaine. Au changement de phase, trois panneaux de la coque se soulèvent
et laissent voir les coutures incandescentes de la chambre de cuisson.

**Le Choc d'émail** est la mécanique phare proposée. Faïron glace des bandes de sol
pendant la préparation. Au refroidissement, les bandes se fendent dans l'ordre
où elles ont été marquées. Cet ordre donne au joueur une fenêtre pour traverser.
Les gestes indiquent la direction et le moment du coup. Les bandes, les éclats
et leur durée restent à synchroniser avec le gameplay.

| Planche | Clips | Geste |
| --- | --- | --- |
| A, 6 × 3 | `idle`, `move`, `attack` | Repos, marche du four et frappe d'une patte. |
| B, 6 × 2 | `enamel_line`, `vent_purge` | Pose d'émail et purge des évents. |
| C, 6 × 3 | `transform`, `phase2_idle`, `phase2_move` | Ouverture de la coque, repos et marche coque ouverte. |
| D, 6 × 3 | `enamel_shock`, `kiln_spit`, `death` | Choc d'émail, projection du four et effondrement. |

L'atlas `boss.fairon` réunit les onze animations, soit 66 poses.
[Les deux phases](../previews/fairon/fairon.webp) · [Clips animés](../previews/fairon/animations.gif) · [Banc Godot](../previews/fairon/phase_2.webp)

## Import et livrables

Sources ImageGen, prompts, plans de découpe et jobs sous `assets/concepts/incoming/`.
Les nouvelles feuilles et leurs icônes sont référencées dans le manifeste. Échelle 0,5,
palette de 32 couleurs au maximum et ancrage au sol.

```sh
python3 tools/art/import_vernisses.py --preview-dir <dossier>
python3 tools/art/import_fairon.py --preview-dir <dossier>
```

Les captures utilisent le zoom 1,3333 du mode 2D sur le Sanctuaire des Runes, avec le
Veilleur des Seuils et un Écho comme repères. Les rencontres et les techniques restent à brancher.

Le validateur de Rift Hunters accepte les huit atlas sur le banc Godot 4.3. Le test du pipeline
d’import passe. [Rapport de la famille](../previews/vernisses/controle.json) · [Rapport de Faïron](../previews/fairon/controle.json)
