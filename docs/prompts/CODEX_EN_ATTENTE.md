# Prompts pour Codex en attente (mis de côté le 3 novembre 2026)

Prompts rédigés par Claude et validés par le propriétaire, à envoyer à Codex après sa réinitialisation. Les envoyer
dans l'ordre ; chacun est autonome. Rappel pour Codex : une branche par tâche depuis `main` à jour, PR vers `main`
(AGENTS.md) ; si l'API GitHub le bloque, pousser la branche et donner son nom et son dernier commit : Claude ouvrira
la PR.

## 1. Carte 16 : corrections de la composition (avant le détail graphique)

```text
Carte 16 (chapitre 4, Glacier silencieux, docs/design/CARTES.md : vagues par zone, B1 glace qui fait glisser) : le
propriétaire valide le plan de ta composition (trois plateaux reliés par des cols étroits, plaques de glace lisses
bien lisibles, blocs de glace dans les aires de combat) et la lisibilité des monstres sur la neige. Garde ce plan et
applique ces corrections avant le détail graphique :

1) Abris : les blocs de glace doivent pouvoir abriter le Chasseur des attaques de boss : 110 à 160 unités de large,
   3 à 4 par plateau dans les aires de combat (pas collés aux bords), 4 à 5 sur le plateau de la finale, lisibles
   comme des obstacles pleins (ombre portée, faces éclairées en haut à gauche).
2) Parcours explicite : indique dans plan.json (repères en %) le point de départ, l'ordre des plateaux, le plateau de
   la finale et son emprise utile. Le champ de neige en bas à droite doit être soit relié clairement au parcours,
   soit fermé (falaise ou crevasse).
3) Échelle : respecte la nouvelle règle de docs/ART_BIBLE.md (section « Échelle des décors » : Chasseur environ 52
   unités ; marche 12 à 16, dalle au plus 26, colonne 30 à 45 de large) et valide sur une capture au zoom réel avec
   le Chasseur et un Écho.

ATTENTION : le propriétaire a déjà peint les collisions sur la version actuelle de la composition (blocs de glace
compris). Ne change ni le cadrage ni les contours praticables ; si une correction les modifie, signale-le pour qu'il
repeigne. Ensuite : plan.json, détail graphique, image de référence des collisions comme pour les cartes 14 et 15.
Ne touche ni src/ ni data/.
```

## 2. Objets posés sur les cartes : sprites peints dans la direction artistique de chaque carte

```text
Objets de gameplay posés sur les cartes : le propriétaire constate qu'ils ne se fondent pas dans la direction
artistique des cartes, en particulier les miroirs-portails de la carte 14 (scène vectorielle mirror_portal.tscn :
aplats, rendu étranger au décor peint). Règle (docs/ART_BIBLE.md, section « Objets posés sur les cartes ») : tout
objet ajouté à une carte est un sprite peint de la même facture que le décor de SA carte (palette prélevée sur la
carte, même finesse, lumière haut-gauche, ombre portée, aucun aplat ni couleur saturée ; repères de jeu discrets).

1) Miroirs-portails, carte 14 (Puits des reflets) : feuille de sprites peinte (job.json,
   assets/concepts/incoming/README.md), dans la matière du décor : pierre grise moussue, vitre d'eau sombre, reflets
   pâles. Quatre paires distinguées seulement par une lueur discrète dans les teintes de la carte (sarcelle, sauge,
   or pâle, gris lilas : ce sont les teintes déjà utilisées par le jeu). Animations : active (vitre qui ondule),
   cooldown (vitre éteinte), enter, exit (courts, sans grand halo). Pied ancré au sol, environ 100 unités de haut.
2) Cristaux-miroirs, cartes 13 (Jardins de cristal) et 15 (terrasse du Cœur des marais) : même traitement, dans la
   matière de ces décors. États : idle, charged, burst, hidden.
3) Mannequin de la salle d'entraînement (object.training_dummy) : peint, bois et fer du refuge ; idle et hit.
4) Abris : à peindre directement dans les décors des prochaines cartes (pas d'objet séparé).

Garde les mêmes états et les mêmes noms que les scènes actuelles : Claude rebranche les visuels sans toucher aux
règles. Capture au zoom réel de chaque objet posé dans sa carte. Ne modifie ni src/ ni data/.
```

## 3. Échelle des décors : cartes 15 et 4

```text
Échelle des décors (docs/ART_BIBLE.md, section « Échelle des décors ») : le Chasseur mesure environ 52 unités de
haut ; une marche fait 12 à 16 unités de profondeur, une dalle au plus 26, une porte 75 à 90 de haut, une colonne 30
à 45 de large. Deux cartes s'en écartent nettement :

1) Carte 15, Cœur des marais (marsh_heart), priorité : escaliers et colonnes 3 à 4 fois trop grands (le Chasseur ne
   couvre qu'une marche et demie). Refais une passe de détail des régions concernées (escaliers sud, central et des
   berges, colonnes du temple et de la terrasse) avec des marches plus nombreuses et plus fines et des colonnes plus
   étroites, SANS changer le plan, les emprises, le cadrage ni ce qui est praticable : les collisions peintes par le
   propriétaire et l'intégration en jeu doivent rester valables. Même densité (2,25 px/unité), mêmes tuiles.
2) Carte 4, Gué des Brumes (mist_ford) : dalles environ 2 fois trop grandes ; affine le dallage de la même façon.

Pour chaque carte : capture au zoom réel avec le Chasseur et Cendrelame posés sur un escalier, un dallage et près
d'une colonne, contrôle qualité habituel (check_map_quality), et superposition avec l'ancien master pour prouver que
les bords praticables n'ont pas bougé. Ne touche ni src/ ni data/.
```

## Déjà réglé (ne plus envoyer)

- PR #90 (objets miroirs) et PR #92 (sprites du chapitre 4) : fusionnées.
- Image de référence des collisions de la carte 15 : le propriétaire a peint les collisions, carte intégrée.
- Rochers-abris en sprite séparé (`object.cover_rock`) : abandonné, les abris se peignent dans les décors.
