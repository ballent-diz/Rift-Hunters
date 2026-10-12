# Audio

Déposez les fichiers (MP3, OGG ou WAV) dans ces dossiers : ils sont détectés automatiquement.

| Dossier | Joué pendant |
|---|---|
| `music/menu/` | écran titre et Refuge |
| `music/refuge/` | Refuge uniquement |
| `music/run/` | expéditions (liste de lecture : morceaux enchaînés au hasard) ; aussi le menu s'il n'a pas de musique propre |
| `music/boss/` | combats de Dévoreurs (phases 1 et 2) |
| `music/boss_phase2/` | phase 2 des Dévoreurs uniquement (facultatif) |
| `music/victory/`, `music/defeat/` | écran de fin (sans boucle) |

- Tempo : mesuré automatiquement par `python3 tools/audio/detect_bpm.py` (section `bpm` du manifeste), ou
  indiqué dans le nom du fichier (`assaut_165bpm.mp3`). Il synchronise les pulsations de l'interface.
- Un dossier vide se rabat sur un autre : menu → run, refuge → menu, boss_phase2 → boss.
- Noms sans espaces ni accents recommandés. Git LFS conseillé pour les gros volumes (`git lfs track "*.mp3"`).
- Effets sonores : `sfx/<nom>.mp3`, associés aux événements dans `audio_manifest.json` (section `sfx`).
