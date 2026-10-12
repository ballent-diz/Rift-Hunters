# Audio

Déposez les fichiers (MP3, OGG ou WAV) dans ces dossiers : ils sont détectés automatiquement.

| Dossier | Joué pendant |
|---|---|
| `music/menu/` | écran titre et Refuge |
| `music/refuge/` | Refuge uniquement |
| `music/run/` | expéditions (un morceau au hasard par partie) |
| `music/boss/` | combats de Dévoreurs (phases 1 et 2) |
| `music/boss_phase2/` | phase 2 des Dévoreurs uniquement (facultatif) |
| `music/victory/`, `music/defeat/` | écran de fin (sans boucle) |

- Indiquez le BPM dans le nom pour synchroniser les pulsations : `assaut_165bpm.mp3`.
- Noms sans espaces ni accents recommandés. Git LFS conseillé pour les gros volumes (`git lfs track "*.mp3"`).
- Effets sonores : `sfx/<nom>.mp3`, associés aux événements dans `audio_manifest.json` (section `sfx`).
