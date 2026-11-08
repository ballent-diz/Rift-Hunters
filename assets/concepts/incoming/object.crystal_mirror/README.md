# object.crystal_mirror

Sprite peint, source retenue et job normalisé. Guide : `docs/art/OBJETS_PEINTS_CARTES.md`.

Import individuel : `python3 tools/art/import_sheet.py assets/concepts/incoming/object.crystal_mirror/job.json`.
Reconstruction des sources normalisées et de toutes les variantes : `python3 tools/art/import_painted_objects.py`.

`poses.webp` conserve les cellules de 256 × 256 px, l'ancre (128, 232), l'alpha de l'ombre et la palette prélevée sur le décor. Ne pas recadrer ni recentrer les cellules. Le job utilise les options `registered_cells`, `keep_size` et `preserve_alpha`.

La planche originale et le prompt exact sont dans `source/`. Les prélèvements et la recette de normalisation y sont conservés. Les cristaux des Jardins reprennent les deux dernières poses de fracture de la terrasse pour terminer leur effondrement, avec leur propre palette.
