# Prompts pour Codex en attente (mis de côté le 3 novembre 2026)

Prompts rédigés par Claude et validés par le propriétaire, à envoyer à Codex après sa réinitialisation. Les envoyer
dans l'ordre ; chacun est autonome. Rappel pour Codex : une branche par tâche depuis `main` à jour, PR vers `main`
(AGENTS.md) ; si l'API GitHub le bloque, pousser la branche et donner son nom et son dernier commit : Claude ouvrira
la PR.

## 1. Objets posés sur les cartes : sprites peints dans la direction artistique de chaque carte

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

## 2. Échelle des décors : cartes 15 et 4

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

## 3. Proportions des cartes des chapitres 4 et 5 (cartes 16 à 25)

```text
Proportions des décors, chapitres 4 et 5 : le propriétaire constate en jeu que, sur beaucoup de cartes des deux
derniers chapitres, les personnages paraissent beaucoup trop petits : marches, dalles, colonnes, portes, bâtiments,
statues et rochers sont peints à une échelle trop grande. Référence (docs/ART_BIBLE.md, « Échelle des décors ») :
le Chasseur mesure environ 52 unités ; marche 12 à 16 unités de profondeur, dalle 15 à 26, porte 75 à 90 de haut,
colonne 30 à 45 de large, arbre 120 à 200 ; carte étalon : les Ruines des Cascades (cascade_ruins).

Cartes : glacier_entry (16), brazier_pass (17), storm_lake (18), lighthouse_floe (19), silent_heart (20),
shattered_outskirts (21), rune_sanctum (22), suspended_quarters (23), shattered_pantheon (24), rift_eye (25).

1) Audit d'abord, sans rien repeindre : pour chaque carte, mesure sur le master les éléments repères (marches,
   dalles, portes, colonnes, fenêtres, statues, rochers, troncs) en unités du monde, compare à la bible et classe
   la carte : conforme / à affiner / à reprendre. Planche par carte : capture au zoom réel (1,3333) avec le Chasseur
   et Cendrelame posés sur un escalier, un dallage et près d'une porte ou d'une colonne, à côté de la même capture
   sur les Ruines. Tableau récapitulatif dans docs/maps/ECHELLE_CHAPITRES_4_5.md. Livre l'audit en PR séparée et
   attends la validation du propriétaire avant l'étape 2.
2) Correction, carte par carte, dans l'ordre de priorité validé : passe de détail locale par régions
   (tools/art/map_regions.py) avec marches plus nombreuses et plus fines, dalles plus petites, colonnes et portes
   plus étroites, ornements à l'échelle. SANS changer le plan, les emprises, le cadrage ni ce qui est praticable :
   les collisions peintes par le propriétaire (cartes 16 à 24) et l'intégration en jeu (cartes 16 à 18) doivent
   rester valables. Même densité (2,25 px/unité), mêmes tuiles, mêmes dimensions.

Pour chaque carte corrigée : check_map_quality conforme, superposition avec l'ancien master prouvant que les bords
praticables n'ont pas bougé, captures avant/après au zoom réel. Une PR par carte (ou par paire de petites
retouches), poids indiqué. Ne touche ni src/ ni data/ ni les collisions.
```

## Déjà réglé (ne plus envoyer)

- Carte 16 : corrections de la composition, devenues sans objet (carte détaillée et intégrée en jeu).
- PR #90 (objets miroirs) et PR #92 (sprites du chapitre 4) : fusionnées.
- Image de référence des collisions de la carte 15 : le propriétaire a peint les collisions, carte intégrée.
- Rochers-abris en sprite séparé (`object.cover_rock`) : abandonné, les abris se peignent dans les décors.
