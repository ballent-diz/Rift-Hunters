# Abyssarque — un boss, sept formes visuelles

Importer le lot complet avec `tools/art/import_abyssarch.py`, qui appelle l'import standard pour A puis B–G :

```powershell
python tools/art/import_abyssarch.py --preview-dir C:/chemin/hors-depot/apercus
```

`job.json` est la recette canonique A et référence `jobs/B.json` à `jobs/G.json` dans `phase_jobs`.
Un appel isolé à `import_sheet.py job.json` ne reconstruit que A ; la commande ci-dessus applique aussi
les formes, la palette commune, les icônes entières et la compression PNG sans perte.

Identifiant principal : `boss.abyssarch`. Les six variantes portent les suffixes
`.roots`, `.magma`, `.crystal`, `.ice`, `.rift`, `.death` ; ne pas créer sept fiches de boss.
Gabarit déjà intégré : `scale=0.5`, environ 450u, `BossData.visual_scale` attendu à **1.0**.
Mort complète : variante `.death`, animations `collapse` → `eye_close` → `hidden`.

Sources finales dans `source/planche_A.png` à `source/planche_G.png` ; prompts et recettes de détail dans `source/`.
Guide, captures, limites et contrôles : `docs/art/ABYSSARQUE.md` depuis la racine du dépôt.
