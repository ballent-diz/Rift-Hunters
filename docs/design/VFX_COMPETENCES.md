# Compétences et effets visuels par famille (lot 1 : audit et attribution)

Mise à jour du 12 novembre 2026 : [raccordements des sorts et compléments PixelFX](../art/PIXELFX_SORTS_MANQUANTS.md),
avec les Échos, les boss et les familles du chapitre 5. L’audit initial ci-dessous décrit le lot du 6 novembre.

Statut : **validé par le propriétaire le 6 novembre 2026** (règle des éléments, attributions ; effets peints du
chapitre 3 conservés, armure qui se fend du Gardien d'écorce et impacts de tir retenus). **Lots 2 et 3 livrés** :
tous les chapitres et leurs boss (`assets/vfx/pixelfx/techniques.json`, `PixelFx.technique/impact/shot/state`) ;
armure qui se fend du Gardien d'écorce codée (3 s, dégâts subis × 1,5) ; effets longs allégés (une image sur deux).
Demande : chaque famille de Corrompus, ses élites et ses boss ont leurs compétences ; il faut coder celles qui
manquent et donner à chaque compétence une animation pixelfx (MIT, `tools/art/build_pixelfx.py`) **raccord avec la
famille** : un monstre de feu ne lance pas une attaque d'eau.

## 1. Audit

- **63 Corrompus** (8 familles) et **19 boss**. Les **33 techniques** déclarées dans `data/enemies/*.tres` sont toutes
  codées (`EnemyManager`, `MarshTechniques`, `FrostTechniques`), ainsi que les motifs des 19 boss.
- Règle validée le 22 octobre (`MONSTRES.md`) : les normaux restent simples (déplacement + attaque), quelques-uns ont
  une technique ; élites et boss ont les leurs. Le chapitre 1 garde ses normaux sans technique.
- **Une seule mécanique prévue et absente** : l'**armure qui se fend** (E8) du **Gardien d'écorce** (prévue dans
  `MONSTRES.md`, chapitre 3). Proposition : après son Bouclier d'écorce, son armure se fend 3 s (défense retirée,
  dégâts subis × 1,5), comme le Cratère ouvert du Titan.
- **Effets visuels actuels** :
  - effets **peints** par Codex pour tout le chapitre 3 (Enlisés, Reflets : attaques et techniques), Glauquemire et
    le Dévoreur des Sources ;
  - ailleurs, formes du jeu (cercles d'alerte, éclats, anneaux) et pixelfx génériques déjà en place (impact,
    disparition, anneaux des boss).
  - **Aucune** technique des chapitres 1, 2 et 4 n'a d'effet propre.

## 2. Règle d'attribution : un élément par famille

Chaque effet est recoloré avec la **palette de sa famille** (`tools/art/pixelfx/families.json`). Seules les
catégories de pixelfx permises pour la famille sont utilisées ; un test vérifiera qu'aucune technique n'emprunte une
catégorie interdite.

| Famille (chapitre) | Élément | Catégories pixelfx permises | Interdites |
|---|---|---|---|
| Violets (1) | Faille, vide | shadow, arcane, spawn | fire, ice, water, lightning |
| Hautes Terres (1) | Orage, pierre | lightning, nature (quake, boulder, earth-spike), weather (storm) | fire, ice, water |
| Calcinés (2) | Cendre, suie, braise | fire, explosions (smoke-bomb, small-explosion) | ice, water, lightning |
| Enfants du magma (2) | Lave | fire, explosions (dirt, big) | ice, water, lightning |
| Enlisés (3) | Vase, spores, eau | nature (spore, poison, root), water | fire, ice, lightning |
| Reflets (3) | Cristal, prisme | arcane, ice-crystal (forme de cristal), pickups/crystal-shard, holy (sunburst) | fire, water |
| Givrés (4) | Neige, gel | ice, weather (blizzard, snow) | fire, water, lightning |
| Échos du silence (4) | Glace muette | ice, shadow (hex, soul-drain), arcane (time-stop, mana) | fire, water, lightning |

Communs à toutes les familles (sans élément) : impacts (heavy-landing, ground-slam, shield-block), spawn
(summon-rise, egg-hatch), status (rage, stunned, slowed), melee (claw-swipe, heavy-cleave, spin-slash).

## 3. Attribution par Corrompu

Moments : **annonce** (pendant le télégraphe), **effet** (au déclenchement ou à l'impact), **état** (en boucle
pendant la durée). Les normaux sans technique ne reçoivent rien de plus (impact et disparition génériques
existants) ; les tireurs reçoivent un **impact de tir** à l'élément de leur famille.

### Violets (chapitre 1)

| Corrompu | Rang | Compétence | Effet pixelfx |
|---|---|---|---|
| Nuée-mère | élite | Tunnel (burrow) · invocation | effet : shadow/grasping-hands à la sortie · spawn/summon-rise par petit |
| Rôdeur d'ombre | normal | Téléportation (blinker) | arcane/blink-out au départ, arcane/blink-in à l'arrivée |
| Gardien de cristal | élite | Garde (warden) | état : arcane/rune-circle sous lui |
| Cracheur | normal | Tir | impact : arcane/mana-burst (petit) |
| Faille | structure | Apparition des Corrompus | spawn/spawn-portal |

### Hautes Terres (chapitre 1, finale)

| Corrompu | Rang | Compétence | Effet pixelfx |
|---|---|---|---|
| Gardien des menhirs | élite | Tunnel | effet : nature/quake + nature/earth-spike à la sortie |
| Chimère des sommets | élite | Saut | effet : lightning/thunderclap à l'atterrissage |
| Chevalier fulgurant | élite | Saut | effet : lightning/lightning-strike à l'atterrissage |
| Salamandre de cendre, Harpie argentée | normaux | Tir | impact : lightning/zap-hit |

### Calcinés (chapitre 2)

| Corrompu | Rang | Compétence | Effet pixelfx |
|---|---|---|---|
| Chien de suie | normal + technique | Bond | effet : explosions/smoke-bomb à l'atterrissage |
| Brute du bûcher | élite | Bûcher écrasé · Rage du brasier | effet : fire/flame-pillar · état : status/rage + fire/spirit-flame |
| Veuve de cendre | élite | Ponte · Toile de suie | effet : spawn/egg-hatch à l'éclosion · impact : explosions/smoke-bomb + status/slowed |
| Chevalier calciné | élite | Charge · Taille tournoyante | annonce : fire/torch sur l'épée · effet : melee/spin-slash + fire/fire-ring |
| Feu-fumée | normal | Tir | impact : explosions/smoke-bomb (petit) |
| Bulbe de braise | objet de carte | Éclatement | explosions/small-explosion |
| Œuf et nid de cendre | structures | Éclosion | spawn/egg-hatch |

### Enfants du magma (chapitre 2)

| Corrompu | Rang | Compétence | Effet pixelfx |
|---|---|---|---|
| Rôdeur de lave | normal + technique | Plongée | effet : fire/flame-pillar + explosions/dirt-explosion à la sortie |
| Titan de caldeira | élite | Éruption · Cratère ouvert | effet : fire/flame-pillar sur chaque geyser · état : fire/brazier sur le Titan |
| Wyvernette de flammes | élite | Souffle · Piqué | effet : fire/fire-breath dans le cône · fire/meteor à l'impact |
| Matrone des scories | élite | Couvée · Mue | spawn/summon-rise · effet : explosions/dirt-explosion + fire/fire-ring (flaque) |
| Cracheur de braise | normal | Tir | impact : explosions/small-explosion |

### Enlisés et Reflets (chapitre 3)

Effets **peints** déjà livrés pour chaque attaque et technique, dans la direction artistique des cartes : **on les
garde** (proposition). pixelfx ne s'ajoute que là où rien n'est peint :

| Corrompu | Compétence | Effet pixelfx (complément) |
|---|---|---|
| Gardien d'écorce | Armure qui se fend (nouvelle, voir l'audit) | effet : impacts/shield-block puis nature/thorns |
| Mère-spore | Aura de soin (état) | état : nature/healing-bloom |
| Prêtresse-miroir, Chasseresse des reflets | Téléportation quand on la frappe trop | arcane/blink-out, arcane/blink-in |

### Givrés (chapitre 4)

| Corrompu | Rang | Compétence | Effet pixelfx |
|---|---|---|---|
| Loup de blizzard | normal + technique | Glissade | effet : ice/snowflake-burst à l'arrêt |
| Chaman du gel | élite | Prison de glace · Brume glaciale · Souffle des braseros | effet : ice/freeze sur le Chasseur · état : weather/blizzard (zone) · ice/frost-breath vers le brasero |
| Yéti des cimes | élite | Avalanche · Bond · Rage | effet : ice/ice-shatter à l'éclatement · impacts/heavy-landing + ice/snowflake-burst · état : status/rage |
| Archère du givre | élite | Flèche glaçante · Pluie de grêle | impact : ice/ice-shatter (petit) + status/slowed · ice/icicle-fall sur chaque point |

### Échos du silence (chapitre 4)

| Corrompu | Rang | Compétence | Effet pixelfx |
|---|---|---|---|
| Brise-banquise | normal + technique | Plongée | effet : ice/ice-spikes à la sortie |
| Héraut du silence | élite | Silence · Écho des sorts | état : shadow/hex-sigil sur le cercle · effet : arcane/mana-burst puis arcane/arcane-missiles |
| Mammouth de givre | élite | Piétinement (armure qui éclate) · Fissure | impacts/ground-slam + ice/ice-shatter · ice/ice-spikes le long de la fissure |
| Sorcière des neiges | élite | Appel du blizzard · Clones · Téléportation | état : ice/blizzard-vortex · arcane/blink-in par clone · arcane/blink-out, arcane/blink-in |
| Sentinelle gelée | normal | Tir | impact : ice/ice-shatter (petit) |

## 4. Boss

Motifs communs, à l'élément du boss : griffes → melee/claw-swipe · balayage → melee/heavy-cleave · écrasement →
impacts/ground-slam · charge → impacts/heavy-landing à l'arrêt · invocation → spawn/summon-rise · souffle →
fire/fire-breath (feu) ou ice/frost-breath (glace) · pluie de roches → nature/boulder (pierre), fire/meteor (lave),
ice/icicle-fall (glace). Anneaux : charge, onde et poussière déjà livrées (PR 111).

| Boss (carte, famille) | Mécanique phare | Effet pixelfx propre |
|---|---|---|
| Nébulorax (1, violets) | Absorption | état : shadow/black-hole pendant l'aspiration · effet : shadow/dark-explosion au recrachat |
| Astravorn (2, violets : ses attaques sont celles du vide) | Couronne d'astres | état : arcane/star-fall sur chaque astre · rayon du vide : shadow/void-orb à la source |
| Sentinelle des racines (3, violets) | Séisme | nature/quake (au départ de chaque anneau) |
| Chimère des brumes (4, Hautes Terres) | Voile de brume | état : weather/fog autour d'elle · effet : lightning/zap-hit sur chaque lanterne brisée |
| Dévoreur des Sources (5) | Orbes de source | **effets peints conservés** |
| Gardien du bûcher (6, Calcinés) | Charge du bûcher | effet : explosions/smoke-bomb au choc · état : status/stunned quand il est sonné |
| Chevalier calciné, gardien (7) | Cercle du duel | état : fire/fire-ring sur le bord du cercle |
| Reine-veuve (8, Calcinés) | Fils tendus | effet : status/slowed sur le Chasseur collé · melee/sword-slash quand une Ruée coupe un fil |
| Matrone des scories (9, magma) | Carapace et pluie de scories | effet : fire/meteor par roche · explosions/dirt-explosion quand la carapace se fend |
| Pyrevorn (10, magma) | Séquence des cratères | effet : fire/flame-pillar par case · Envol et chute : fire/meteor · Œil de la Faille : fire/spirit-flame à l'œil |
| Gardien d'écorce, gardien (11, Enlisés) | Garde d'écorce | effet : impacts/shield-block sur un coup de face · nature/root-snare pour les racines |
| Gueule des marais (12, Enlisés) | Plongée | effet : water/splash à la plongée · water/geyser à la sortie |
| Mère des spores (13, Enlisés) | Voile de spores | état : nature/spore-burst sur le voile · effet : nature/poison-cloud quand il brûle |
| Dame des portails (14, Reflets) | Saut de portail | arcane/portal au départ et à l'arrivée |
| Glauquemire (15) | Miroirs à orienter | **effets peints conservés** |
| Patriarche des cimes (16, Givrés) | Avalanche | effet : ice/ice-shatter à l'éclatement de chaque boule |
| Chaman ancestral (17, Givrés) | Grand gel | effet : ice/frost-nova sur la vague · fire/brazier sur le brasero gardé (chaleur, seule exception au feu chez les Givrés) |
| Loup alpha des tempêtes (18, Givrés) | Chasse dans la tempête | état : weather/blizzard autour du Chasseur · ice/snowflake-burst à chaque assaut |
| Nivorath (20, Échos du silence) | Écho des sorts | état : shadow/soul-drain gueule ouverte · effet : arcane/arcane-missiles au renvoi · pics : ice/ice-spikes · banquise : ice/ice-shatter |

## 5. Mise en œuvre prévue (lots 2 et 3)

- **Données, pas de code par monstre** : `tools/art/pixelfx/techniques.json` associe à chaque famille et à chaque
  technique (ou motif de boss) ses effets d'annonce, d'effet et d'état. `build_pixelfx.py` ne génère que les
  feuilles utilisées, dans la palette de la famille.
- **Un seul point d'appel** : `PixelFx.technique(enemy, technique, moment, position)` depuis `_run_technique` (comme
  les effets peints du chapitre 3) et depuis les motifs des boss ; un état suit son porteur et s'arrête avec lui.
- **Garde-fous** : plafond d'effets actifs (48), aucun effet n'est nécessaire pour comprendre une attaque (les
  cercles d'alerte du jeu restent la référence), test des catégories permises par famille.
- **Poids estimé** : 70 à 90 feuilles, environ 20 à 30 Mo (selon la longueur des effets).
- **Découpage** : lot 2 = chapitres 1 et 2 (Violets, Hautes Terres, Calcinés, Magma) et leurs boss ; lot 3 =
  chapitres 3 et 4, armure qui se fend du Gardien d'écorce et boss restants.

## 6. Décisions demandées au propriétaire

1. Valider la règle des éléments (section 2) et les attributions (sections 3 et 4), ou les corriger.
2. Chapitre 3, Glauquemire et Dévoreur des Sources : **garder les effets peints** (proposé) ou les remplacer par
   pixelfx pour l'homogénéité ?
3. Coder l'**armure qui se fend** du Gardien d'écorce (proposé) ?
4. Ajouter l'**impact de tir** par famille pour les tireurs normaux (proposé) ?
