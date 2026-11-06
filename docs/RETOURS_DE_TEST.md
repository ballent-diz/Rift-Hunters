# Retours de test du propriétaire

Notés au fil des parties de test. Une case cochée = corrigé et vérifié.

## Session du 3 novembre 2026

- [ ] **Menus pas centrés, fenêtre pas entièrement accessible** : une partie des menus est hors de portée.
- [ ] **Économie trop généreuse au début** : 1 023 Éclats à la fin de la carte 1, et déjà beaucoup de passifs
  accessibles. Revoir les gains de la carte 1 et le coût et l'ordre de déblocage des passifs.
- [x] **Sélection des Échos** : ajouter une brève description du sort actif de chaque Écho. Corrigé le 6 novembre :
  une ligne « sort actif » par Écho de l'équipe, et dans l'infobulle de chaque Écho.
- [x] **Musique** : ne jamais jouer les mêmes morceaux sur deux cartes d'affilée. Corrigé le 6 novembre : une carte
  écarte les morceaux de la précédente (partie et boss), tant qu'il en reste d'autres.
- [x] **Flèche d'objectif** : ses mouvements pendant les déplacements agacent ; la rendre plus fixe. Corrigé le
  6 novembre : elle ne change de cap qu'au-delà d'un écart d'environ 25° et tourne en douceur.
- [x] **Performances** : gros ralentissements quand il y a beaucoup d'ennemis à l'écran. Corrigé le 3 novembre :
  recherche de sortie des ennemis coincés mémorisée, musiques préchargées, rattrapage de simulation plafonné
  (détails : docs/ROADMAP.md, « Performances »). À confirmer sur le PC du propriétaire.
- [x] **Carte 2 (Hautes Terres d'Orage) : faille de droite inaccessible** sous la pression des monstres. Corrigé le
  6 novembre : déplacée du sanctuaire (derrière l'escalier) sur la route dégagée au pied des marches, (1280, -60).
- [x] **Combat contre Astravorn** (corrigé, voir Performances) : chute à environ 10 images par seconde pendant le combat (ralentissement, pas de
  blocage). À mesurer en priorité avec le point des performances.
- [x] **Objectifs en jaune** : les phrases restent à peine une seconde à l'écran, pas le temps de les lire. Corrigé
  le 6 novembre : 3,5 à 9 s selon la longueur, et une annonce ne chasse plus la précédente (file d'attente).
- [ ] **Sorts de boss en cercle de 360°** : impossibles à esquiver.
- [x] **Sorts visés en mode clavier** : les sorts qui se visaient à la souris doivent se lancer sur le Chasseur
  (ex. Singularité doit s'activer sur le personnage, pas à un endroit au hasard de la carte). Corrigé le 6 novembre :
  au clavier seul, Singularité, Cristal, Failles jumelles, Rupture et Appel de meute partent sur le Chasseur,
  le Mur de faille se dresse juste devant lui.
- [x] **Mode test « dev »** : débloquer aussi les compétences « débloquée au niveau 3 » et « niveau 1 du chapitre 2 ».
  Corrigé le 6 novembre : le mode test ouvre les emplacements de sort 3 et 4.
- [ ] **Menus : visuels des cartes 7 à 15** à ajouter.
- [ ] **Carte 17, Col des braseros : équilibrage à reprendre** (détails : docs/ROADMAP.md, carte 17).
- [ ] **Carte 18, Lac gelé des tempêtes : équilibrage à reprendre**, en commençant par l'Avalanche de l'élite Yéti des cimes (détails : docs/ROADMAP.md, carte 18).
