# Habillage du menu principal

`refuge.png` vient du visuel `accueil.png` fourni par le propriétaire du projet.
Les quatre libellés et la version ont été retirés avec imagegen pour être affichés
par Godot : les traductions FR/EN et les actions des boutons restent actives.
Le logo, les icônes, les cadres et le décor font partie de la texture.

Le menu utilise les coordonnées du visuel de référence (1752 × 897), avec une
transformation commune au décor et aux boutons. L'image entière reste visible,
avec des bandes sombres selon le format de la fenêtre. Le filtre est nearest.
Les survols, pressions et focus clavier sont des styles locaux au menu.

Le bouton Paramètres conserve l'action de changement de langue de la branche
source ; son infobulle indique la langue courante. Aucun écran de paramètres
nouveau n'est ajouté. Les crédits, l'entrée au Refuge et Quitter conservent leurs
callbacks. Les alertes de sauvegarde sont affichées sur un panneau lisible.

Aperçu réel Godot : `docs/previews/main-menu.png`.
Captures : `godot --path . --resolution 1600x900 res://tools/screenshot.tscn -- --menu=main --locale=fr --out=<dossier>`.
Tests dédiés : `godot --headless --path . res://tests/run_tests.tscn -- --filter=main_menu`.
