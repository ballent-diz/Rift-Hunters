# Glacier silencieux — Normaux

**Lot graphique livré le 3 novembre 2026.** Branche `codex/glacier-normaux`, créée depuis `main` actualisé. 8 visuels, 108 poses dessinées. Sources retenues du 2 novembre réimportées au format demandé ; aucun changement de gameplay.

![Planche du lot](../previews/glacier-normaux/planche.webp)

[Vue au zoom du jeu](../previews/glacier-normaux/zoom_jeu.png) · [Catalogue et animations](../previews/glacier-normaux/catalogue.json) · [Rapport](../previews/glacier-normaux/qualite.json)

## Contenu

| Identifiant | Nom | Animations dessinées |
|---|---|---|
| `enemy.frost_crawler` | Rampe-givre | `move`, `attack` |
| `enemy.blizzard_wolf` | Loup de blizzard | `move`, `attack`, `slide` |
| `enemy.snow_wraith` | Spectre de neige | `move`, `attack` |
| `enemy.ice_golem` | Golem de glace | `move`, `attack` |
| `enemy.hush_shard` | Éclat du silence | `move`, `attack` |
| `enemy.ice_knight` | Chevalier de glace | `move`, `attack` |
| `enemy.frozen_sentry` | Sentinelle gelée | `move`, `attack` |
| `enemy.icebreaker` | Brise-banquise | `move`, `attack`, `dive` |

## Recettes et contrôles

Cellules **64 × 64**, échelle **0,5**, ancre (32,54). Les volants utilisent (32,58), retrait de 8 pixels. Les normaux ont déplacement et attaque ; le Loup ajoute `slide`, le Brise-banquise `dive`. Les élites ont A déplacement/attaque/mort, B deux techniques, C le troisième geste ; la seconde rangée de C reste transparente sans animation inventée.

La lumière et les matières suivent les sources froides : glace, neige, blancs et bleus, liseré violet de Faille ; aucune couleur orange détectée dans les palettes livrées. Les recettes `assets/concepts/incoming/<id>/job.json` passent par `tools/art/import_sheet.py`. Prompts, sources retenues, empreintes et facteurs de cadrage sont conservés dans `source/`. Un facteur commun ajuste le cadrage de chaque créature ; une mort affaissée ne regonfle pas. `size_delivery.json` détaille les valeurs. Les sources de départ ne sont pas redessinées pour changer seulement la taille de cellule.

Le contour est inclus dans le budget de 32 couleurs : correction ciblée de l’importeur, accompagnée d’une régression. Les anciennes images déjà intégrées ne sont pas régénérées. Les sorties ont un alpha binaire, 32 couleurs opaques au plus, aucune pose vide parmi les animations dessinées et aucun pixel sur les bords de cellule. Les noms d’animations correspondent exactement aux entrées prévues du manifeste ; les cadences et boucles restent identiques.

`idle` est un alias de `move`. La mort des normaux utilise une pose runtime transparente pour la dispersion commune ; cette pose ne compte pas comme dessin. Les deux volants gardent une marge sous leur silhouette.

Godot **4.3** : import, contrôle assets et banc de 18 captures 1280 × 720 au zoom du jeu, avec Chasseur témoin. **435 assets valides, 7 prévus, zéro erreur**. Ce banc est graphique : aucun combat, navigation ou synchronisation de mécanique n’est revendiqué. Les GIF font moins de 3 Mo.

Rejouer le banc après import :

```bash
godot --headless --import --path .
godot --path . --resolution 1280x720 res://tools/art/preview_glacier_sprites.tscn -- --catalog=res://docs/previews/glacier-normaux/catalogue.json --out=/tmp/rift-glacier-normaux --steps=18
```

## Limites et suite

- **Livré** : sprites du lot, icônes, recettes, sources retenues, planches, captures et contrôle assets sans erreur.
- **Non fait** : essais de campagne par le propriétaire et raccordement temporel des techniques par Claude.
- **Choix graphiques** : cadrage commun pour tenir dans les cellules, ancrage et palette limités sans modifier les mécaniques.
- **Protection** : `src/`, `data/` et tous les fichiers de la carte14 restent identiques à la base ; seules les entrées du lot changent dans le manifeste.

Dans cette branche indépendante, les entrées encore provisoires sont : `enemy.frost_shaman`, `enemy.peak_yeti`, `enemy.rime_archer`, `enemy.silence_herald`, `enemy.frost_mammoth`, `enemy.snow_witch`, `boss.nivorath`. Les autres lots se fusionnent par leurs propres PR. Le statut `final` protège les dessins d’une génération procédurale ; la validation artistique en partie revient au propriétaire.

Poids des fichiers ajoutés ou modifiés : voir [poids.json](../previews/glacier-normaux/poids.json), sources et aperçus compris. Essais et captures intermédiaires hors Git.
