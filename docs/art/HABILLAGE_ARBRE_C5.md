# Habillage de l’arbre du Chasseur — suite C5

Écran fonctionnel après la PR #16, fenêtre de référence **1280 × 720**.
Révision du 17 octobre : vue détaillée par voie avec cadres de 80 px et aperçu de 144 px,
pour rendre les illustrations lisibles. Les cinq niveaux défilent dans la zone de l’arbre ;
les builds, équipements et actions restent fixes. Le bouton « Vue d’ensemble » conserve le plan
compact du tronc et des quatre voies. Les noms complets sont visibles sous les nœuds agrandis.

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
Les prompts historiques suivent la Bible graphique. Retour du propriétaire du 17 octobre :
la réduction à 64 × 64 et 32 couleurs rendait les images illisibles. Pour ces illustrations d’interface,
les originaux sont désormais conservés en 512 × 512, sans limitation de palette ni contour ajouté,
avec transparence et réduction Lanczos. Les sprites de gameplay gardent leurs recettes existantes.
Le propriétaire a confié leur génération à Codex pendant cette livraison. Les 24 images ont été créées avec
imagegen puis importées avec tools/art/import_sheet.py ; generation.json conserve les prompts exacts et les empreintes des sources.

Les 24 originaux transparents sont conservés dans les dossiers source/. Les 24 icônes et leurs feuilles
512 × 512 sont importées et déclarées finales dans le manifeste. Les nœuds et les emplacements de sorts
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

Résultats de la livraison initiale : **179/179 tests unitaires**, **lint sans problème**, **113 entrées graphiques sans erreur**
(112 valides et un placeholder préexistant, sans rapport avec ce lot). Les **3 contrôles C5 avec affichage**
passent également, dont les cadrages FR/EN à 1280 × 720.

## Correction du 17 octobre

Conflit avec main résolu par conservation des deux ensembles de traductions.
Le nouveau mode test ajouté sur main est conservé. Aucune régénération IA des 24 images :
réimport des originaux avec les options resample=lanczos, preserve_alpha=true, colors=0,
outline=false, icon_size=512. Les options restent facultatives : les autres recettes ne changent pas.
La largeur des images est ajustée à la cellule pour garder les silhouettes entières.
Les tests vérifient aussi les dimensions HD et l’accès aux clés de voûte de chaque voie par défilement.

Validation de la correction : 182/182 tests unitaires, lint sans problème, 113 entrées du manifeste
sans erreur, pipeline Python existant validé, 4/4 contrôles C5 avec affichage réel à 720p.
