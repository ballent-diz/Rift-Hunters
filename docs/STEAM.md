# Préparation à la sortie (Steam)

## Déjà en place
- **Hors ligne** : aucun système de jeu ne dépend d'un service externe.
- **Sauvegardes** : `user://profile.json` et `user://settings.json` (+ `.bak`). Sous Windows :
  `%APPDATA%\Godot\app_userdata\Rift Hunters\`. À déclarer pour le **Steam Cloud** (Auto-Cloud, chemins ci-dessus).
- **Succès** : chaque objectif (`data/progression/objectives/*.tres`) appelle
  `PlatformServices.unlock_achievement(<id de l'objectif>)`. Créer dans Steamworks des succès portant
  exactement les mêmes identifiants (ex. `first_steps`, `devourer_slain`, `tension_three`...).
- **Manette** (Steam Deck) : stick gauche pour se déplacer, A/RB Ruée, X/Y/B Techniques, LB focus,
  Start pause ; visée au stick droit ou assistée ; menus navigables au pad.
- **Bilingue** FR/EN (ajout d'une langue = une colonne dans `i18n/strings.csv`).
- **Options** : plein écran, VSync, volumes séparés, chiffres de dégâts, secousses, réduction des flashs, FPS.
- **Préréglages d'export** : `export_presets.cfg` (Windows et Linux, sans les tests, outils, docs ni concepts).

## Reste à faire
1. Installer les modèles d'export Godot 4.3 (éditeur : Projet > Exporter > Gérer les modèles), puis :
   `godot --headless --export-release "Windows Desktop" build/windows/RiftHunters.exe`.
2. Icône Windows `.ico` (configurer `rcedit` dans l'éditeur) ; l'icône du projet est `icon.png` (placeholder).
3. Intégrer **GodotSteam** (GDExtension) et fournir un backend :
   ```gdscript
   class SteamBackend:
       func unlock_achievement(id: String) -> void:
           Steam.setAchievement(id)
           Steam.storeStats()
   # au démarrage, si Steam est disponible :
   PlatformServices.backend = SteamBackend.new()
   ```
4. Remplacer les placeholders par les sprites finaux (voir `docs/ASSET_PIPELINE.md`) et ajouter musiques et sons
   (`assets/audio/audio_manifest.json`) ; vérifier les droits commerciaux de chaque fichier.
5. Page Steam : capsules, captures, bande-annonce, classification d'âge, description FR/EN.
6. Licences : l'écran Crédits affiche la licence de Godot (`Engine.get_license_text()`). Garder
   `THIRD_PARTY_NOTICES.md` à jour (polices, sons, bibliothèques ajoutées).
