# Images à importer

Dépose ici les images produites par un générateur (ou dessinées), **un dossier par visuel**,
puis lance l'import : l'outil détoure le fond, découpe les frames, met tout à la même échelle,
réduit la palette, aligne les pieds sur l'ancre et écrit la feuille de sprites et l'icône
au bon endroit, puis met à jour `assets/asset_manifest.json`.

Règles graphiques : `docs/ART_BIBLE.md`. Prompts prêts à l'emploi : `docs/art_prompts.md`.

## 0. Rangement du dossier

- **Un dossier par identifiant du jeu** : `player.hunter/`, `monster.mossback/`, `enemy.skitterling/`,
  `boss.nebulorax/`, `map.fractured_plain/`… (le nom du dossier = l'identifiant du manifeste).
- Dans chaque dossier : les bandes d'animation découpées (`move.png`, `attack.png`…) et le `job.json` ;
  les **images d'origine** (planche complète, fiche de référence) dans `source/`.
- Planches qui mélangent plusieurs créatures : `planches_communes/`. Anciennes versions : `archive_v1/`…
- Images déposées mais pas encore intégrées : un dossier `<identifiant>_a_integrer/` (ex. `map.l1_a_integrer/`).
- Ce dossier contient un `.gdignore` : Godot ne l'importe pas (seuls les outils Python le lisent),
  il ne faut donc pas y versionner de fichiers `.import`.

## 1. Préparer le dossier

```
assets/concepts/incoming/monster.ashblade/
  reference.png      (facultatif, l'image de référence du personnage)
  idle.png           une image = une animation = une rangée de frames côte à côte
  move.png
  attack.png
  technique.png
  job.json
```

Conseils pour les images :
- fond uni (vert `#00D648` conseillé, sinon n'importe quelle couleur absente de la créature) ;
- frames sur **une seule rangée**, séparées par du fond (l'outil découpe sur les colonnes vides) ;
  si elles se touchent, indiquer `"layout": "grid", "grid": [colonnes, rangées]` ;
- créature tournée vers la droite (sinon `"flip": true`).

## 2. `job.json` (modèle)

```json
{
  "visual_id": "monster.ashblade",
  "cell": [64, 64],
  "anchor": [32, 54],
  "scale": 0.5,
  "target_height": 46,
  "status": "final",
  "background": "auto",
  "tolerance": 60,
  "colors": 32,
  "outline": true,
  "flip": false,
  "hover": 0,
  "animations": [
    {"name": "idle",      "source": "idle.png",      "frames": 8, "fps": 8,  "loop": true},
    {"name": "move",      "source": "move.png",      "frames": 8, "fps": 12, "loop": true},
    {"name": "attack",    "source": "attack.png",    "frames": 7, "fps": 16, "loop": false},
    {"name": "technique", "source": "technique.png", "frames": 8, "fps": 16, "loop": false}
  ],
  "aliases": {}
}
```

| Champ | Rôle |
|---|---|
| `visual_id` | identifiant du manifeste (liste dans `docs/art_prompts.md`) |
| `cell`, `anchor`, `scale` | tailles de la bible (§ 2) ; ne pas changer `scale` |
| `target_height` | hauteur de la créature en pixels d'art, mesurée sur la 1re animation |
| `status` | `final` : protégé de la génération procédurale ; `wip` : essai |
| `background` | `auto` (couleur des bords), une couleur (`"#00D648"`) ou `alpha` (déjà transparent) |
| `tolerance` | tolérance du détourage (0–255) : monter si un liseré de fond reste, baisser si la créature est rognée |
| `colors` | couleurs max de la palette commune (0 = pas de réduction) |
| `outline` | ajoute un contour sombre d'1 pixel |
| `flip` | `true` si les images regardent vers la gauche |
| `hover` | créatures volantes : pixels entre le bas du corps et l'ancre |
| `animations` | une entrée par image ; la 1re sert de référence d'échelle |
| `aliases` | animations manquantes réutilisant une autre ligne, ex. `{"technique": "attack"}` |
| `empty_animations` | poses runtime transparentes, sans source dessinée, ex. `[{"name":"death","fps":12,"loop":false}]` pour masquer le corps pendant une disparition commune |
| `frame_offsets` (par animation) | décalages graphiques `[x,y]` après ancrage, un par pose ; préserve une montée/piqué dans la cellule sans déplacer l’entité |

### Planches à plusieurs rangées (monstres à partir du chapitre 2)

Une planche de 6 colonnes sur 2 ou 3 rangées sert plusieurs animations : chaque entrée reprend la même `source` avec
`"grid": [6, <rangées>]` et la `"row"` lue (0 en haut). Un monstre peut avoir plusieurs planches (élites et boss).
Contenu des planches selon le rang : [docs/design/MONSTRES.md](../../../docs/design/MONSTRES.md).

```json
{"name": "move",   "source": "planche_A.png", "grid": [6, 3], "row": 0, "frames": 6, "fps": 10, "loop": true},
{"name": "attack", "source": "planche_A.png", "grid": [6, 3], "row": 1, "frames": 6, "fps": 12, "loop": false},
{"name": "death",  "source": "planche_A.png", "grid": [6, 3], "row": 2, "frames": 6, "fps": 12, "loop": false},
{"name": "leap",   "source": "planche_B.png", "grid": [6, 2], "row": 0, "frames": 6, "fps": 12, "loop": false}
```

## 3. Lancer l'import

```bash
# Essai sans rien écrire dans le jeu : aperçu dans assets/concepts/previews/<id>_import.png
python3 tools/art/import_sheet.py assets/concepts/incoming/monster.ashblade/job.json --preview-only

# Import réel, puis vérification
python3 tools/art/import_sheet.py assets/concepts/incoming/monster.ashblade/job.json
godot --headless --import --path .
tools/run_tests.sh assets
```

Le jeu utilise la nouvelle feuille au prochain lancement, sans code à modifier.
Les images d'origine peuvent rester ici : elles servent de source si on veut réimporter.
