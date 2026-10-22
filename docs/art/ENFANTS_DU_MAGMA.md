# Enfants du magma — livraison des sprites

Famille de sept monstres du chapitre 2, validée par le propriétaire le 22 octobre 2026 après
présentation de la planche de contrôle. Cette livraison concerne uniquement les visuels :
aucune donnée de monstre ni règle de combat n’est créée ou modifiée.

## Identifiants et animations

Les clés du manifeste sont `enemy.<identifiant>`. Chaque animation dessinée contient six images.
`move` tourne en boucle à 10 images/s (0,6 s) ; les attaques, morts dessinées et techniques se
jouent une fois à 12 images/s (0,5 s). `idle` est un alias de `move`.

| Identifiant | Nom | Rang | Animations dessinées |
|---|---|---|---|
| `magma_mite` | Acarien de magma | Normal | `move`, `attack` |
| `lava_lurker` | Rôdeur de lave | Normal | `move`, `attack`, `plunge` |
| `obsidian_brute` | Brute d’obsidienne | Normal | `move`, `attack` |
| `ember_spitter` | Cracheur de braise | Normal | `move`, `attack` |
| `caldera_titan` | Titan de caldeira | Élite | `move`, `attack`, `death`, `eruption`, `open_crater` |
| `flame_wyrmling` | Wyvernette de flammes | Élite | `move`, `attack`, `death`, `flame_breath`, `dive` |
| `slag_matron` | Matrone des scories | Élite | `move`, `attack`, `death`, `brood`, `slag_molt` |

Les normaux possèdent une entrée `death` de compatibilité : **une seule image transparente**,
à 12 images/s, sans boucle. Il ne s’agit pas d’une animation de mort dessinée. Cette entrée
satisfait le chargement actuel sans ajouter de rangée au cahier des charges des normaux.

## Conditionnement et échelle

- Cellules de 256 × 256 pixels ; ancre de pieds `[128, 238]` ; échelle du manifeste `0.5`.
- Hauteurs cibles d’art, avant cette échelle : 60, 80, 84, 72 pixels pour les quatre normaux ;
  100, 96 et 94 pixels pour les trois élites, dans l’ordre du tableau.
- Fond transparent, palette réduite à 32 couleurs, contour sélectif, vue vers la droite.
- La Wyvernette conserve un flottement `hover: 6`.
- Les techniques issues d’une seconde planche sont ramenées à la taille du corps de la première
  avant import. Les facteurs exacts figurent dans `source/normalization.json` de chaque élite.

Pour `flame_wyrmling/dive`, les six décalages verticaux sont `[0, -22, -48, -56, -28, 0]` pixels
d’art (décalage horizontal nul). Ils préservent la montée puis le retour dans la cellule malgré
l’alignement automatique des pieds. Ce mouvement est exclusivement graphique : il ne déplace
pas l’entité et ne décide ni de son invulnérabilité ni du moment des dégâts.

## Sources et reproduction

Chaque dossier `assets/concepts/incoming/enemy.<identifiant>/` contient :

- `job.json`, les bandes d’animation et leurs références de rangée ;
- `source/`, avec les planches générées, prompts exacts, métadonnées et essais conservés ;
- `source/SHA256.txt`, empreintes des images sources ;
- pour les élites, `source/normalization.json`, normalisation entre leurs deux planches.

Les sources sont générées pour le projet ; aucune image tierce sous licence restrictive n’est
ajoutée. Les révisions conservées documentent notamment le jet raccourci du Cracheur.
Le dossier `incoming` reste ignoré par Godot ; aucun fichier `.import` n’y est nécessaire.

Le conditionnement est décrit par `tools/art/package_magma_family.py`, puis chaque `job.json`
utilise `tools/art/import_sheet.py`. Le nettoyage technique des fragments de cellules voisines
se fait par `tools/art/clean_sprite_gutters.py` ; les sources originales restent conservées.
Les sprites utilisables sont dans `assets/sprites/enemies/<identifiant>/` et les icônes dans
`assets/ui/icons/enemies/`. Le manifeste reste la source de vérité de leurs chemins.

## Contrôles et aperçus

Contrôles ciblés effectués sur cette livraison, sans répétition de la suite complète :

- import Godot 4.3 réussi ;
- contrôle `assets` : **322/322 entrées chargées**, zéro erreur et zéro visuel de remplacement ;
- `tools/art/test_import.py` réussi ;
- contrôle de la montée de `dive` : bord inférieur des images à
  `[234, 212, 186, 178, 206, 234]`, soit 56 pixels d’art de montée et retour à la même hauteur ;
- captures en partie gelée à 1280 × 720, avec Chasseur, Mousseroc et un ennemi de référence ;
- planche de famille, séquences GIF et captures des techniques dans
  `docs/previews/magma-monsters/` ; rapport technique `import_report.json` au même endroit.

Aperçus principaux :

- [Famille complète](../previews/magma-monsters/magma_roster.png) ;
- [Échelle en partie](../previews/magma-monsters/magma_in_game.png) ;
- [Plongée](../previews/magma-monsters/technique_plunge.png) ;
- [Piqué](../previews/magma-monsters/technique_dive.png).

Les avertissements de libération de ressources à la fermeture du banc de capture sont ceux du
banc existant ; le contrôle de chargement final ne signale aucun remplacement ni aucune erreur.
Ces captures valident l’apparence et l’échelle ; elles ne constituent pas une validation de
l’équilibrage ni du comportement en combat, qui seront raccordés par Claude.

## Suite : Pyrevorn

Les quatre planches de Pyrevorn sont livrées après validation de cette famille ; voir [PYREVORN_SPRITES.md](PYREVORN_SPRITES.md).
Elles feront l’objet de leur propre contrôle d’échelle et d’animation ; elles ne sont pas
comptées dans les 322 entrées du contrôle ci-dessus.

Contrôle final commun après récupération de main et ajout de Pyrevorn : **345/345**, zéro
placeholder et zéro erreur. Les compteurs 322 ci-dessus correspondent au contrôle de famille initial.
