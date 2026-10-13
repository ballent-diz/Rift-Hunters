# Menus du Refuge et de la partie

`refuge-backdrop.png` est une déclinaison du visuel d'accueil fourni par le
propriétaire : seuls le logo et les boutons ont été retirés avec imagegen.
Les menus utilisent `MenuSkin`, un thème indépendant du thème partagé du HUD.
Les couleurs des états, raretés et branches sont conservées.

`EchoPortrait` utilise `EntityVisual`, le manifeste d'assets et les palettes
sélectionnées en partie. Aucun Écho n'a été redessiné. Les évolutions sans sprite
dédié suivent le remplacement utilisé par les alliés. Les Échos inconnus du
Bestiaire et les cartes verrouillées ne montrent pas de portrait.

Les panneaux de pause, coffre, amélioration et résultat se dimensionnent selon
leur contenu et offrent le défilement si la fenêtre ne peut pas tout afficher.
Les signaux, effets, achats, sauvegardes et règles du jeu ne changent pas.

Captures dans Godot avec `tools/screenshot.tscn` :

- `--menu=refuge --tab=0` à `--tab=6` : Expédition, arbre, Bestiaire, laboratoire,
  objectifs, statistiques, options.
- `--menu=pause|levelup|chest|results|credits` : les autres panneaux.
- Ajouter `--locale=fr|en --out=<dossier>` et `--resolution 1600x900` avant la scène.

Les captures en partie utilisent une session sans sauvegarde de progression.
Exemples réels : `docs/previews/bestiary.png` et `docs/previews/pause.png`.

Validation : 151 scripts sans erreur ; 122/123 tests dans la dernière suite
complète, avec seul le budget de performance dépassé (11,62 ms, budget 10 ms).
Le même test est également exécuté isolément, pour mesurer l'effet de la charge
de la machine. Les quatre tests de `test_menu_skin.gd` passent : sept onglets et
absence de débordement, masquage des inconnus, sprites/palettes identiques à la
partie, thème indépendant et actions Pause/Résultats.
