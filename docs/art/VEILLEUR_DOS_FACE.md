# Veilleur des Seuils : dos et face

Le propriétaire a confirmé le 17 novembre que la demande concerne **`player.threshold_warden`**,
le personnage actuellement sélectionné en jeu, et non l'ancien `player.hunter` au chapeau de paille.
La branche conserve le nom demandé `codex/chasseur-dos-face`.

## Contrat livré

La cellule du Veilleur reste **112 × 80**, ancre **(56, 74)**, échelle **0,65**, palette originale de **48 couleurs**.
Les dimensions 96 × 80 et l'ancre (48, 74) du premier prompt concernaient l'ancien Chasseur.
La source publiée `source/profile_reference.png` verrouille les cinq anciennes rangées pixel pour pixel.
L'icône, les clips idle/move/attack/hurt/death, l'alias dash et les métadonnées d'ombre restent inchangés.

| Animation | Rangée, base zéro | Source | Images | Cadence | Boucle |
|---|---:|---|---:|---:|---|
| idle_back | 5 | idle_back.png | 6 | 7/s | oui |
| move_back | 6 | walk_back.png | 6 | 10/s | oui |
| idle_front | 7 | idle_front.png | 6 | 7/s | oui |
| move_front | 8 | walk_front.png | 6 | 10/s | oui |

Les bandes intermédiaires sont RGBA transparentes, conformément au job du Veilleur existant.
La planche peinte de départ utilise le fond sombre `#0a1321`. La lumière, l'écharpe ivoire, la cape ardoise,
les plaques d'acier usé, la chevelure cendrée et l'épée tenue de la main droite reprennent le personnage publié.
Les pieds touchent y = 74 sur chacune des 24 poses, sans déplacement vertical du point d'appui.
Les mouvements des jambes et de la cape sont dessinés dans la source ; aucune pose n'est synthétisée par déformation.

## Reproduction

Source retenue : `assets/concepts/incoming/player.threshold_warden/source/directions.png`.
Prompts exacts dans `assets/concepts/incoming/player.threshold_warden/prompts.json`, clé `directions`.
Génération avec l'outil intégré ImageGen, conditionnée par les deux premières rangées du Veilleur publié.

```sh
python3 tools/art/condition_warden_directions.py
python3 tools/art/import_sheet.py assets/concepts/incoming/player.threshold_warden/job.json
```

L'importeur accepte désormais `preserve_rows` pour figer un préfixe publié et refuse toute modification de ses
clips. Le nuancier `palette_source` est repris exactement lorsqu'il respecte déjà le budget de couleurs.
Un test d'extension vérifie les anciens pixels, les clips et l'ombre, l'icône, la réimportation reproductible,
le refus d'une modification de cadence publiée et la conservation de nuances voisines dans le nuancier.

## Contrôle et raccordement

- Planches ×4 : [idle](../previews/veilleur_dos_face/idle_x4.webp), [marche](../previews/veilleur_dos_face/walk_x4.webp).
- [Comparaison animée profil/dos/face](../previews/veilleur_dos_face/cycles.gif).
- [Capture de la feuille dans Godot](../previews/veilleur_dos_face/godot_sheet.png).
- [Rapport des invariants](../previews/veilleur_dos_face/validation.json).

La scène `tools/art/warden_directions_preview.tscn` affiche la feuille finale sans modifier le jeu.
Elle accepte `-- --out=<chemin.png>` pour produire une capture du viewport (fenêtre 1100 × 850).

Claude devra ensuite brancher idle_back/move_back pour le mouvement vers le haut de l'écran,
idle_front/move_front pour le mouvement vers le bas, avec une zone de stabilité entre les orientations.
Le profil reste celui des attaques, blessures et mort. Aucun fichier de `draft3d/`, `src/`, `data/` ni
`appearances/` n'est modifié dans ce lot. Les nouvelles orientations ne sont donc pas encore sélectionnées en partie.

Vérifications finales : `tools/run_tests.sh assets` vert (534 entrées, 513 valides, 21 placeholders préexistants, zéro erreur) ;
`tools/run_tests.sh art` vert (import, extensions de feuilles, ombres et six cartes finales conformes).
Capture native Godot 4.3 avec filtrage nearest. Aucun fichier interdit dans le diff.
