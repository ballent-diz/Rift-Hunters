# Trois propositions d'apparence du Chasseur

**Maquettes à valider, pas de sprites importés en jeu.** Aucune entrée de manifeste, scène, donnée de boutique, prix, statistique ou règle de gameplay créée. Les trois apparences visent le même corps, chapeau conique, masque et katana que le Chasseur actuel.

| Proposition | Palette et tenue |
|---|---|
| Veilleur de jade | Veste jade sombre, écharpe vert mousse, poignets argent et chapeau charbon bordé de menthe |
| Argent des temples | Tunique ivoire froide, écharpe turquoise, ceinture bleu nuit et chapeau gris acier |
| Nuit d'orage | Veste cobalt/indigo, écharpe grise, chapeau bleu nuit au bord argenté, bottes sombres |

L'arme conserve son accent blanc/cyan ; aucun effet de sort, avantage ou prix n'est associé à une tenue. Les images ne contiennent ni texte ni interface.

Six poses existantes ont servi de référence commune, assemblées en trois colonnes sur deux rangées : attente, deux instants de marche, préparation d'attaque, blessure et chute. `reference.json` conserve les indices du véritable atlas et son empreinte. Les trois propositions sont des éditions de cette même référence, générées par l'outil intégré, sans ressource tierce.

Les silhouettes et postures restent cohérentes visuellement ; certains détails sont redessinés. **Aucune identité pixel par pixel ni compatibilité d'import automatique n'est revendiquée.** Après validation d'une tenue, il faudra l'appliquer à l'ensemble des frames d'origine puis contrôler l'ancrage et les animations ; cela n'est pas fait dans ce lot de propositions.

Sources retenues, prompts et SHA : `assets/concepts/incoming/player.hunter/appearances/`. Aperçus légers et capture native720p : `docs/previews/apparences/`. Aucun fichier `.import` n'est versionné sous incoming.

## Récapitulatif de la journée du 28 octobre

| Lot | Livraison | Suite / limite |
|---|---|---|
| 1 · Monstres chapitre3 | PR #82, 14 créatures, 25 sources, 54 animations peintes, 324 poses ; import/contrôles/captures joints | Essai de foule par le propriétaire ; Enlisés sombres sur terre |
| 2 · Effets chapitre3 | Déjà livrés et fusionnés dans PR #78 | Raccords des effets aux attaques par Claude ; pas de régénération inutile |
| 3 · Glauquemire et lanterne | PR #83, six planches de boss, 14 animations, lanterne trois états, 15 clips | Choix artistique à valider ; transition vers le cœur non séparée et cœur discret ; avertissement GPU natif documenté |
| 4 · Escalier carte9 | Non commencé, condition absente de main2da0104 | Aucun commit « Carte9 : escalier » trouvé ; la mention trouvée concernait la carte5. Aucune texture ni collision touchée |
| 5 · Apparences | Trois planches de propositions dans cette PR | Choix du propriétaire avant conversion complète/import ; aucun prix |
| Carte13 · Jardins de cristal | Composition PR #81, brouillon | Plan à valider, collisions propriétaire, huit régions de détail ensuite |
| Carte14 · Puits des reflets | Composition PR #84, brouillon, commencée après13h | Plan à valider, collisions propriétaire, seize régions de détail ensuite |

Les captures des monstres et du boss sont des bancs visuels Godot, pas des combats. Les deux compositions de cartes ne sont pas des niveaux jouables et ne prétendent pas avoir passé la qualité finale de détail. Aucun travail de gameplay n'a été entrepris dans ces lots.

## Contrôles finaux

Import Godot headless, `tools/run_tests.sh assets` et `tools/run_tests.sh art` réussis : 424 entrées, 408 visuels valides, 16 provisoires, aucune erreur. Contrôles exécutés sur le runtime complet de main 2da0104, inchangé par ces propositions ignorées par Godot. Les contrôles des cartes finales existantes passent ; ils ne certifient ni les compositions en attente ni des tenues importées. Capture native de comparaison 1280 × 720 et journaux joints.
