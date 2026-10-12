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

## Commandes

```bash
tools/run_tests.sh            # import + tests unitaires + validation données/assets + smoke test
tools/run_tests.sh unit       # tests unitaires seulement
godot --headless --import --path .                     # (ré)importer les ressources (traductions)
godot --path .                                         # lancer le jeu (nécessite un affichage)
godot --headless --path . res://tests/run_tests.tscn   # tests unitaires
godot --headless --path . res://tests/smoke/autoplay.tscn -- --minutes=8   # partie jouée par un bot
gdlint src tests tools        # lint GDScript (config : gdlintrc)
```

Captures d'écran dans le cloud : `xvfb-run -a godot --path . --rendering-driver opengl3 ...`.

## Architecture (détails : docs/ARCHITECTURE.md)

- `src/data/` : classes `Resource` des données (MonsterData, EnemyData, UpgradeData...).
- `data/` : contenu du jeu en `.tres` (un fichier par entité). Ajouter un monstre = ajouter
  un `.tres`, ses clés de traduction et (plus tard) ses assets. Aucun code à modifier.
- `src/core/` : autoloads (`GameDB`, `Settings`, `Profile`, `Router`). Garder ce nombre minimal.
- `src/combat/` : stats, dégâts, statuts, grille spatiale, effets de gameplay.
- `src/run/` : une partie (RunContext, directeurs de vagues/événements, offres d'amélioration).
- `src/entities/` : joueur, alliés, ennemis, boss, projectiles, ramassables.
- `src/progression/` : sauvegarde versionnée, arbre, maîtrise, objectifs, recherche.
- `src/ui/` : HUD, panneaux, refuge. L'UI lit les services, ne contient aucune règle de jeu.
- `src/assets/` : registre d'assets + placeholders générés (le jeu démarre sans sprites finaux).
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
