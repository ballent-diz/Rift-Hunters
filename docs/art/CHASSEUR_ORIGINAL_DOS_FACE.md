# Chasseur original : vues de dos et de face conservées pour plus tard

Le propriétaire a demandé le 17 novembre de terminer et fusionner aussi ce lot, après avoir confirmé
le Veilleur des Seuils comme personnage actuellement utilisé. Ce lot enrichit **`player.hunter`** ;
il ne modifie pas le personnage sélectionné en jeu ni ne branche les orientations.

## Contrat

- Cellules **96 × 80**, ancre **(48, 74)**, échelle **0,65**, fond des bandes **#0a1321**.
- Chapeau de paille conique, écharpe et ceinture rouges, tenue sombre, sabre dans la main droite.
- Vue légèrement plongeante ; lumière haut-gauche et contour violet sombre côté ombre.
- `idle_back` et `idle_front` : six images, 7/s, boucle ; `move_back` et `move_front` : six images, 10/s, boucle.
- Rangées ajoutées **5, 6, 7, 8** (indexation zéro). Les cinq anciennes rangées sont conservées pixel pour pixel.
- Les clips idle/move/attack/hurt/death, l'alias dash et l'icône sont inchangés.
- Appui des pieds à y = 74 ; contour ajouté jusqu'à y = 75, comme sur le profil original.

**Palette :** l'ancienne feuille possède déjà 50 couleurs opaques malgré le réglage historique à 48.
Ses pixels ne sont pas recolorés. Les nouvelles vues utilisent 42 nuances issues d'un nuancier de 48 couleurs
prélevé sur l'ancienne feuille ; aucun dépassement supplémentaire. La feuille complète conserve ses 50 couleurs.

## Sources et reproduction

Quatre sources peintes retenues dans `assets/concepts/incoming/player.hunter/source/`, noms idle_back,
walk_back, idle_front et walk_front. Les prompts exacts figurent dans `directions_prompts.json` du même job.
Génération avec l'outil intégré ImageGen ; le profil publié conditionne l'identité et la face idle conditionne
la marche de face. Les poses sont dessinées, sans transformation géométrique pour inventer le mouvement.

```sh
python3 tools/art/condition_hunter_directions.py
python3 tools/art/import_sheet.py assets/concepts/incoming/player.hunter/job.json
```

La référence `source/profile_reference.png` et `preserve_rows` figent les anciennes rangées lors des réimports.
L'importeur et son test de préservation sont ceux du lot Veilleur (PR #220).

## Aperçus

- [Repos ×4](../previews/chasseur_original_dos_face/idle_x4.webp).
- [Marche ×4](../previews/chasseur_original_dos_face/walk_x4.webp).
- [Comparaison animée profil/dos/face](../previews/chasseur_original_dos_face/cycles.gif).
- [Capture native Godot de la feuille finale](../previews/chasseur_original_dos_face/godot_sheet.png).
- [Rapport des invariants](../previews/chasseur_original_dos_face/validation.json).

La scène de contrôle `tools/art/hunter_directions_preview.tscn` accepte `-- --out=<chemin.png>`.
Aucun changement de `src/`, `data/`, `draft3d/` ou `appearances/`. Les orientations seront raccordées séparément
si ce personnage est réutilisé. Aucune nouvelle attaque, blessure ou mort de face/dos.

Contrôles locaux finaux : `tools/run_tests.sh assets` et `tools/run_tests.sh art` verts :
534 entrées, 513 valides, 21 placeholders préexistants, zéro erreur ; import Python, ombres et six cartes finales conformes.
Le cache local de deux modules Space Base a été régénéré pour supprimer des identifiants périmés ;
aucune réparation de cache ni modification de décor ne fait partie du lot. Capture native Godot 4.3 vérifiée.
