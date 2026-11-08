# Prompts pour Codex en attente (mis de côté le 3 novembre 2026)

Prompts rédigés par Claude et validés par le propriétaire, à envoyer à Codex après sa réinitialisation. Les envoyer
dans l'ordre ; chacun est autonome. Rappel pour Codex : une branche par tâche depuis `main` à jour, PR vers `main`
(AGENTS.md) ; si l'API GitHub le bloque, pousser la branche et donner son nom et son dernier commit : Claude ouvrira
la PR.

## 2. Échelle des décors : carte 15 (en cours chez Codex ; la partie carte 4 est annulée)

```text
Échelle des décors (docs/ART_BIBLE.md, section « Échelle des décors ») : le Chasseur mesure environ 52 unités de
haut ; une marche fait 12 à 16 unités de profondeur, une dalle au plus 26, une porte 75 à 90 de haut, une colonne 30
à 45 de large.

Carte 15, Cœur des marais (marsh_heart) : escaliers et colonnes 3 à 4 fois trop grands (le Chasseur ne couvre
qu'une marche et demie). Refais une passe de détail des régions concernées (escaliers sud, central et des berges,
colonnes du temple et de la terrasse) avec des marches plus nombreuses et plus fines et des colonnes plus étroites,
SANS changer le plan, les emprises, le cadrage ni ce qui est praticable : les collisions peintes par le propriétaire
et l'intégration en jeu doivent rester valables. Même densité (2,25 px/unité), mêmes tuiles.

Capture au zoom réel avec le Chasseur et Cendrelame posés sur un escalier, un dallage et près d'une colonne, contrôle
qualité habituel (check_map_quality), et superposition avec l'ancien master pour prouver que les bords praticables
n'ont pas bougé. Ne touche ni src/ ni data/.
```

## 4. Barrières de zone peintes, une par chapitre

```text
Barrières de zone : le propriétaire trouve le rideau actuel trop « cheap ». Aujourd'hui c'est un ruban généré par
shader (src/run/rift_wall_visual.gd + assets/shaders/rift_curtain.gdshader, contrat d'origine :
docs/art/BARRIERES_FAILLES_A3.md), sans pixel art, étranger aux décors peints. Remplace-le par des barrières peintes
qui s'intègrent dans les décors, selon docs/ART_BIBLE.md (« Objets posés sur les cartes » et « Échelle des décors » :
Chasseur ≈ 52 unités, lumière haut-gauche, ombre portée, palette prélevée sur les cartes du chapitre, aucun aplat).

Cinq jeux, un par chapitre, dans la matière de ses cartes :
- chapitre 1 (Ruines, Plaine, Gué, Hautes Terres) : pierre grise moussue et runes violettes ;
- chapitre 2 (Terres dévastées) : basalte, braises, fissures de lave ;
- chapitre 3 (Marais engloutis) : bois noyé, racines, eau sombre ;
- chapitre 4 (Glacier) : glace bleutée, givre, pierre gelée ;
- chapitre 5 (Cité de la Faille) : acier pâle, ardoise, dorures ternies, veines magenta.

Chaque jeu contient :
1) Bornes de sceau (2 ou 3 variantes) : piliers ou obélisques ancrés au sol, environ 90 à 110 unités de haut et 30
   à 40 de large, posés aux extrémités et aux angles d'une barrière. États : idle (runes qui pulsent doucement),
   open (les runes s'éteignent, la borne reste au sol).
2) Voile de faille : bande verticale en pixel art, environ 100 unités de haut, raccordable SANS COUTURE en largeur
   (module de 64 ou 128 unités, plus un module d'angle), vue de face et de biais pour les barrières verticales à
   l'écran. Animations : loop (8 images, voile qui ondule, étincelles discrètes), appear (6 images), dissolve
   (8 images, le voile se déchire et se disperse). Assez transparent pour laisser lire le sol derrière, lisible comme
   « infranchissable ».
Feuilles de sprites et job.json selon assets/concepts/incoming/README.md, entrées object.barrier_<chapitre> au
manifeste, palette ≤ 32 couleurs, ancres au pied.

Captures au zoom réel (1,3333) avec le Chasseur et un Écho : une barrière droite, un angle et une barrière verticale
sur une carte de chaque chapitre, plus un GIF appear/loop/dissolve. Guide d'intégration pour Claude dans
docs/art/BARRIERES_PEINTES.md (modules, ancres, raccords, ordre de pose le long d'un rectangle). Ne modifie ni src/
ni data/ ni les collisions : Claude remplace le shader en posant les modules le long des barrières existantes, sans
changer règles ni minuteries.
```

## Déjà réglé (ne plus envoyer)

- Échelle des décors de la carte 4 et proportions des chapitres 4 et 5 : réglé le 8 novembre par la réduction du
  décor par carte (`decor_scale`, docs/maps/ECHELLE_CHAPITRES_4_5.md), sans repeindre. Proportions des cartes 16 à 25
  (ancien prompt 3) : sans objet.
- Objets posés sur les cartes (miroirs-portails, cristaux, mannequin) : livrés par Codex (PR #131, fusionnée le
  8 novembre via #132) ; intégration en jeu à faire par Claude.
- Carte 16 : corrections de la composition, devenues sans objet (carte détaillée et intégrée en jeu).
- PR #90 (objets miroirs) et PR #92 (sprites du chapitre 4) : fusionnées.
- Image de référence des collisions de la carte 15 : le propriétaire a peint les collisions, carte intégrée.
- Rochers-abris en sprite séparé (`object.cover_rock`) : abandonné, les abris se peignent dans les décors.
