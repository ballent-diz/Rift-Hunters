# Contrôles des effets du Dévoreur

- Quatorze scènes Godot autonomes : impacts, souffles, racines, invocations, transformation,
  réactions, fragment et télégraphe.
- Chargement dans une vraie partie gelée, Chasseur et Écho présents, capture native 1280 × 720.
- Animation du boss synchronisée uniquement pour l’aperçu ; aucune règle de combat ajoutée.
- `tools/run_tests.sh assets` : 337 ressources valides, aucune erreur.
- Les images animées sont des aperçus WebP qualité 94 ; les PNG restent à la résolution native.
- `performance.json` : 90 ennemis, huit effets, présentation seule. Cette mesure ne couvre pas
  l’IA, les collisions ou le coût d’un futur combat complet.
- Les messages de ressources encore référencées à la fermeture du banc de capture restent
  présents ; ils n’affectent pas le chargement des scènes ni les exports.

Raccordement, visée réelle, dégâts, invocations et occultation par les rochers : à réaliser par
Claude avec le prompt `docs/art/PROMPT_CLAUDE_DEVOREUR_SOURCES.md`.
