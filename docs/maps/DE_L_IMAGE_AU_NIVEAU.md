# De l'image au niveau jouable

Mode d'emploi pas à pas pour le propriétaire : détourer les collisions soi-même, puis placer le départ, les zones,
les barrières et l'arène du boss à la souris. Générer l'image : [GENERER_UNE_CARTE.md](GENERER_UNE_CARTE.md).

## Vue d'ensemble

| Étape | Qui | Outil | Résultat |
|---|---|---|---|
| 1. Intégrer l'image | Codex (une fois par carte) | scripts de `tools/art/` | tuiles `map*.webp`, entrée du manifeste, `data/arenas/<id>.tres` |
| 2. Préparer le détourage | Propriétaire | `collision_mask.py export` | `reference.jpg` + `collision.png` |
| 3. Détourer | Propriétaire | Krita, GIMP ou Photopea | `collision.png` peint |
| 4. Construire les collisions | Propriétaire | `collision_mask.py build` | `field.png` + `preview.jpg` |
| 5. Placer départ, zones, barrières, arène | Propriétaire | éditeur de niveau (Godot) | `data/arenas/<id>.tres` |
| 6. Vagues et noms des zones | Propriétaire ou Claude | inspecteur de Godot + `i18n/strings.csv` | niveau complet |
| 7. Tester et envoyer | Propriétaire | jeu, GitHub Desktop | pull request |

## Prérequis (une fois)

Python 3 avec trois bibliothèques. Dans un terminal ouvert dans le dossier du jeu
(GitHub Desktop : *Repository → Open in Command Prompt / Terminal*) :

```
pip install numpy pillow scipy
```

Sous Windows, si `python` n'est pas reconnu, utiliser `py` à la place dans toutes les commandes ci-dessous.

## 2. Préparer le détourage

```
python tools/art/collision_mask.py export <arène>
```

`<arène>` est le nom du fichier dans `data/arenas/` sans `.tres` (ex. `three_rifts`, `storm_highlands`).
Le dossier `assets/concepts/incoming/map.<arène>/collision/` contient alors :

- `reference.jpg` : la carte entière, **1 pixel = 1 unité du monde** (fond pour peindre, non envoyé sur GitHub) ;
- `collision.png` : le masque, même taille. **Blanc = praticable, noir = bloqué.** Au premier export, il reprend
  les collisions actuelles du jeu : on part de l'existant et on corrige. Un export suivant ne l'écrase jamais.

Les Ruines des Cascades et les Hautes Terres d'Orage ont déjà leur dossier prêt.

## 3. Détourer (Photopea, gratuit dans le navigateur ; même principe dans Krita ou GIMP)

1. Ouvrir `reference.jpg`, puis *Fichier → Ouvrir et placer* `collision.png` : il devient un calque au-dessus.
2. Régler l'**opacité** du calque `collision` à 40-50 % : on voit la carte à travers.
3. Peindre **sur le calque collision** avec un pinceau **dur** (dureté 100 %, sans lissage) :
   - **noir** : eau, falaises, forêts denses, bâtiments, murs, bords de la carte ;
   - **blanc** : sol, routes, ponts, escaliers, places, petits cailloux décoratifs.
   L'outil *Lasso polygonal* + *Remplir* va vite pour les grandes surfaces.
4. Remettre l'opacité à 100 %, **masquer** `reference`, puis *Fichier → Exporter → PNG* en écrasant
   `collision.png` (même taille, sans redimensionner).

Conseils :

- Suivre le **pied** des falaises, des arbres et des murs (là où ils touchent le sol), pas leur sommet.
- Garder les passages à **120 pixels de large au minimum** (1 pixel = 1 unité) ; sinon hordes et Échos s'y bloquent.
- Pas de taches blanches isolées dans le noir (le contrôle les signale en magenta) : un ennemi pourrait y apparaître.
- Pour un pont cassé : noir sur toute la largeur du vide.

## 3 bis. Méthode rapide : peindre en rouge sur la carte (18 octobre 2026)

Sans calque ni noir et blanc : prendre la carte elle-même (capture ou image du jeu, **n'importe quelle taille**, même
cadrage), peindre en **rouge translucide** tout ce qui est bloqué, puis :

```
python tools/art/collision_mask.py overlay <arène> <image peinte>
python tools/art/collision_mask.py build <arène>
```

- Le rouge peut être plus ou moins opaque : l'outil compare l'image peinte à la carte d'origine (il reconnaît aussi
  la peinture sur la lave ou le feuillage rouge).
- **L'eau de la carte est toujours bloquée**, et le **bord de la carte** aussi, même non peints.
- Seule la grande région praticable est gardée : un îlot non relié devient bloqué.
- On peut **annoter sur la même image** : traits **noirs**, **bleus** ou **rouge foncé** (barrières, numéros de
  zone). Ils sont ignorés pour les collisions (le passage sous un trait reste praticable). Ils servent à indiquer à
  Claude où placer les barrières. Convention des Ruines des Cascades : noir = sortie de la zone 1, bleu = sorties de
  la zone 2, rouge foncé = entrées de l'arène qui se ferment au combat final.
- Garder l'image peinte dans `assets/concepts/incoming/map.<arène>/collision/painted.webp` (source des collisions).

## 4. Construire les collisions

```
python tools/art/collision_mask.py build <arène>
```

Le script écrit `assets/environments/<décor>/field.png` (les collisions lues par le jeu), met à jour le manifeste et
produit `preview.jpg` dans le dossier de travail : **rouge = bloqué, magenta = îlot praticable isolé**. Il liste aussi
les îlots isolés avec leurs coordonnées (normal s'ils sont voulus, par exemple une plate-forme inaccessible).

`collision.png` devient la référence des collisions de cette carte : ne plus relancer l'ancien script de collisions
de la carte (`build_cascade_ruins.py`, `build_storm_highlands.py`), qui écraserait `field.png`.

## 5. Placer départ, zones, barrières et arène : l'éditeur de niveau

Dans Godot : ouvrir `tools/level_editor.tscn`, puis **Lancer la scène actuelle** (icône de clap en haut à droite,
ou F6 ; sur un portable, Fn+F6). Il charge les Ruines des Cascades ; pour une autre arène, changer `arena_id` en
haut de `_ready()` dans `tools/level_editor.gd`, ou lancer
`godot --path . res://tools/level_editor.tscn -- --arena=<arène>`.

Ce qu'on voit :

- **hachures sombres** : décor bloqué (d'après `field.png`) ; touche **L** pour recharger après un nouveau `build` ;
- **couleurs** : régions séparées par les barrières fermées (bleu = zone 1, vert = zone 2, jaune = arène…).
  **Si deux zones ont la même couleur, il y a une fuite** : un passage non fermé par une barrière ou par du noir ;
- rectangles : barrières (couleur de leur zone) ; petit carré dans le coin = poignée de taille ;
- points : ancre de chaque zone (« Zone 1 »…), **orange** = centre de l'arène du boss (avec son cercle),
  **blanc** = départ du Chasseur.

| Action | Commande |
|---|---|
| Déplacer un point ou une barrière | glisser au clic gauche |
| Redimensionner une barrière | glisser le petit carré du coin bas-droit |
| Nouvelle barrière pour la zone choisie | clic droit glissé |
| Choisir la zone | touches 1 à 9 |
| Nouvelle zone (ancre sous la souris, vagues copiées de la zone choisie) | N |
| Supprimer la barrière survolée / la zone dont l'ancre est survolée | Suppr / Maj+Suppr |
| Déplacer la vue | ZQSD, WASD, flèches, clic milieu glissé |
| Zoom | molette, pincement du pavé tactile, + et - |
| Afficher / masquer collisions et régions | C |
| Recharger les collisions | L |
| **Enregistrer** | **Ctrl+S** |

Règles de placement :

- Le **départ** dans la zone 1, sur une place dégagée.
- L'**ancre** d'une zone au milieu de sa grande clairière (c'est par elle que le jeu reconnaît la zone).
- Les **barrières de sortie** d'une zone ferment **tous** ses passages vers la suite : les placer au point le plus
  étroit, en débordant un peu sur le noir de chaque côté. Les barrières de la dernière zone ferment l'arène.
- Le **centre de l'arène** au milieu de la place du boss.
- Vérifier les couleurs après chaque barrière : chaque zone et l'arène doivent avoir **leur propre couleur**.

Ctrl+S enregistre `data/arenas/<arène>.tres` et le départ dans `assets/asset_manifest.json` (la console de Godot
affiche « enregistrement réussi »). Le fichier `.tres` est réécrit en entier : le diff est plus long que la
modification, c'est normal.

## 6. Vagues et noms des zones

Dans le panneau *FileSystem* de Godot, double-cliquer `data/arenas/<arène>.tres` ; dans l'inspecteur, *Zones* :

- `name_key` : clé du nom de la zone, à ajouter dans `i18n/strings.csv` avec le français **et** l'anglais
  (sinon le test de traduction échoue) ; puis relancer l'import (`godot --headless --import --path .` ou rouvrir Godot) ;
- `waves` : pour chaque vague, `enemies` (identifiants), `weights`, `count`, `elites`, `spawn_rate`, `max_alive` ;
- `heal_ratio` et `reward_chest` : récompense à la sortie.

Claude peut faire cette étape (et l'équilibrage) sur demande, à partir du niveau placé.

## 7. Tester et envoyer

- Jouer la carte depuis le refuge, ou regarder le bot la jouer :
  `godot --headless --fixed-fps 60 --path . res://tests/smoke/autoplay.tscn -- --arena=<arène>`.
- GitHub Desktop : nouvelle branche, puis commit de `collision.png`, `field.png`, `asset_manifest.json` et
  `data/arenas/<arène>.tres` (`reference.jpg` et `preview.jpg` ne sont pas envoyés), puis pull request vers `main`.
