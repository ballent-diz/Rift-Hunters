# Cartes B3 — Cascades et Hautes Terres d’Orage

## État et périmètre

Les deux cartes sont disponibles dans le sélecteur d’expédition existant. Les Hautes Terres utilisent le système actuel de vagues temporisées, avec quatre monstres normaux, trois élites et Astravorn. Les Cascades conservent leurs ennemis et Nébulorax ; leur finale attend le nettoyage des ennemis, invite à rejoindre le cercle, puis ouvre la faille et ferme le combat avec les Échos.

Le mode campagne « vagues par zone » dépend des lots A1 et A2 de Claude dans ROADMAP.md. Cette intégration graphique ne remplace pas ces lots et ne prétend pas les livrer. Les barrières et flèches du lot A3 restent à traiter avec leur système.

## Dimensions et circulation

| Carte | Surface de jeu | Source détaillée | Texture de présentation | Navigation |
|---|---|---|---|---|
| Ruines des Cascades | 5016 × 1672 | 3762 × 1254 | 7524 × 2508 | cellules de 48 |
| Hautes Terres d’Orage | 5016 × 5016 | 3762 × 3762 | 7524 × 7524 | cellules de 64 |

La seconde carte couvre exactement trois fois la surface de la première. Les collisions restent échantillonnées tous les deux points du monde, indépendamment de la grille plus large de navigation. Les petites pierres décoratives ne bloquent pas les routes ; seules l’eau, les falaises, les bâtiments et les massifs périphériques les limitent. Le premier pont des Cascades est volontairement cassé ; le passage terrestre nord le contourne. Le départ des Cascades se trouve au nord-ouest.

## Recette conservée

Les compositions, régions détaillées et corrections de raccords sont dans assets/concepts/incoming/map.three_rifts et map.storm_highlands. Chaque job.json conserve les prompts ImageGen et la provenance. Les sources sont ignorées par Godot.

1. Assembler les régions avec tools/art/assemble_cascade_regions.gd et assemble_storm_regions.gd.
2. Appliquer les raccords avec apply_cascade_seams.gd et apply_storm_seams.gd ; pour Orage appliquer le passage vertical puis horizontal.
3. Préparer les images de présentation avec prepare_detailed_maps.gd -- --out=<dossier>.
4. Convertir les PNG avec python tools/art/convert_detailed_maps.py <dossier>. La conversion WebP vérifie l’identité des pixels ; elle est sans perte.
5. Recalculer les champs avec build_cascade_ruins.py et build_storm_highlands.py (Pillow, numpy, scipy).
6. Importer dans Godot, lancer tools/run_tests.sh et inspecter les captures à la caméra réelle.

L’agrandissement de présentation utilise Lanczos, sans modèle de lissage IA. Les détails sont reconstruits dans les régions sources. Le shader de Nébulorax retire le résidu vert de sa planche originale sans remplacer ses animations. Le coursier est reconditionné par pack_heath_sprite.gd avec des découpes ajustées aux silhouettes pour conserver son museau.

La recette reste à confronter au retour du propriétaire en jeu avant de servir de base définitive aux cartes suivantes ; les critères durables sont dans MAP_GUIDELINES.md.

## Vérification du 14 octobre 2026

tools/run_tests.sh : scripts, 142 tests unitaires sur 142, persistance, assets, import graphique et smoke test verts. Deux placeholders préexistants (Mirrorling et Vorgranite) restent signalés ; aucun nouveau asset manquant. Une partie automatisée des Hautes Terres avec invulnérabilité de test et apparition anticipée du boss à 60 secondes a terminé en victoire à 160 secondes, 181 éliminations. Ce scénario vérifie les apparitions et le combat, pas l’équilibrage définitif.

Les captures des deux terrains et des boss sont dans docs/previews/cartes-b3. Le pack Windows contient assets/asset_manifest.json, vérifié au lancement du pack exporté.
