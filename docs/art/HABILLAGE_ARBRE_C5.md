# Habillage de l’arbre du Chasseur — suite C5

Écran fonctionnel après la PR #16, fenêtre de référence **1280 × 720**.
Le tronc, les quatre voies et leurs cinq niveaux sont visibles ensemble. Les nœuds compacts donnent
leur nom complet et leur description dans le panneau de droite et en infobulle.

## Utilisation

- Cliquer un nœud sélectionne son détail sans achat implicite. Apprendre, activer et désactiver utilisent
  exclusivement les fonctions existantes de HunterTree. Les actions restent en bas du panneau ;
  seule sa description défile si nécessaire.
- Cliquer un emplacement de sort y équipe le sort actif sélectionné. Avec un autre type de nœud
  sélectionné, cliquer un emplacement occupé ouvre son sort. Les touches reflètent les réglages du joueur.
- Les trois builds conservent l’équipement existant. Le compteur indique les points utilisés / totaux.
- Le bouton « Améliorations du refuge » remplace le plan par une grille de conforts permanents,
  sans modifier leurs coûts ni leur activation automatique.
- A/B suit les variantes de la conception, indépendamment de l’ordre alphabétique des traductions.
  Les traits fins reproduisent les prérequis des ressources, pas des prérequis supplémentaires.

## États

À venir : cadre assombri et points de suspension ; verrouillé : cadenas ; apprenable : repères clairs et + ;
appris : coche ; actif dans le build : double cadre et point doré. Le rang reste affiché dans le cadre.
Les clés de voûte ont un cadre en losange couronné. Une seule est active selon la règle existante.
Les couleurs distinguent les voies : or, cyan, lilas et jade.

Les cadres C5 réutilisés sont dans assets/ui/hunter_tree/ ; six ressources « upcoming » complètent
le catalogue, désormais référencé en 1280 × 720. Les emplacements ont un contour extensible sans
ornement traversant leur texte. Le manifeste référence chaque ressource graphique réelle.

## Les 24 illustrations livrées

Les **24 prompts complets** sont dans
[assets/concepts/incoming/ui.hunter_tree_icons/PROMPTS.md](../../assets/concepts/incoming/ui.hunter_tree_icons/PROMPTS.md).
Ils suivent docs/ART_BIBLE.md : silhouette lisible en 64 × 64, fond transparent, 24–32 couleurs,
lumière haut-gauche, ombres violettes et accents alliés blancs/cyan.
Le propriétaire a confié leur génération à Codex pendant cette livraison. Les 24 images ont été créées avec
imagegen puis importées avec tools/art/import_sheet.py ; generation.json conserve les prompts exacts et les empreintes des sources.

Les 24 originaux transparents sont conservés dans les dossiers source/. Les 24 icônes et leurs feuilles
64 × 64 sont importées et déclarées finales dans le manifeste. Les nœuds et les emplacements de sorts
utilisent ces illustrations ; seuls les passifs simples et les améliorations du refuge gardent des symboles de catégorie.
Le fichier bindings.json du même dossier associe les 24 identifiants d’illustration aux vrais nœuds C2.
Il prend notamment en compte refracting_crystal / refractor_crystal, aegis / rift_aegis,
blade_slicing_dash / slashing_dash et blade_counter_cut / counter_slash.

Pour remplacer ultérieurement une illustration :

1. Placer le PNG dans assets/concepts/incoming/icon.hunter.<identifiant>/source/icon.png.
2. Exécuter tools/art/import_sheet.py sur le job.json de ce dossier.
3. Réimporter le projet dans Godot puis vérifier la lisibilité à 720p.

L’import existant produit l’icône, sa feuille et l’entrée du manifeste. L’écran utilise
Assets.icon("icon.hunter.<identifiant>") : elle remplace automatiquement le symbole provisoire.
Les variantes A/B réutilisent l’illustration de leur sort ; la lettre les distingue.
Ne pas ajouter de fichiers .import sous incoming/ (dossier exclu de Godot).

## Validation et captures

[Quatre captures de l’écran réel](../previews/c5/tree/README.md) : départ, build avancé,
variante exclusive et améliorations du refuge en anglais. Profil de démonstration isolé,
aucun changement de sauvegarde du joueur.

Les tests de mise en page avec le moteur graphique couvrent les deux langues à 720p, les nœuds et les boutons d’action,
ainsi que l’apprentissage, l’activation, le retrait, l’équipement sur F et le changement de build.
Le mode sans affichage utilise une police factice aux métriques différentes : les assertions de dimensions
sont exécutées avec le moteur graphique ; les assertions de structure et d’actions fonctionnent dans les deux modes.
Commandes finales : tools/run_tests.sh unit, tools/run_tests.sh lint et tools/run_tests.sh assets.
Contrôle géométrique réel : tests/run_tests.tscn -- --filter=hunter_tree_layout, avec affichage à 1280 × 720.
Le test des icônes vérifie les 24 correspondances sort / talent / illustration.

Les fichiers hunter_tree.gd, hunter_spells.gd et hunter_spell_world.gd restent inchangés.

Résultats finaux : **179/179 tests unitaires**, **lint sans problème**, **113 entrées graphiques sans erreur**
(112 valides et un placeholder préexistant, sans rapport avec ce lot). Les **3 contrôles C5 avec affichage**
passent également, dont les cadrages FR/EN à 1280 × 720.
