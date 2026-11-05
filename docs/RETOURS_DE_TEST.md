# Retours de test du propriétaire

Notés au fil des parties de test. Une case cochée = corrigé et vérifié.

## Session du 3 novembre 2026

- [ ] **Menus pas centrés, fenêtre pas entièrement accessible** : une partie des menus est hors de portée.
- [ ] **Économie trop généreuse au début** : 1 023 Éclats à la fin de la carte 1, et déjà beaucoup de passifs
  accessibles. Revoir les gains de la carte 1 et le coût et l'ordre de déblocage des passifs.
- [ ] **Sélection des Échos** : ajouter une brève description du sort actif de chaque Écho.
- [ ] **Musique** : ne jamais jouer les mêmes morceaux sur deux cartes d'affilée.
- [ ] **Flèche d'objectif** : ses mouvements pendant les déplacements agacent ; la rendre plus fixe.
- [x] **Performances** : gros ralentissements quand il y a beaucoup d'ennemis à l'écran. Corrigé le 3 novembre :
  recherche de sortie des ennemis coincés mémorisée, musiques préchargées, rattrapage de simulation plafonné
  (détails : docs/ROADMAP.md, « Performances »). À confirmer sur le PC du propriétaire.
- [ ] **Carte 2 (Hautes Terres d'Orage) : faille de droite inaccessible** sous la pression des monstres. Déplacer
  cette faille (`rift_points`, actuellement (1710, -225)) vers un endroit plus accessible.
- [x] **Combat contre Astravorn** (corrigé, voir Performances) : chute à environ 10 images par seconde pendant le combat (ralentissement, pas de
  blocage). À mesurer en priorité avec le point des performances.
- [ ] **Objectifs en jaune** : les phrases restent à peine une seconde à l'écran, pas le temps de les lire.
- [ ] **Sorts de boss en cercle de 360°** : impossibles à esquiver.
- [ ] **Sorts visés en mode clavier** : les sorts qui se visaient à la souris doivent se lancer sur le Chasseur
  (ex. Singularité doit s'activer sur le personnage, pas à un endroit au hasard de la carte).
- [ ] **Mode test « dev »** : débloquer aussi les compétences « débloquée au niveau 3 » et « niveau 1 du chapitre 2 ».
- [ ] **Menus : visuels des cartes 7 à 15** à ajouter.
- [ ] **Carte 17, Col des braseros : équilibrage à reprendre** (détails : docs/ROADMAP.md, carte 17).
