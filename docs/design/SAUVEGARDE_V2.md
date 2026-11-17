# Sauvegarde de la version 3D (profil v2)

Session « Progression », 17 novembre 2026. Code : `draft3d/save.gd` (`DraftSave`), façades `draft3d/unlocks.gd`
(`DraftUnlocks`, API inchangée pour l'écran « Déblocages ») et `draft3d/progress.gd` (`DraftProgress`, chapitres).
Tests : `tests/unit/test_draft3d_save.gd`, étape `persistence` de `tools/run_tests.sh` (relecture après redémarrage).

## Fichier

`user://draft3d_profile.json` (Linux : `~/.local/share/godot/app_userdata/Rift Hunters/`). Séparé du profil v1
(`user://profile.json`, jamais lu ni écrit par la v2) et des réglages généraux (`Settings`, `user://settings.json`).

```json
{ "version": 1, "fragments": 0, "unlocked": ["cleaving_slash", "prismatic_lance"],
  "starting": ["cleaving_slash", "prismatic_lance"], "last_gain": -1,
  "chapters": { "reached": [1], "cleared": [] },
  "stats": { "runs": 0, "victories": 0, "defeats": 0, "kills": 0, "best_kills": 0, "guardians": 0,
             "devourers": 0, "fragments_earned": 0, "best_level": 0, "play_seconds": 0.0, "best_seconds": 0.0 },
  "settings": {} }
```

- `unlocked` : sorts et mutations (variantes) débloqués ; `starting` : les 2 sorts de départ.
- `chapters.reached` : chapitres lancés ou ouverts par une victoire ; `cleared` : chapitres vaincus.
- `settings` : réglages propres à la v2 (`DraftSave.setting` / `set_setting`). Vide pour l'instant : langue, volumes,
  commandes, aperçu des sorts restent dans `Settings`.
- Clés inconnues conservées telles quelles (un format plus récent n'efface rien).

## Robustesse (base v1 : `SafeJsonStore`)

- Écriture atomique : fichier `.tmp`, relecture, copie de l'ancien en `.bak`, renommage.
- Fichier illisible : copié en `.corrupted-<date>` (jamais supprimé), puis restauration depuis `.bak` ; sans copie
  valide, profil neuf (`LoadState.CORRUPTED_RESET`).
- Version future (`version` > `FORMAT`) : lue au mieux, jamais écrasée (`NEWER_VERSION`).
- Types réparés à la lecture (`DraftSave.sanitize`) : nombres JSON, doublons, valeurs négatives.
- Migrations : `DraftSave.migrate` (format 0 = ancien `draft3d_unlocks.json`). Ajouter une étape par nouveau format.

## Reprise des anciens fichiers v2

Au premier lancement sans profil, `draft3d_unlocks.json` (Fragments, déblocages, départ, dernier gain) et
`draft3d_progress.json` (chapitres vaincus) sont fusionnés dans le profil, qui est écrit aussitôt. Les anciens
fichiers restent en place ; la reprise n'a lieu qu'une fois (le profil fait foi ensuite).

## Quand on écrit

- À chaque déblocage et à chaque choix des sorts de départ (`DraftUnlocks`).
- Au lancement d'un chapitre (atteint) et en fin de partie : statistiques, chapitre vaincu, Fragments (`run.gd`,
  avant l'écran de fin).
- Jamais : bot et parties headless (`DraftSave.path = ""`), parties d'essai (`DraftSave.read_only = true` :
  `--boss-at`, `--god`, `--spells`, `--chapter`). Le mode test du boss (session Boss) n'a qu'à mettre
  `DraftSave.read_only = true` au lancement ; `run.gd` le remet à faux en quittant la partie.

## Réinitialiser la progression

Options du menu principal (pas en pause) : « Réinitialiser la progression », second appui pour confirmer.
L'ancien profil est gardé à côté (`.reset-<date>`), puis tout repart des sorts offerts (`DraftUnlocks.wipe`).
