# Retours de test du propriétaire

Notés au fil des parties de test. Une case cochée = corrigé et vérifié.

## Session du 3 novembre 2026

- [x] **Menus pas centrés, fenêtre pas entièrement accessible** : une partie des menus est hors de portée. Corrigé le
  6 novembre : la fenêtre (1600 × 900) est réduite à 90 % de l'écran utilisable au besoin et centrée au lancement ;
  l'écran titre n'a plus de bandes noires (fond recadré) ; le refuge reste centré sur écran ultra-large. À confirmer
  sur le PC du propriétaire.
- [x] **Économie trop généreuse au début** : 1 023 Éclats à la fin de la carte 1. Corrigé le 6 novembre : 960 → 441
  Éclats pour une première victoire sur la carte 1 (profil neuf, mesuré par `autoplay --profile=stage`) ; paliers III
  après 2 victoires, IV et V après 4.
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
- [x] **Sorts de boss en cercle de 360°** : impossibles à esquiver. Corrigé le 6 novembre : tout anneau de boss garde
  une brèche du côté du Chasseur (et une à l'opposé), les couloirs sûrs sont dessinés en vert dès l'annonce avec
  l'anneau à venir ; animations pixelfx aux couleurs de la famille du boss (charge, onde de choc, poussière du front).
- [x] **Sorts visés en mode clavier** : les sorts qui se visaient à la souris doivent se lancer sur le Chasseur
  (ex. Singularité doit s'activer sur le personnage, pas à un endroit au hasard de la carte). Corrigé le 6 novembre :
  au clavier seul, Singularité, Cristal, Failles jumelles, Rupture et Appel de meute partent sur le Chasseur,
  le Mur de faille se dresse juste devant lui.
- [x] **Mode test « dev »** : débloquer aussi les compétences « débloquée au niveau 3 » et « niveau 1 du chapitre 2 ».
  Corrigé le 6 novembre : le mode test ouvre les emplacements de sort 3 et 4.
- [x] **Menus : visuels des cartes 7 à 15** à ajouter. Corrigé le 6 novembre : vignettes des cartes 7 à 18 tirées
  de leurs décors (`tools/art/build_expedition_previews.gd`).
- [ ] **Carte 17, Col des braseros : équilibrage à reprendre** (détails : docs/ROADMAP.md, carte 17).
- [ ] **Carte 18, Lac gelé des tempêtes : équilibrage à reprendre**, en commençant par l'Avalanche de l'élite Yéti des cimes (détails : docs/ROADMAP.md, carte 18).
- [x] **Proportions des cartes des chapitres 4 et 5** (8 novembre) : sur beaucoup de cartes des deux derniers chapitres,
  les personnages paraissent beaucoup trop petits par rapport au décor (marches, dalles, colonnes, bâtiments trop
  grands). Corrigé le 8 novembre : décor réduit par carte (`decor_scale` d'ArenaData) sans toucher aux personnages ;
  mesures et facteurs dans docs/maps/ECHELLE_CHAPITRES_4_5.md (cartes 4, 16 et 18 réduites ; 17 déjà à
  l'échelle ; 15 repeinte par Codex ; facteurs des cartes 19 à 25 notés pour leur intégration).

## Session du 9 novembre 2026

- [x] **Arbre de compétences trop petit** (« c'est mieux mais trop petit, ça fait comprimé pour rien ») : corrigé le
  9 novembre : bouton « Agrandir » (touche F) qui ouvre l'arbre du Chasseur sur toute la fenêtre, nœuds, icônes et
  textes plus grands, fiche du nœud sur le côté ; Échap pour revenir. Les arbres des Échos n'étaient pas comprimés.
- [x] **Sorts et passifs à distinguer** : corrigé le 9 novembre : sorts en hexagone doré à liseré, passifs en cercle
  sobre, dans l'arbre, la fiche, les infobulles et la légende (Chasseur et Échos).
- [x] **Échos immenses par rapport au Chasseur** : corrigé le 9 novembre : six Échos ramenés à environ 1,3 fois la
  taille apparente du Chasseur par leur seule échelle visuelle (docs/art/TAILLE_DES_ECHOS.md).
- [ ] **Trop de monde et trop de sorts avec trois Échos** : « ça fait un peu bordel avec les 3 Échos autour de nous,
  et beaucoup de sorts à gérer » ; envie d'essayer sans Échos ou un autre gameplay. Deux prototypes livrés le
  10 novembre, activables par le réglage « Mode des Échos » (Actuel / Relais / Solo, détails dans docs/ROADMAP.md,
  « Modes des Échos à l'essai »). **À tester par le propriétaire**, qui choisit ensuite le mode à garder.
- [ ] **Échos et monstres « en lévitation »** (10 novembre) : ils semblent flotter au-dessus du sol, surtout à cause du
  cercle d'ombre sous chaque sprite. À ancrer au sol : ombre portée plus discrète et collée aux pieds (forme et
  opacité selon la silhouette, lumière haut-gauche de docs/ART_BIBLE.md), ancres des feuilles vérifiées, flottement
  réservé aux créatures volantes.
  Précision du propriétaire : le Chasseur a aussi le cercle mais paraît bien posé au sol. La cause principale est donc
  probablement la position des pieds dans les feuilles des Échos et monstres (ancre trop basse, pieds au-dessus du
  centre de l'ombre) : comparer leurs ancres à celle du Chasseur avant de toucher aux ombres.
- [x] **Monstres du chapitre 5 minuscules** (10 novembre) : Déchus (cellules 64 px, 16 à 24 unités) et Enfants de la
  Faille trop petits face au Chasseur (≈ 52 unités) ; revoir leur échelle (manifeste) selon docs/ART_BIBLE.md.
  Corrigé le 11 novembre pour les sept Déchus (26 à 47 unités, visuel seulement). Les Enfants de la Faille et la
  Statue mesurent déjà 45 à 110 unités : inchangés, **à confirmer en jouant** (docs/ROADMAP.md, lot 3).
- [ ] **Boss de fin de chapitre pas assez dynamiques** (10 novembre) : plus de déplacements, d'enchaînements et de
  techniques lisibles ; à revoir boss par boss.
- [x] **Glauquemire (carte 15, Cœur des marais)** (10 novembre) : boss intuable, mécanique jugée mauvaise par le
  propriétaire, et un « cercle » bloque le Chasseur dans l'arène. Refondre la mécanique et retirer le blocage.
  Corrigé le 11 novembre : soin des sangsues plafonné, plus de laisse ni d'anneau (racine jaillissante, raz-de-marée à
  traverser), miroirs sans Ruée, finale sur toute la terrasse fermée par des barrières (plus d'ellipse), boss
  recalibré (bot : 2 sur 4 au lieu de 0 sur 4). **À juger en jouant** (docs/design/DEVOREUR_CHAPITRE3.md).
- [x] **Carte 15 buguée** (10 novembre) : contrôlée le 11 novembre au bot et par superposition des collisions.
  Corrigé : moitié droite de l'escalier central bloquée par une collision invisible ; chaussées de marée décalées
  d'environ 115 unités par rapport aux ponts peints ; ellipse de finale au milieu de la terrasse. Reste à repeindre
  (prompt Codex en attente) : un morceau de rambarde en double sur le pont nord-ouest.
