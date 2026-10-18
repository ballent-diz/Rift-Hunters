# Icônes des passifs et améliorations du Chasseur — C5-icônes

Complément des 24 illustrations C5 : 18 passifs et 12 améliorations permanentes du refuge.
Chaque nœud dispose de son illustration propre ; les variantes A/B continuent à partager l’image de leur sort.
La table ICON_ALIASES dans HunterTreeSkin est le seul fichier src/ modifié. Aucune règle de progression ne change.

## Direction et sources

Illustrations générées avec imagegen intégré, fond réellement transparent, sans texte ni cadre.
Couleurs du tronc ivoire/argent ; Lame ambre ; Prisme cyan ; Abîme lilas/indigo ; Lien jade.
Les douze améliorations du refuge utilisent une famille d’objets : instruments de cuivre pour la recherche,
équipement de laiton pour l’exploration. Grandes masses lisibles à 48 px, détails conservés en haute définition.
Les originaux ne sont pas réduits à une palette de sprites de gameplay.

Les prompts complets et le sens de chaque capacité sont conservés dans
assets/concepts/incoming/ui.hunter_passive_icons/PROMPTS.md et prompts.json.
Chaque original et son prompt se trouvent dans assets/concepts/incoming/icon.hunter.<id>/source/.
generation.json conserve le prompt exact et l’empreinte SHA-256 de chaque image effectivement importée.
Aucune ressource tierce n’est utilisée.

## Import et raccordement

tools/art/prepare_missing_hunter_icons.py prépare les recettes, à partir des noms et descriptions réels.
tools/art/import_missing_hunter_icons.py utilise import_sheet.py, contrôle l’alpha et exporte la planche 112/48.
L’option --final s’utilise après inspection des trente illustrations.

Les icônes sont des PNG 512 × 512 dans assets/ui/icons/skills/hunter_<id>.png ; feuilles dans
assets/sprites/skills/hunter/. Les entrées icon.hunter.<id> du manifeste pointent vers ces ressources.
Les recettes reprennent la cellule 512, ancre centrale, hauteur 448, réduction Lanczos, alpha conservé,
sans réduction de palette ni ajout de contour. Les fichiers .import des icônes et feuilles activent les mipmaps.
incoming/ reste exclu de Godot : aucun .import n’y est ajouté.

## Contrôle

tests/unit/test_hunter_node_icons.gd vérifie que les 78 nœuds résolvent une vraie texture importée de 512 px,
y compris les variantes et les douze améliorations. Il conserve le contrôle antérieur des 24 illustrations.
tools/art/missing_hunter_icons_preview.tscn capture les quatre voies et les améliorations en 1280 × 720,
sur un profil de présentation isolé en lecture seule, sans sauvegarde du propriétaire.

La planche et les captures sont dans docs/previews/c5-icones-chasseur/.

## Résultats du 18 octobre

Import Godot 4.3 puis tools/run_tests.sh complet : 231 tests réussis (dont couverture des 78 nœuds),
232 scripts, persistance, 279 ressources sans erreur, pipeline d’import, partie automatique et lint verts.
Les trente sources ont un canal alpha contrôlé ; soixante fichiers d’import (icônes et feuilles) activent
les mipmaps. Aucun .import ajouté aux trente nouveaux dossiers incoming/.
Les cinq captures réelles sont en 1280 × 720. Seule l’image de Fil aiguisé a demandé un recadrage ;
l’original avant recadrage et le prompt corrigé sont conservés avec la source définitive.

Compatibilité : la branche réunit également la PR #32, afin que les ajouts au manifeste et à la feuille
de route ne se retrouvent pas en conflit après sa fusion. Le contrôle complet après réunion des deux lots
est vert : 231 tests et 311 ressources sans erreur, persistance, import graphique, partie automatique et lint.
Fusion conseillée : PR #32, puis PR des icônes. Le diff des icônes se réduira automatiquement après la première.
