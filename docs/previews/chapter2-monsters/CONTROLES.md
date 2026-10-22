# Contrôles de la livraison

- Godot 4.3 : import sans erreur.
- `tools/run_tests.sh assets` : 322 entrées, 322 valides, aucun placeholder, aucune erreur.
- `python tools/art/test_import.py` : import, palette, détourage, échelle et ancrage vérifiés.
- Rapport `import_report.json` : dimensions et bords des poses de la famille.
- Captures Godot 1280 × 720 : partie gelée, son coupé, profil en lecture seule, Chasseur et
  Mousseroc présents pour l’échelle ; un Courser des landes existant sert aussi de référence.
- Normaux : pas de mort dessinée ; une pose transparente de compatibilité masque le sprite.
- Validation artistique de la famille et des animations supplémentaires du Dévoreur : en attente.

Le rendu est préparé pour raccordement. Les nouvelles créatures ne sont pas encore ajoutées aux
vagues ou aux données de combat : ce travail reste à Claude.
