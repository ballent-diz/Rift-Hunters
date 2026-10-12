# Architecture technique

## 1. Audit initial (12/10/2026)

- Dépôt vide (README seul) : aucune contrainte héritée.
- Outils : Godot 4.3-stable (headless, installé par `.claude/hooks/session-start.sh`),
  gdtoolkit 4 (gdlint/gdformat), Xvfb + OpenGL3 pour les captures d'écran.
  Les sessions cloud ne gardent rien : seul ce qui est poussé sur Git persiste.
- Vérifié : chargement de `.tres` écrits à la main (sous-ressources, tableaux typés),
  import CSV → traductions, autoloads en mode headless, rendu Xvfb.

## 2. Arborescence

```
project.godot
data/            contenu du jeu (.tres) — un fichier par entité, sans code
  balance/  monsters/  enemies/  affixes/  bosses/  statuses/  upgrades/  relics/
  synergies/  arenas/  difficulties/  progression/{skill_tree,objectives,research}/
i18n/strings.csv     toutes les chaînes FR/EN
assets/              concepts/, sprites/, effects/, environments/, ui/, audio/
  asset_manifest.json   identifiant d'asset → fichiers + découpage des animations
src/
  core/        autoloads : GameDB, Settings, Profile, Router, Assets
  data/        classes Resource (MonsterData, EnemyData, ...)
  combat/      StatSheet, DamageInfo, CombatSystem, StatusSystem, SpatialGrid, effects/
  entities/    player/, allies/, enemies/, bosses/, projectiles/, pickups/, hazards/
  run/         RunController, RunContext, SpawnDirector, EventDirector, UpgradeOffers, BuildState
  progression/ SafeJsonStore, migrations, ProfileData, services (arbre, maîtrise, objectifs...)
  ui/          hud/, panels/, refuge/, thème
  assets/      AssetRegistry, PlaceholderFactory, EntityVisual
scenes/        scènes racines (main, refuge, run)
tests/         runner + tests unitaires + smoke test autoplay
tools/         run_tests.sh, validate_assets, validate_data
docs/          GDD, architecture, pipeline d'assets, fiches concept
```

## 3. Principes

- **Données ≠ comportement.** Une `MonsterData` décrit stats, rôle, attaque, technique,
  évolutions, affinités, visuel, déblocage. Le comportement est choisi par un identifiant
  (`behavior_id`, `technique_id`) qui pointe vers une classe de stratégie paramétrée par les
  données. Ajouter un Écho qui réutilise des comportements existants = 0 ligne de code.
- **Effets composables.** Reliques, synergies, mutations, nœuds d'arbre, récompenses de
  maîtrise et évolutions listent des `GameplayEffect` (modificateur de stat, statut au
  toucher, bonus contre un statut, frappe supplémentaire, propagation à la mort...).
  Chaque effet s'installe sur le `RunContext` au début de la partie ou à l'acquisition.
- **Événements de combat.** `RunEvents` émet `hit`, `kill`, `status_applied`, `dash`,
  `technique_cast`, `detonation`... Les effets s'y abonnent ; le combat ne connaît pas les reliques.
- **Pas de moteur physique pour la foule.** Ennemis, projectiles et ramassables sont des
  `Node2D` mis à jour par leurs managers (une boucle, pas de `_process` par entité) avec une
  **grille spatiale** maison pour les requêtes de proximité et la séparation.
  Projectiles et textes de dégâts sont **poolés**.
- **Services purs testables.** La progression (récompenses de fin de partie, arbre,
  objectifs, maîtrise, migrations de sauvegarde) est faite de classes sans nœud, testées
  directement.
- **Autoloads minimaux** : `GameDB` (données), `Settings` (options), `Profile`
  (progression + sauvegarde), `Router` (navigation), `Assets` (sprites/placeholders).
  Pas d'état de partie global : tout l'état d'une partie vit dans `RunContext`.

## 4. Flux d'une partie

```
Router.start_run(RunSetup) → scenes/run.tscn (RunController)
  RunController crée RunContext, Player, managers, UI
  installe : effets de l'arbre, maîtrises, variante, relique de départ
  boucle physique (ordre fixe par process_priority) :
    SpawnDirector → EventDirector → Player → AllyManager → EnemyManager (statuts, IA, contact)
    → ProjectileManager → PickupManager → HazardManager → BossController
  Fin (victoire/défaite) → RunResult → Profile.apply_run_result() → sauvegarde → écran de résultats
```

## 5. Sauvegarde

- Fichiers : `user://profile.json` (progression) et `user://settings.json` (options).
- En-tête : `format_version`, `game_version`, `saved_at`.
- Écriture **atomique** : écriture `*.tmp` → relecture et validation → l'ancien fichier
  devient `*.bak` → renommage du `.tmp`.
- Chargement : fichier absent → `.bak`, sinon profil neuf. Fichier corrompu → copie
  `*.corrupted-<date>.json` conservée, on tente le `.bak`, et le joueur est **averti**.
  Version plus récente que le jeu → lecture seule (on n'écrase jamais).
- Migrations : `SaveMigrations` enchaîne `v1 → v2 → ...` (fonctions pures testées).
- Les identifiants inconnus (contenu retiré) sont conservés, pas supprimés.

## 6. Risques et décisions coûteuses à prendre tôt

| # | Sujet | Décision / statut |
|---|---|---|
| 1 | Foule d'entités | Grille spatiale + managers (pas de physique Godot). Si > 1000 ennemis sont nécessaires : rendu MultiMesh puis GDExtension pour les boucles chaudes. Mesurer d'abord (test de perf inclus). |
| 2 | Identifiants de contenu | Ne **jamais** renommer un id publié (sauvegardes). Renommage = alias dans les migrations. |
| 3 | Format de sauvegarde | Versionné dès v1, migrations testées. |
| 4 | Localisation | Clés dès le jour 1 ; test bloquant si FR ou EN manque. |
| 5 | **Style graphique** | **À décider avant la production d'assets** : pixel art (filtrage nearest, tailles de cellule fixes) ou 2D dessinée HD. La planche Nébulorax tend vers un pixel art détaillé. Les tailles de cellule proposées sont dans le pipeline d'assets. |
| 6 | Version de Godot | Figée sur 4.3-stable. Mise à jour = tâche dédiée avec tests. |
| 7 | Steam | Objectifs conçus pour être reliés plus tard aux succès Steam (GodotSteam). Aucune dépendance en jeu. |
| 8 | Alliés invulnérables | Choix du prototype (lisibilité, pas de micro-gestion de soins). À réévaluer en phase 4. |
| 9 | Résolution | Base 1280×720, étirement `canvas_items`, aspect `expand` : l'UI s'adapte (16:9, 16:10, ultrawide). |
