# Rift Hunters — consignes pour les agents (Codex, Claude…)

Survivor-like 2D original (Godot 4.3, GDScript typé). Détails d'architecture : `docs/ARCHITECTURE.md`.
Les mêmes règles s'appliquent à tous les agents ; `CLAUDE.md` en est la version complète (commandes, pièges connus).

## Règles du projet (demandées par le propriétaire)

1. **Effort avant chaque tâche** : annoncer le niveau d'effort conseillé (low / medium / high / xhigh / max) et
   attendre le feu vert, sauf si l'utilisateur a explicitement autorisé à enchaîner plusieurs tâches.
2. **Bilingue FR/EN** : tout texte visible par le joueur passe par une clé de `i18n/strings.csv` avec les colonnes
   `fr` ET `en` remplies. Jamais de texte en dur. Le test `test_localization` échoue sinon.
3. **Langue de travail : français** (docs, commits, échanges). Identifiants de code en anglais.
4. **Rien n'est terminé sans vérification** : `tools/run_tests.sh` vert (et une capture si c'est visuel).

## Git : organisation commune

- `main` est la version de référence. On ne pousse pas directement dessus : une branche par tâche
  (`codex/<sujet>` pour Codex, `claude/<sujet>` pour Claude), créée **depuis un `main` à jour**, puis une pull request
  vers `main`. On fusionne seulement ce qui passe les tests.
- Avant de commencer : `git fetch origin && git checkout -b codex/<sujet> origin/main`.
- Un seul agent à la fois sur une même branche. Après fusion, supprimer la branche (pas de branches `snapshot/…` :
  l'historique git suffit pour revenir en arrière).
- Commits en français, petits et vérifiés. Ne jamais réécrire l'historique d'une branche partagée (pas de force-push).

## Commandes utiles

```bash
godot --headless --import --path .     # OBLIGATOIRE après ajout d'un class_name, d'une traduction ou d'une image
tools/run_tests.sh                     # tout ; ou : unit, scripts, persistence, assets, art, smoke, lint
gdlint src tests tools                 # lint (lignes ≤ 130, constantes avant les variables)
```

Captures sans écran : `xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900
res://tools/screenshot.tscn -- --out=<dossier> --times=20,60` (`--menu=main|refuge` pour les menus).

## Où sont les choses

- **Décisions de conception et chantiers à venir : [docs/ROADMAP.md](docs/ROADMAP.md)** (à lire avant toute tâche
  de gameplay ; détails dans `docs/design/`).
- Code : `src/` (données `src/data/`, combat `src/combat/`, partie `src/run/`, entités `src/entities/`, UI `src/ui/`).
- Contenu : `data/*.tres` (un fichier par entité) ; équilibrage dans `data/balance/`, `data/arenas/`, `data/difficulties/`.
- Sprites et décors : `assets/asset_manifest.json` est la source de vérité des chemins. Ne pas déplacer un fichier
  référencé sans mettre à jour le manifeste puis relancer les tests `assets`.
- Images de travail (planches IA, maps) : `assets/concepts/incoming/<identifiant>/` — mode d'emploi dans
  `assets/concepts/incoming/README.md`. Ce dossier est ignoré par Godot (`.gdignore`).
- Pipeline graphique : `tools/art/` (`import_sheet.py` pour les planches, `build_map.py` + `upscale.py` pour les
  maps dessinées). Règles graphiques : `docs/ART_BIBLE.md`.

## Génération et intégration de cartes

Lire [docs/MAP_GUIDELINES.md](docs/MAP_GUIDELINES.md) avant toute génération ou intégration de map. Ce document conserve les critères du propriétaire : espace de manœuvre, décors variés et à l’échelle du personnage, routes sans collisions, raccords invisibles et rendu net à l’écran.
