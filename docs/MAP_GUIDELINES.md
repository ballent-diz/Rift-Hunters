# Consignes pour les prochaines cartes

Critères demandés par le propriétaire le 13 octobre 2026. Ils priment sur les anciennes recettes de maps lorsqu’elles donnent un rendu flou, grossièrement pixelisé ou trop encombré.

## Espace de jeu

- Prévoir de grandes surfaces ouvertes pour combattre, tourner autour des ennemis et se dégager : clairières, plaines, places, cours de ruines et plateaux. Ne pas limiter le jeu à des routes étroites.
- Créer des carrefours larges et plusieurs itinéraires de fuite. Éviter les goulets qui bloquent immédiatement le personnage ou son équipe.
- Vérifier la praticabilité avec le personnage, les Échos et la navigation des ennemis. Une belle image ne suffit pas.

## Collisions

- Aucune collision au milieu des routes, sur les tabliers des ponts ou dans les zones explicitement destinées à la circulation.
- Les petits cailloux et détails décoratifs sur les chemins sont traversables ou retirés de l’image.
- Garder les obstacles utiles sur les bords ou dans des massifs clairement séparés : falaises, eau profonde, bâtiments et grands éléments du terrain.
- Tester les virages et la largeur des passages, et pas seulement l’existence d’un trajet entre deux points.

## Paysages et raccords

- Varier les paysages et les éléments de décor ; ne pas remplir la carte uniquement d’arbres.
- Mélanger ruines, bâtiments, temples, cascades, rivières, falaises, carrières, villages, marais et zones corrompues selon le thème.
- Une grande carte doit paraître dessinée d’un seul tenant. Aucun raccord rectangulaire visible, coupure de texture ou rupture de perspective.
- Les chemins, ponts, rives, terrasses et niveaux du terrain doivent se rejoindre naturellement et précisément.
- Vérifier les supports physiques des ponts et bâtiments : aucun morceau de bois, rail, pilier ou débris qui flotte sans raison. Un pont détruit doit présenter des extrémités ancrées aux berges et un vide clairement infranchissable.
- Conserver le niveau de détail des premières maps de référence. Refuser les textures simplifiées, les formes plastiques ou les détails lissés par des retouches successives.
- Pour les très grandes cartes, utiliser des régions cohérentes et un chargement adapté, avec contrôle des transitions et du coût mémoire.

## Netteté et échelle

- Le rendu attendu à l’écran est parfaitement net : ni flou, ni gros pixels provoqués par un agrandissement insuffisant.
- Prévoir une résolution source et un upscale adaptés aux résolutions de jeu visées ; contrôler le résultat à la caméra réelle.
- Ne pas confondre augmentation du nombre de pixels et augmentation des détails. Inspecter les textures après upscale et éviter les halos.
- Les portes, escaliers, ponts, bâtiments, rochers et arbres doivent être proportionnés au personnage. Contrôler l’échelle en situation, avec personnage et Échos visibles.
- La direction artistique reste celle de Rift Hunters ; ces critères de netteté et de lisibilité priment sur un filtrage qui produirait de gros pixels visibles.

## Validation et captures

- Envoyer des captures à chaque étape significative : composition, raccords, collisions et espaces de circulation, puis rendu final en jeu.
- Vérifier plusieurs résolutions, les mouvements réels et le comportement de la caméra.
- Respecter AGENTS.md : effort annoncé et approuvé, branche depuis main à jour, textes FR/EN, tests tools/run_tests.sh verts et PR vers main.

## Précisions du 14 octobre 2026

- La Plaine originale (environment.fractured_plain_map) est la référence de qualité, à comparer au même zoom en jeu. Un upscale qui lisse la pierre et le feuillage ne satisfait pas ce critère.
- Élargir les routes ne suffit pas : créer de grandes surfaces de jeu libres, ouvertes dans plusieurs directions, avec les obstacles regroupés aux bordures.
- Éviter que la diversité du paysage réduise les zones de combat : carrière, lac et ruines doivent laisser des plaines et places largement praticables.
- Valider d’abord une carte fonctionnelle avec Chasseur, Échos et ennemis : mouvements, virages, retraite et plusieurs trajets par secteur. Conserver ensuite sa recette validée comme base des prochaines cartes.
- Pour les Cascades, le propriétaire signale de nombreux passages bloqués : reprendre les surfaces, les raccords et les collisions avant toute déclaration de fin. Le pont cassé reste la seule coupure volontaire sur son passage ; son détour doit être clair et large.
