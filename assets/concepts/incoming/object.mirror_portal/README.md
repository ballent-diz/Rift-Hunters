# object.mirror_portal

Sprite peint, source retenue et job normalisé. Guide : `docs/art/OBJETS_PEINTS_CARTES.md`.

Import individuel : `python3 tools/art/import_sheet.py assets/concepts/incoming/object.mirror_portal/job.json`.
Reconstruction des sources normalisées et de toutes les variantes : `python3 tools/art/import_painted_objects.py`.

`poses.webp` conserve les cellules de 256 × 256 px, l'ancre (128, 232), l'alpha de l'ombre et la palette prélevée sur le décor. Ne pas recadrer ni recentrer les cellules. Le job utilise les options `registered_cells`, `keep_size` et `preserve_alpha`.

La planche originale et son prompt sont dans `../object.mirror_portal/source/`. Les autres teintes partagent ce dessin : la conversion de palette est limitée à la gemme et à quelques reflets. `source/normalization.json` indique cette source commune ; `source/palette.json` conserve les prélèvements exacts.
