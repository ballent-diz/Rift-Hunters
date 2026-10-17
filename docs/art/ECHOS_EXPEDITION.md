# Illustrations des Échos et habillage d’Expédition

Lot C5 / B2, 17 octobre 2026. Branche : codex/echos-expedition.

## Livrables

35 illustrations originales générées avec l’outil imagegen intégré : Cendrelame, Lucivelle,
Gueule-d’ombre, Mirelle, Mousseroc, Ronceline et Fulgurine. Cinq rôles par Écho : Puissance,
Concentration, Technique d’origine, second sort et Signature. Les sujets suivent les données
et docs/design/ARBRES_DES_ECHOS.md. Les couleurs distinguent les sept familles ; aucun texte dans les images.

Les originaux sont conservés dans assets/concepts/incoming/icon.echo.<nœud>/source/icon.png.
Les 35 prompts exacts sont dans assets/concepts/incoming/ui.echo_tree_icons/prompts.json ;
generation.json conserve les correspondances et empreintes SHA-256. Images générées pour ce projet,
sans recours à une banque d’images ni reprise d’éléments graphiques d’autres jeux.

Import : tools/art/import_sheet.py avec la recette job.json de chaque dossier.
Sorties PNG 512 × 512 dans assets/ui/icons/skills/echo_<nœud>.png ; feuilles correspondantes dans
assets/sprites/skills/echo/. Transparence conservée, réduction Lanczos, aucune limitation de palette
ni contour ajouté. Les fichiers .import des icônes activent mipmaps/generate=true.
Clés du manifeste : icon.echo.<identifiant du nœud>.

EchoTreeBoard.node_icon() lit l’entrée du manifeste ; le nœud conserve son symbole de repli.
La fiche utilise la même icône. Aucun changement dans EchoTree, les données de gameplay,
les composants graphiques du Chasseur ou SkillCard.

## Expédition

La disposition à deux colonnes est conservée : Écho de départ, chapitres et Survie à gauche,
résumé et départ fixe à droite. Chaque tuile de carte reçoit une vignette ; le résumé reprend
le même décor. Les chapitres ont un bandeau teinté avec ChapterData.color. Titres Cinzel,
texte Inter, textes traduits existants uniquement ; les étoiles dessinées sont conservées.

Les vignettes 768 × 256 sont des recadrages des décors jouables existants, et non de nouvelles cartes.
Elles sont enregistrées sous assets/ui/expedition/ ; la clé menu_preview des entrées environment.*
du manifeste est leur source de vérité. Le générateur tools/art/build_expedition_previews.gd
permet de les reconstruire après une évolution des décors. Les cartes, collisions et chemins ne changent pas.
Les crédits des cartes sources restent applicables ; aucune nouvelle source tierce n’a été ajoutée.

## Validation

Captures du refuge réel dans docs/previews/echo-expedition/ : deux Échos différents,
Expédition avec un profil neuf, mode test, et complément anglais. Les profils sont créés en mémoire
avec Profile.read_only=true ; les captures ne modifient pas la sauvegarde du joueur.

Reproduction : scène tools/art/echo_expedition_preview.tscn, fenêtre 1280 × 720.
Avant la PR : import Godot, tools/run_tests.sh complet, puis contrôles des menus avec le moteur graphique.
Les tests couvrent aussi les 35 correspondances nœud / image HD / mipmaps et le départ FR/EN sur les deux profils.

Résultats : tools/run_tests.sh complet terminé avec code 0 ; 214 scripts vérifiés, 207/207 tests unitaires,
persistance, manifeste (148 entrées, zéro erreur), smoke et lint réussis. Pipeline Python d’import validé
séparément avec le Python disponible dans cet environnement. Contrôles graphiques réels : 4/4 menus du refuge
et 5/5 arbre du Chasseur. Godot émet des avertissements de ressources à la fermeture des contrôles graphiques,
sans échec des assertions.
