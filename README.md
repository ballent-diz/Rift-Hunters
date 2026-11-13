# Rift Hunters

Survivor-like original (Godot 4.3, GDScript) : décors 3D modulaires, personnages et monstres en sprites 2D.
Un Chasseur de Failles affronte des hordes de Corrompus, ramasse leur EXP, choisit ses améliorations et abat le
Dévoreur du chapitre. Jeu solo, au clavier, en français et en anglais.

**Version 2 (3D) = jeu principal** depuis le 13 novembre 2026 : code dans `draft3d/`, guide dans
[docs/PREMIER_JET_3D.md](docs/PREMIER_JET_3D.md). **La version 1 (2D) est archivée** sur la branche
`archive/v1-2d`. Son code reste dans ce dépôt tant que la v2 en réutilise des pièces (données de `data/`,
autoloads de `src/core/`, sprites, effets, audio, textes) ; on peut encore la lancer avec
`godot --path . res://scenes/main.tscn`.

## Jouer
1. Installer [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (version standard).
2. Ouvrir le dossier du projet dans Godot (le premier import prend quelques secondes), puis F5.
   En ligne de commande : `godot --path .` · sous Windows : double-clic sur `lancer.cmd`.

Contrôles : ZQSD/WASD ou flèches · Espace ou Maj Ruée · attaque et sorts automatiques · 1 2 3 ou clic pour choisir
une amélioration · molette zoom · R rejouer · Échap quitter.

## Documentation
- Game design : [docs/GDD.md](docs/GDD.md)
- Équilibrage : [docs/BALANCE.md](docs/BALANCE.md)
- Sortie Steam : [docs/STEAM.md](docs/STEAM.md)
- Audio (où déposer musiques et sons) : [assets/audio/README.md](assets/audio/README.md)
- Architecture : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Pipeline d'assets : [docs/ASSET_PIPELINE.md](docs/ASSET_PIPELINE.md)
- Conventions de travail : [CLAUDE.md](CLAUDE.md)
