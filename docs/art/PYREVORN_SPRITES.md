# Pyrevorn — quatre planches et onze animations

Dévoreur volcanique du chapitre 2. Livraison graphique uniquement : aucun fichier `src/` ou
`data/` modifié, aucun comportement de boss ajouté. Apparence proposée à la validation du propriétaire.
Les sept Enfants du magma sont déjà validés ; Pyrevorn conserve le statut `wip` en attendant son avis.

## Atlas et échelle

Clé `boss.pyrevorn` ; atlas `assets/sprites/bosses/pyrevorn/pyrevorn_sheet.png`.
Cellules 512 × 512, ancre de pieds `[256, 480]`, échelle `1.0`, hauteur cible 150 pixels d’art,
comme le job actuel de Nébulorax. Le grand cadre est un espace de mouvement, pas une taille de corps.
Palette de 32 couleurs : basalte, charbon, orange et jaune-blanc ; pas de violet principal.

Chaque animation contient **six poses**. `idle` et `phase2_idle` : 7 images/s, boucle de 0,857 s.
`move` : 9 images/s, boucle de 0,667 s. Toutes les autres : 9 images/s, 0,667 s, sans boucle.
`attack` est un alias de `claws`, pas une douzième animation dessinée.

| Planche | Animations | Déclenchement attendu côté gameplay |
|---|---|---|
| A, 6 × 3 | `idle`, `move`, `claws` | Attente, déplacement, attaque au contact |
| B, 6 × 3 | `magma_breath`, `crater_rain`, `brood_call` | Souffle, pluie de roches, invocation |
| C, 6 × 2 | `transform`, `death` | Changement de phase, mort |
| D, 6 × 3 | `phase2_idle`, `skyfall`, `rift_eye` | Phase 2, envol et chute, rayon de l’œil |

Le souffle et le flash de l’œil sont volontairement courts dans la feuille : le véritable cône,
les projectiles de cratère, les invocations, les anneaux de lave et le rayon mobile seront des objets
ou effets du jeu. Aucun grand cercle ni aire de dégâts n’est peint dans le sprite.
La mort se termine par une carcasse noire refroidie ; le moteur choisira ensuite sa disparition.

## Contrat de raccordement pour Claude

- Charger les frames via `Assets.get_sprite_frames(&"boss.pyrevorn")`, l’ancre et l’échelle du manifeste.
- Garder les noms ci-dessus. Les phases, durées de préparation, impacts et collisions restent au gameplay.
- `skyfall` contient les décalages graphiques `[0, -60, -140, -170, -70, 0]` pixels ; ils ne déplacent
  ni la collision ni l’entité. Le moteur décide seul de l’invulnérabilité, de la cible et du retour au sol.
- Pour un envol hors écran plus long, masquer/déplacer la représentation côté moteur ; ne pas étirer
  les six poses et ne pas déduire l’impact de la position du dessin.
- Pour la phase 2, utiliser `phase2_idle` entre les techniques. Aucune attaque de base de phase 2
  supplémentaire n’est prétendue dans cette livraison.
- Les rochers et murs réels doivent arrêter les attaques qui le prévoient. Un sprite ne définit pas
  de couverture, de télégraphe, de dégâts, d’apparition ou d’équilibrage.

## Sources et réparations conservées

`assets/concepts/incoming/boss.pyrevorn/source/` conserve les quatre planches, les versions rejetées,
les prompts exacts, les métadonnées et les SHA256. Génération intégrée à Codex, sans source tierce.
`PROMPT_A_PADDING.txt` garde la retouche de cadrage de la planche A ; `PROMPT_D_PADDING.txt` garde
la retouche de l’armure endommagée et du cadrage de D.

Les ailes d’envol de D débordaient sur les cellules voisines. Une bande `skyfall_repair.png`
a donc été générée ; ses **six composantes entières et séparées** ont été réespacées par découpage
technique, sans redessiner leurs contours. `skyfall_extraction.json` et `normalization.json` donnent
les coordonnées et facteurs utilisés. Les autres animations ne sont pas remplacées par cette bande.

Reproduction : `package_pyrevorn.py <sources>`, puis `clean_sprite_gutters.py <job.json>` et
`import_sheet.py <job.json>`. Les sources originales ne sont jamais modifiées par le nettoyage.

## Contrôles visuels

- 66 poses importées ; aucune ne touche le bord de sa cellule, rapport `import_report.json`.
- [Planche des animations](../previews/pyrevorn/pyrevorn_animations.png).
- [Échelle avec Nébulorax, le Chasseur et un Écho](../previews/pyrevorn/pyrevorn_in_game.png),
  capture Godot à 1280 × 720 dans une partie gelée, son coupé.
- Un GIF par animation et captures des techniques dans `docs/previews/pyrevorn/`.
- Les captures attestent le chargement et l’apparence ; le combat reste à raccorder et à tester par Claude.
- Le banc de capture hérite des avertissements de libération à sa fermeture (43 ressources),
  sans erreur de chargement des sprites. Cette limite est distincte du contrôle `assets`.
