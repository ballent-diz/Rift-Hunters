# Pipeline d'assets

Objectif : des monstres reconnaissables, des animations propres, et un jeu qui démarre
toujours, même quand un asset n'existe pas encore (placeholder généré automatiquement).

## Étape 1 — Concept art

Une fiche par entité dans `docs/concepts/<catégorie>/<id>.md`, par exemple
`docs/concepts/bosses/nebulorax.md`. Contenu obligatoire :
- silhouette et proportions, détails distinctifs ;
- palette (5 à 6 couleurs en hexadécimal) ;
- lisibilité en vue de dessus (ce qui doit rester visible à 64 px) ;
- directions d'animation nécessaires et liste des animations avec nombre de frames ;
- taille de cellule et point d'ancrage.

Les images de référence (générées ou dessinées) vont dans
`assets/concepts/<catégorie>/<id>/`. Elles servent de référence et ne sont **jamais**
découpées pour devenir des frames.

## Étape 2 — Sprites et animations

Style, tailles, lumière, palette et animations : **`docs/ART_BIBLE.md`** (pixel art, 1 pixel d'art
≈ 1 pixel d'écran en 1080p grâce à `"scale": 0.5`). Résumé des cellules :

| Catégorie | Cellule | Ancre |
|---|---|---|
| Chasseur, Échos | 64×64 | (32, 54) — volants (32, 58) |
| Corrompus | 48×48 (Grouillard) ou 64×64 | (24, 42) / (32, 54) |
| Dévoreurs | 320×320 | centre du corps |
| Projectiles / effets | 32×32 ou 64×64 | centre |

Règles :
- PNG avec **fond transparent**, cellule **constante** dans toute la feuille.
- Une ligne par animation. Les frames vont de gauche à droite.
- Vue de côté tournée vers la droite (légère plongée), retournée horizontalement par le moteur.
  Si une créature a besoin de 4 directions, le déclarer dans le manifeste
  (`"directions": 4`, une ligne par direction).
- Aucune variation de silhouette, de proportions ou de palette entre les frames.
- Filtrage `nearest` automatique pour les feuilles (les placeholders restent lissés).

### Deux façons de produire une feuille

| Source | Commande | Statut |
|---|---|---|
| Procédural (sprites de travail) : `tools/art/pixelforge/` + une recette par créature dans `tools/art/creatures/` | `python3 tools/art/build.py monster.ashblade` | `wip` |
| Images d'un générateur ou dessinées : prompts dans `docs/art_prompts.md`, dépôt dans `assets/concepts/incoming/<id>/` | `python3 tools/art/import_sheet.py <job.json>` | `final` |

Les deux écrivent la feuille, l'icône, un aperçu agrandi (`assets/concepts/previews/`) et
l'entrée du manifeste. Une entrée `final` n'est jamais écrasée par `build.py`.
Mode d'emploi de l'import : `assets/concepts/incoming/README.md`.
Les prompts se régénèrent depuis `tools/art/prompts.py` (descriptions des visuels).

Animations minimales par catégorie (vérifiées par l'outil de validation) :

| Catégorie | Animations requises |
|---|---|
| `player` | idle, move, dash, hurt, death |
| `monster` | idle, move, attack, technique |
| `enemy` | move, death |
| `boss` | idle, move, attack, death (+ celles de sa fiche) |

## Étape 3 — Intégration

### Convention de fichiers
```
assets/sprites/<catégorie>s/<id>/<id>_sheet.png       ex. assets/sprites/monsters/ashblade/ashblade_sheet.png
assets/ui/icons/<catégorie>s/<id>.png                 icônes 64×64
assets/effects/<id>.png
assets/environments/<arène>/...
```

### Manifeste : `assets/asset_manifest.json`
Chaque entité de données référence un **identifiant d'asset** (`visual_id`, ex.
`monster.ashblade`), jamais un chemin de fichier.

```json
"monster.ashblade": {
  "status": "planned",
  "sheet": "res://assets/sprites/monsters/ashblade/ashblade_sheet.png",
  "cell": [64, 64],
  "anchor": [32, 54],
  "scale": 0.5,
  "animations": {
    "idle":   {"row": 0, "frames": 8, "fps": 8,  "loop": true},
    "move":   {"row": 1, "frames": 8, "fps": 12, "loop": true},
    "attack": {"row": 2, "frames": 7, "fps": 16, "loop": false}
  },
  "icon": "res://assets/ui/icons/monsters/ashblade.png"
}
```

`scale` : unités du monde par pixel d'art (0,5 pour tout le pixel art).
`status` : `planned` (rien produit), `wip` (sprite de travail), `final` (validé, protégé). Tant que la feuille n'existe pas, le
jeu utilise le **placeholder** décrit dans la donnée (`VisualData` : forme, couleurs,
taille), généré au lancement par `PlaceholderFactory`. Le résultat est cohérent et lisible,
et chaque entité garde sa silhouette propre.

### Remplacer un placeholder par un sprite final
Le plus simple : l'outil d'import (ci-dessus) fait les étapes 1 à 3. À la main :
1. Déposer la feuille au chemin indiqué par `sheet`.
2. Vérifier `cell`, `anchor` et les lignes/frames de chaque animation dans le manifeste.
3. Passer `status` à `wip` ou `final`.
4. Lancer `tools/run_tests.sh assets` : l'outil vérifie l'existence du fichier, les
   dimensions (multiples de la cellule), la transparence (canal alpha et coins
   transparents), l'ancre et les animations requises.
5. Lancer le jeu : l'entité utilise automatiquement le sprite (aucun code à modifier).

### Validation
`tools/validate_assets.gd` (lancé par les tests) produit un rapport :
- `OK` : asset final valide ;
- `PLACEHOLDER` : asset prévu mais absent (non bloquant, le jeu utilise le placeholder) ;
- `ERREUR` : fichier présent mais invalide (dimensions, transparence, animation manquante) :
  **bloquant**.
