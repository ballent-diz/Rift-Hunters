# Lueurine — import C8

Visuel monster.glowmoth généré avec imagegen, référence conservée puis réutilisée pour les animations.
Originaux : source/reference.png et source/sheet.png. Cinq bandes découpées à côté de job.json.

Statut final : contrôlé graphiquement ; sensation en partie à confirmer par le propriétaire.
Cellule [128, 112], ancre [64, 102], scale 0.75, target_height 52, hover 10.
La cellule réserve la place aux appendices sans changer la taille apparente du corps.

Fond #00D648, tolérance 30, trous 42 et holes_min_area 1. Despill global : False.
Les verts naturels de Sylvécaille et Lueurine sont préservés. Palette commune à 32 couleurs et contour discret.

Reproduction : python3 tools/art/prepare_c8_sheet.py glowmoth, puis
python3 tools/art/import_sheet.py assets/concepts/incoming/monster.glowmoth/job.json.
Séparations dans source/slicing.json ; éventuelles corrections dans source/overrides.json.

Prompts : docs/art/C8_PROMPTS.md. Provenance exacte : ../c8-generation/generation.json.
Contrôles : docs/previews/c8/, outils tools/art/review_c8.py et preview_c8.tscn.
Aucune donnée de gameplay ni ressource data/monsters créée ; le lot C7 reste distinct.
