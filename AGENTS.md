# Rift Hunters — consignes pour les agents (Codex, Claude…)

Survivor-like 2D original (Godot 4.3, GDScript typé). Détails d'architecture : `docs/ARCHITECTURE.md`.
Les règles ci-dessous s'appliquent à tous les agents ; `CLAUDE.md` en est la version complète pour Claude
(commandes, pièges connus, plus l'annonce du niveau d'effort, propre à Claude). Codex n'annonce pas de niveau
d'effort et n'attend pas de feu vert pour commencer une tâche demandée.

## Règles du projet (demandées par le propriétaire)

1. **Bilingue FR/EN** : tout texte visible par le joueur passe par une clé de `i18n/strings.csv` avec les colonnes
   `fr` ET `en` remplies. Jamais de texte en dur. Le test `test_localization` échoue sinon.
2. **Langue de travail : français** (docs, commits, échanges). Identifiants de code en anglais.
3. **Vérification proportionnée** : `tools/run_tests.sh` pour les changements de code qui le justifient.
   Pour les lots visuels de Codex, décision du propriétaire du 14 octobre : contrôles ciblés de chargement et
   d’erreurs évidentes une fois en fin de lot, captures, puis essais en jeu par le propriétaire. Ne pas relancer
   systématiquement toute la suite à chaque retouche ; conserver les tests existants.

## Git : organisation commune

- `main` est la version de référence. On ne pousse pas directement dessus : une branche par tâche
  (`codex/<sujet>` pour Codex, `claude/<sujet>` pour Claude), créée **depuis un `main` à jour**, puis une pull request
  vers `main`. Pour le code, on fusionne seulement ce qui passe les tests ; pour les lots visuels de Codex,
  appliquer les contrôles ciblés et la validation manuelle indiqués ci-dessus.
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
- **Répartition** (voir la section du même nom dans `docs/ROADMAP.md`) : Codex principalement sur les sprites, les maps
  et les visuels ; Claude sur le code de gameplay. Avant de prendre un lot du plan, le marquer « en cours (qui) »
  dans `docs/ROADMAP.md` pour ne pas travailler à deux dessus.
- Code : `src/` (données `src/data/`, combat `src/combat/`, partie `src/run/`, entités `src/entities/`, UI `src/ui/`).
- Contenu : `data/*.tres` (un fichier par entité) ; équilibrage dans `data/balance/`, `data/arenas/`, `data/difficulties/`.
- Sprites et décors : `assets/asset_manifest.json` est la source de vérité des chemins. Ne pas déplacer un fichier
  référencé sans mettre à jour le manifeste puis relancer les tests `assets`.
- Images de travail (planches IA, maps) : `assets/concepts/incoming/<identifiant>/` — mode d'emploi dans
  `assets/concepts/incoming/README.md`. Ce dossier est ignoré par Godot (`.gdignore`).
- Pipeline graphique : `tools/art/` (`import_sheet.py` pour les planches, `map_regions.py` +
  `check_map_quality.py` pour les maps dessinées). Règles graphiques : `docs/ART_BIBLE.md`.
- **Cartes** : chaque carte suit le plan de SON prompt ; les cartes précédentes sont des références de style, jamais de
  plan. Pas d'arène ronde ou carrée par défaut, arène facultative, pas d'abris non demandés
  (`docs/maps/GENERER_UNE_CARTE.md` § 1 bis).
- **Avant toute planche de monstre, d'élite ou de boss** (chapitre 2 et suivants) : lire `docs/design/MONSTRES.md`.
  Il fixe les rangées à dessiner selon le rang (normaux : déplacement + attaque ; élites et boss : planches de
  techniques), la limite de 3 rangées par planche et les mécaniques associées. Ne pas ajouter de rangée hors de cette
  règle : une animation sans mécanique prévue ne sert pas en jeu. Le chapitre 1 garde ses planches.

## Génération et intégration de cartes

**Qualité obligatoire : [docs/maps/QUALITE_DES_CARTES.md](docs/maps/QUALITE_DES_CARTES.md)**. Chaque carte a la qualité
des Ruines des Cascades et des Hautes Terres, ni plus ni moins, quelle que soit sa taille : composition validée par le
propriétaire puis plan figé (aucune recomposition), une région redessinée par carré de 1672 unités
(`tools/art/map_regions.py`), et une livraison accompagnée du rapport **conforme** de `tools/art/check_map_quality.py`.
Un agrandissement de la composition (Real-ESRGAN ou autre) n'est jamais une carte finale.

Lire [docs/MAP_GUIDELINES.md](docs/MAP_GUIDELINES.md) avant toute génération ou intégration de map. Ce document conserve les critères du propriétaire : espace de manœuvre, décors variés et à l’échelle du personnage, routes sans collisions, raccords invisibles et rendu net à l’écran.
