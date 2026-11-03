# Glacier silencieux — Nivorath

**Lot graphique livré le 3 novembre 2026.** Branche `codex/glacier-nivorath`, créée depuis `main` actualisé. 1 visuels, 72 poses dessinées. Sources retenues du 2 novembre réimportées au format demandé ; aucun changement de gameplay.

![Planche du lot](../previews/glacier-nivorath/planche.webp)

[Vue au zoom du jeu](../previews/glacier-nivorath/zoom_jeu.png) · [Catalogue et animations](../previews/glacier-nivorath/catalogue.json) · [Rapport](../previews/glacier-nivorath/qualite.json)

## Contenu

| Identifiant | Nom | Animations dessinées |
|---|---|---|
| `boss.nivorath` | Nivorath, le Silence du Glacier | `idle`, `move`, `attack`, `claw`, `ice_spikes`, `blizzard_breath`, `spell_capture`, `spell_release`, `death`, `transform`, `shatter_floor`, `frozen_dive` |

## Recettes et contrôles

Quatre planches de six colonnes et trois rangées. Cellules **320 × 320**, échelle **0,5**, ancre au centre de masse : exception Dévoreur de `ART_BIBLE.md`. Le mode `center` de l’importeur aligne ce centre en x et y. Les noms et cadences prévus dans le manifeste sont conservés.

La lumière et les matières suivent les sources froides : glace, neige, blancs et bleus, liseré violet de Faille ; aucune couleur orange détectée dans les palettes livrées. Les recettes `assets/concepts/incoming/<id>/job.json` passent par `tools/art/import_sheet.py`. Prompts, sources retenues, empreintes et facteurs de cadrage sont conservés dans `source/`. Un facteur commun ajuste le cadrage de chaque créature ; une mort affaissée ne regonfle pas. `size_delivery.json` détaille les valeurs. Les sources de départ ne sont pas redessinées pour changer seulement la taille de cellule.

Le contour est inclus dans le budget de 32 couleurs : correction ciblée de l’importeur, accompagnée d’une régression. Les anciennes images déjà intégrées ne sont pas régénérées. Les sorties ont un alpha binaire, 32 couleurs opaques au plus, aucune pose vide parmi les animations dessinées et aucun pixel sur les bords de cellule. Les noms d’animations correspondent exactement aux entrées prévues du manifeste ; les cadences et boucles restent identiques.

Godot **4.3** : import, contrôle assets et banc de 72 captures 1280 × 720 au zoom du jeu, avec Chasseur témoin. **428 assets valides, 14 prévus, zéro erreur**. Ce banc est graphique : aucun combat, navigation ou synchronisation de mécanique n’est revendiqué. Les GIF font moins de 3 Mo.

Rejouer le banc après import :

```bash
godot --headless --import --path .
godot --path . --resolution 1280x720 res://tools/art/preview_glacier_sprites.tscn -- --catalog=res://docs/previews/glacier-nivorath/catalogue.json --out=/tmp/rift-glacier-nivorath --steps=72
```

## Limites et suite

- **Livré** : sprites du lot, icônes, recettes, sources retenues, planches, captures et contrôle assets sans erreur.
- **Non fait** : essais de campagne par le propriétaire et raccordement temporel des techniques par Claude.
- **Choix graphiques** : cadrage commun pour tenir dans les cellules, ancrage et palette limités sans modifier les mécaniques.
- **Protection** : `src/`, `data/` et tous les fichiers de la carte14 restent identiques à la base ; seules les entrées du lot changent dans le manifeste.

Dans cette branche indépendante, les entrées encore provisoires sont : `enemy.frost_crawler`, `enemy.blizzard_wolf`, `enemy.snow_wraith`, `enemy.ice_golem`, `enemy.frost_shaman`, `enemy.peak_yeti`, `enemy.rime_archer`, `enemy.hush_shard`, `enemy.ice_knight`, `enemy.frozen_sentry`, `enemy.icebreaker`, `enemy.silence_herald`, `enemy.frost_mammoth`, `enemy.snow_witch`. Les autres lots se fusionnent par leurs propres PR. Le statut `final` protège les dessins d’une génération procédurale ; la validation artistique en partie revient au propriétaire.

Poids des fichiers ajoutés ou modifiés : voir [poids.json](../previews/glacier-nivorath/poids.json), sources et aperçus compris. Essais et captures intermédiaires hors Git.
