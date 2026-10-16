# Rift Hunters — guide de travail pour Claude

Survivor-like 2D original (Godot 4.3, GDScript typé). Le joueur, un Chasseur de Failles,
combat des vagues de Corrompus avec une équipe d'Échos (créatures alliées originales).
Aucun lien avec une licence existante : noms, créatures, visuels et mécaniques sont originaux.

## Règles de collaboration (demandées par le propriétaire du projet)

1. **Effort avant chaque tâche** : avant de lancer une tâche, annoncer le niveau d'effort
   conseillé (low / medium / high / xhigh / max) et attendre le feu vert, pour que
   l'utilisateur puisse changer le réglage. Exception : quand l'utilisateur a explicitement
   donné le feu vert pour enchaîner plusieurs tâches.
2. **Bilingue FR/EN dès le départ** : tout texte visible par le joueur passe par une clé de
   traduction dans `i18n/strings.csv` avec les colonnes `fr` ET `en` remplies. Jamais de texte
   affiché en dur. Le test `test_localization` échoue si une traduction manque.
3. Langue de travail : français (docs, commits, échanges). Identifiants de code en anglais.
4. Ne jamais déclarer un système terminé sans l'avoir vérifié (tests + lancement).
5. Git partagé avec Codex (consignes communes : `AGENTS.md`) : une branche par tâche depuis `main` à jour,
   pull request vers `main`, pas de push direct sur `main`.

## Commandes

```bash
tools/run_tests.sh            # import + scripts + tests unitaires + persistance + assets + outils art + partie bot + lint
tools/run_tests.sh unit       # tests unitaires seulement (aussi : scripts, persistence, assets, art, smoke, lint)
tools/balance_sim.sh "mossback ashblade" "fractured_plain" "tension_0" 2   # campagne d'équilibrage (META=veteran)
godot --headless --import --path .     # (ré)importer : OBLIGATOIRE après ajout d'un class_name ou d'une traduction
godot --path .                         # lancer le jeu (nécessite un affichage)
godot --headless --fixed-fps 60 --path . res://tests/smoke/autoplay.tscn -- --starter=ashblade --arena=three_rifts
gdlint src tests tools                 # lint GDScript (config : gdlintrc, lignes ≤ 130)
python3 tools/art/build.py monster.ashblade              # sprites pixel art procéduraux (statut wip)
python3 tools/art/import_sheet.py <dossier>/job.json     # importer des images générées (statut final)
python3 tools/art/build_env.py fractured_plain           # décor d'arène depuis un pack (assets/third_party)
python3 tools/art/collision_mask.py export|build three_rifts   # collisions détourées à la main (docs/maps/)
python3 tools/audio/detect_bpm.py                        # mesurer le tempo des musiques (manifeste audio)
```

Graphismes : pixel art, règles dans `docs/ART_BIBLE.md` (cellules 64 px, `scale` 0,5, lumière
haut-gauche, liseré violet bas-droite). Mode d'emploi de l'import : `assets/concepts/incoming/README.md`.
Décor des arènes : pack Ninja Adventure (CC0, tuiles 16 px, `scale` 1) → `assets/environments/<id>/`, entrée
`environment.<id>` du manifeste, placé en jeu par `DecorLayout` (déterministe) et dessiné par `ArenaGround`.
Cartes dessinées : générer selon `docs/maps/GENERER_UNE_CARTE.md`, collisions et zones selon
`docs/maps/DE_L_IMAGE_AU_NIVEAU.md` (masque `collision.png` + éditeur de niveau `tools/level_editor.tscn`).

Captures d'écran dans le cloud :
`xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --fixed-fps 60 --resolution 1600x900 res://tools/screenshot.tscn -- --out=<dossier> --times=20,60`
(`--menu=main|refuge` pour les menus). Le rendu logiciel est lent : viser des instants courts (`--boss-at=35`).

Pièges connus : les sorties de Godot redirigées vers un tube sont perdues si le processus est tué
(écrire dans un fichier) ; un `.tres` généré doit déclarer ses sous-ressources avant usage ;
`Array.filter()` renvoie un tableau non typé (utiliser `assign`) ; une ternaire `[x] if c else y`
donne un tableau non typé.

## Architecture (détails : docs/ARCHITECTURE.md)

- **Feuille de route et décisions validées : `docs/ROADMAP.md`** (détails dans `docs/design/`), à lire avant
  toute tâche de gameplay.
- `src/data/` : classes `Resource` des données (MonsterData, EnemyData, UpgradeData...).
- `data/` : contenu du jeu en `.tres` (un fichier par entité). Ajouter un monstre = ajouter
  un `.tres`, ses clés de traduction et (plus tard) ses assets. Aucun code à modifier.
- `src/core/` : autoloads (`GameDB`, `Audio`, `Settings`, `Profile`, `Assets`, `Router`). Garder ce nombre minimal.
- `src/combat/` : stats, dégâts, statuts, grille spatiale, effets de gameplay.
- `src/run/` : une partie (RunContext, directeurs de vagues/événements, offres d'amélioration).
- `src/entities/` : joueur, alliés, ennemis, boss, projectiles, ramassables.
- `src/progression/` : sauvegarde versionnée, arbre, maîtrise, objectifs, recherche.
- `src/ui/` : HUD, panneaux, refuge. L'UI lit les services, ne contient aucune règle de jeu.
- `src/assets/` : registre d'assets + placeholders générés (le jeu démarre sans sprites finaux).
- `tools/art/` : pixelforge (rendu pixel art procédural), recettes `creatures/`, import d'images, prompts.
- Équilibrage centralisé : `data/balance/balance_config.tres`, `data/arenas/*.tres`,
  `data/difficulties/*.tres`. Pas de valeur d'équilibrage en dur dans le code de combat.

## Conventions

- GDScript typé partout (`var x: int`, retours typés). `class_name` pour les classes réutilisées.
- Identifiants de contenu : `StringName` en snake_case (`&"ashblade"`), uniques par type.
- Clés de traduction : `TYPE_ID_CHAMP` en majuscules (`MONSTER_ASHBLADE_NAME`).
- Pas de logique par entité dans `_process` : les managers itèrent (performance).
- Pas de chemins implicites (`get_node("../../X")`) : références injectées ou `@export`.
- Les effets (reliques, synergies, arbre, mutations) sont des `GameplayEffect` composés en données.
- Commits en français, petits et vérifiés.
