# Monstres, élites et boss : planches et mécaniques

Statut : **règle validée par le propriétaire le 22 octobre 2026**, valable à partir du chapitre 2 et pour tous les
chapitres suivants. Le chapitre 1 garde ses sprites et ses animations actuels : c'est le début du jeu.
Cadre : [CARTES.md](CARTES.md) (familles par chapitre, briques de terrain), [../ART_BIBLE.md](../ART_BIBLE.md)
(style des planches), [../../assets/concepts/incoming/README.md](../../assets/concepts/incoming/README.md) (import).

## Principe

- **Les monstres de base restent simples** : déplacement et attaque. Ils font nombre ; leur lisibilité prime.
  Quelques exceptions par famille reçoivent **une** technique dessinée (bond, plongée…).
- **Les élites et les boss sont plus fournis** : chacun a des **techniques propres**, dessinées sur des planches
  dédiées, qui portent une **mécanique** (un comportement de jeu, pas seulement une animation).
- **Progression continue** : la difficulté et l'apparition de nouvelles mécaniques augmentent sans palier plat, d'une
  carte à l'autre et d'un chapitre à l'autre (voir « Montée en puissance »).
- **Rien n'est dessiné pour rien** : chaque rangée d'une planche correspond à une animation jouée en jeu. Une
  animation prévue sans mécanique codée n'est pas commandée.

Piste en attente : donner le Saut et le Tunnel (E1, E2) à quatre élites du chapitre 1, décision reportée au test
complet du chapitre 1 (voir `docs/ROADMAP.md`, « À décider lors du test complet du chapitre 1 »).

## Planches par rang

Toujours **6 colonnes** ; une planche fait **2 ou 3 rangées au maximum** (le générateur d'images est plus fiable). Un
monstre peut avoir plusieurs planches : le `job.json` liste chaque animation avec sa source et sa rangée. Toutes les
planches d'un monstre sont générées avec la planche A en référence, pour garder l'identité.

| Rang | Planche A | Planches suivantes | Mort |
|---|---|---|---|
| Normal | 6 × 2 : déplacement, attaque | — (exception « + technique » : planche A en 6 × 3, rangée 3 = la technique) | effet commun de dispersion, teinté selon la famille |
| Élite | 6 × 3 : déplacement, attaque, mort | B en 6 × 2 : technique 1, technique 2 (puis C à partir du chapitre 3, voir plus bas) | dessinée |
| Boss (Dévoreur) | 6 × 3 : idle, déplacement, attaque de base | 3 à 5 planches : techniques de chaque phase, transformation, mort | dessinée |

- Chaque technique se lit **anticipation lisible → action → retour**.
- Les effets dessinés font partie du corps ou en partent (flammes de la gueule, gerbe au sol de l'impact). **Les
  cercles d'alerte et les zones au sol sont dessinés par le jeu**, jamais dans la planche.
- Les gardiens de fin de carte réutilisent une élite agrandie avec ses techniques ; aucune planche en plus.

## Catalogue des mécaniques ennemies

Codées une fois, réglées en données dans la fiche du monstre (comme les briques de terrain) ; une élite en combine
deux, un boss davantage. Le chapitre indique la première apparition.

| # | Mécanique | Ce qu'elle demande au joueur | Apparition |
|---|---|---|---|
| E1 | **Bond** : saut télégraphié sur la position du Chasseur, au-dessus des foules, dégâts à l'atterrissage | ne pas fuir en ligne droite, Ruée au bon moment | chapitre 2 (normal) |
| E2 | **Enfouissement** : disparaît sous terre, traînée visible, ressort sous le Chasseur | rester en mouvement | chapitre 2 (normal) |
| E3 | **Sol brûlant laissé derrière soi** : plaque temporaire qui blesse | se repositionner, y attirer les hordes | chapitre 2 |
| E4 | **Ponte** : œufs qui éclosent si on ne les casse pas à temps | choisir ses cibles | chapitre 2 |
| E5 | **Projectile entravant** : toile, glue, gel qui ralentit fortement | esquiver plutôt que tanker | chapitre 2 |
| E6 | **Charge en ligne + coup final** : ligne télégraphiée puis attaque circulaire | sortir de l'axe, puis de la zone | chapitre 2 |
| E7 | **Rage** : sous 50 % de PV, plus rapide et plus dangereux (aspect changé) | finir vite ou garder ses sorts | chapitre 2 |
| E8 | **Armure + fenêtre de faiblesse** : dégâts réduits sauf pendant une ouverture après une technique | frapper au bon moment | chapitre 2 |
| E9 | **Envol et piqué** : intouchable en l'air, ombre au sol, retombe sur un point marqué | lire l'ombre | chapitre 2 |
| E10 | **Cône de souffle** | contourner par le flanc | chapitre 2 |
| E11 | **Invocation de petits** | nettoyer avant qu'ils s'accumulent | chapitre 1 (couveuse) |
| E12 | **Mue** : perd son armure à mi-vie, laisse une flaque, devient plus rapide | changer de rythme | chapitre 2 |
| E13 | **Rayon qui balaie** | se placer derrière un abri | chapitre 2 (boss) |
| … | Pistes : bouclier pour ses alliés, vol de vie, reflet de projectiles, téléportation en chaîne, marque qui explose, clones, contrôle du terrain (geler, inonder) | | chapitres 3 à 5 |

Règles : tout est **télégraphié** ; une mécanique a un **temps de recharge** et une **portée minimale** (pas de
répétition au contact) ; elle doit offrir une **occasion** (fenêtre de faiblesse, ennemis pris dans la zone), pas
seulement une punition.

## Montée en puissance

Vue d'ensemble de tous les leviers (terrain, monstres, hordes…), règle des abris et courbe mesurée au bot :
[DIFFICULTE.md](DIFFICULTE.md).

### D'un chapitre à l'autre

| Chapitre | Normaux avec technique | Élites | Boss | Nouvelles mécaniques |
|---|---|---|---|---|
| 1 (actuel) | aucun (comportements de base : chasseur, tireur, chargeur, invocateur, clignoteur, gardien) | attaque de base + affixes | 2 phases | — |
| 2 | 1 par famille | 2 techniques | 2 phases, 4 planches | E1 à E13 en grande partie |
| 3 | 1 à 2 par famille | 2 techniques + 1 trait passif (aura, réaction aux dégâts) ; planche C pour le trait si visible | 3 phases | 3 ou 4 nouvelles, et anciennes **combinées** autrement |
| 4 | 2 par famille | 3 techniques, enchaînables en combo | 3 phases, attaques combinées | 3 ou 4 nouvelles |
| 5 | 2 ou 3 par famille | 3 techniques + trait passif ; certaines élites en duo | 3 phases + phase finale | dernières mécaniques ; finale qui reprend le meilleur des chapitres |

Les mécaniques déjà vues reviennent dans les chapitres suivants **sous un autre habillage ou dans d'autres
combinaisons** (le bond du chien de suie devient le saut d'un loup des glaces qui gèle à l'atterrissage).

### Mécanique phare de chaque boss (décision du propriétaire, 26 octobre 2026)

Chaque boss apporte **au moins une mécanique que personne n'a eue avant lui** : sa mécanique phare
(`BossData.signature`). Il peut reprendre quelques attaques déjà vues, jamais la mécanique phare d'un autre. Les
Dévoreurs de fin de chapitre sont de plus en plus forts (PV, plus gros coup, phases). Le test
`test_boss_signatures` le vérifie à chaque ajout de boss.

Les mécaniques phares se répondent : le chapitre 1 apprend à **renvoyer** une attaque du boss contre lui, le
chapitre 2 à **lire toute l'arène**, le chapitre 3 combine les deux (orienter l'arène pour retourner son arme).

| Boss | Place | PV · plus gros coup · phases | Mécanique phare | Reprises |
|---|---|---|---|---|
| Nébulorax | carte 1 | 5 000 · 22 · 2 | **Absorption** : avale les tirs, les recrache, puis cœur exposé ×2 | — |
| Astravorn | carte 2 | 5 600 · 22 · 2 | **Couronne d'astres** : anneau d'étoiles qui tourne avec des brèches, rétrécit et accélère ; de l'extérieur, les coups sont absorbés à 85 % ; concentré, le boss n'attaque plus : entrer par une brèche et frapper ; à la fin, les étoiles partent vers l'extérieur | griffes, vague d'ombres, rayon du vide, invocations |
| Sentinelle des racines (gardien) | carte 3 | 3 000 · 20 · 1 | **Séisme** : anneaux sans brèche, à franchir d'une Ruée (invulnérable pendant la Ruée) | griffes, charge, invocations |
| Chimère des brumes (gardien) | carte 4 | 3 000 · 20 · 1 | **Voile de brume** : intouchable tant que brûlent ses 3 lanternes (fils de brume visibles) ; les briser toutes la fige (sonnée, dégâts ×2) ; un voile qui tient jusqu'au bout lui rend des PV | griffes, pas de brume, bond, rugissement, invocations |
| Dévoreur des Sources | carte 5, finale ch. 1 | 6 500 · 26 · 2 | **Orbes de source** : orbes lents qui suivent le Chasseur ; une Ruée dedans les renvoie sur le boss, l'orbe doré l'étourdit ; touchés sans Ruée : dégâts et ralenti | griffes, double écrasement, souffle arrêté par les rochers, invocations |
| Gardien du bûcher (gardien) | carte 6 | 3 600 · 22 · 2 | **Charge du bûcher** : il fonce tout droit, loin ; contre un rocher ou une barrière, il s'assomme (sonné, dégâts ×2) : placer un obstacle derrière soi et s'écarter au dernier moment | balayage, bûcher écrasé, invocations |
| Pyrevorn | carte 10, finale ch. 2 | 9 000 · 30 · 2 (+ 2 mini-boss) | **Séquence des cratères** : grille de 3 × 3 cases ; des cases s'allument une à une puis entrent en éruption dans le même ordre, à peine annoncées ; retenir lesquelles et quand | griffes, pluie du cratère, couvée, envol et chute, Œil de la Faille |
| Glauquemire | carte 15, finale ch. 3 | 12 500 · 34 · 3 | **Miroirs à orienter** : une Ruée contre un miroir le tourne dans le sens de la Ruée ; le rayon de prisme balaie l'arène et suit la flèche des miroirs ; renvoyé sur le boss, il brise sa carapace et l'étourdit | griffes, écrasement |

Glauquemire a aussi sept autres mécaniques nouvelles (vase qui durcit en murs, racine-laisse, sangsues
nourricières, carapace à facettes, tourbillon, anneau de marée, engloutissement d'un Écho) :
[DEVOREUR_CHAPITRE3.md](DEVOREUR_CHAPITRE3.md). Les cartes 7 à 9 reprennent pour l'instant le Gardien du bûcher ; leurs
gardiens propres, comme ceux du chapitre 3, devront chacun apporter leur mécanique phare.

#### Gardiens des cartes 7 à 9 : proposés le 26 octobre, validés et codés le 31 octobre 2026

Chacun est l'élite que la carte met en avant, en version boss (sprite agrandi, comme le Gardien du bûcher) : pas de
nouvelle planche, seulement ses effets. Aucune de ces mécaniques n'existe chez un autre boss.

| Carte | Gardien | Mécanique phare proposée | Pour le joueur |
|---|---|---|---|
| 7. Évents de cendre | Chevalier calciné | **Cercle du duel** : il plante son épée et trace un cercle de feu (rayon 350) autour de lui et du Chasseur. Les Échos restent dehors 8 s ; dedans, le Chevalier prend 1,5 × les coups du Chasseur ; sortir du cercle brûle. Le reste du temps : charge, taille tournoyante | se battre seul, bien se placer avant le cercle |
| 8. Tanières de suie | Reine-veuve (Veuve de cendre) | **Fils tendus** : elle tend des fils de soie entre les rochers et les nids. Toucher un fil colle sur place 1,2 s, et elle bondit sur la proie engluée. Une Ruée à travers un fil le coupe. Les fils bloquent aussi les Corrompus | lire les fils, garder sa Ruée, couper un passage |
| 9. Volcan carré | Matrone des scories | Au choix du propriétaire. **Chaleur** : une jauge du Chasseur monte près d'elle et sur la lave, et redescend loin d'elle ou sur la croûte refroidie ; pleine, elle brûle. Il faut frapper puis s'écarter. Ou **Carapace à fendre** : elle est insensible tant que sa carapace tient ; une roche magmatique qui tombe sur elle la fend 10 s. Il faut l'attirer sous les ombres des roches | gérer la distance, ou se servir de la pluie de roches de la carte |

**Réalisé** (`AshGuardians`, `data/bosses/cinder_champion.tres`, `widow_queen.tres`, `slag_matriarch.tres`) :

- **Chevalier calciné** (`duel_circle`) : cercle de rayon 350 au moins, centré entre lui et le Chasseur, 8 s (9 s en
  phase 2) ; Échos repoussés dehors, coups du Chasseur × 1,5, 6 dégâts toutes les 0,5 s hors du cercle (8 en phase 2).
  Taille tournoyante, charge et invocations autour.
- **Reine-veuve** (`silk_threads`) : 4 fils (6 en phase 2) de 420 unités autour du Chasseur, 14 s. Un fil touché colle
  1,2 s puis la Reine bondit sur la zone annoncée ; une Ruée à travers le fil le tranche. Les fils ne bloquent pas les
  Corrompus (simplification). Couvée et charge autour.
- **Matrone des scories** (`slag_rain`, carapace) : choix retenu « Carapace à fendre », qui se sert de la pluie de roches
  de la carte 9. Carapace dès son arrivée (coups × 0,15) ; une roche qui tombe sur elle (pluie de la carte ou sa
  propre pluie de scories) la fend 10 s (coups × 1,5, sonnée 1 s).

Le bot reste dans le cercle du duel, s'écarte des fils (et tranche d'une Ruée quand il est collé) et reste près de la
Matrone quand sa carapace tient. Tests : `test_boss_signatures`.

### À l'intérieur d'un chapitre (5 cartes)

- **Carte 1** : la nouvelle famille avec ses normaux simples et **une** élite ; ses mécaniques sont présentées seules.
- **Cartes 2 et 3** : les autres élites arrivent, une ou deux mécaniques nouvelles par carte ; les normaux à
  technique apparaissent.
- **Carte 4** : toute la famille, élites en même temps, mécaniques combinées.
- **Carte 5** : finale du chapitre, deuxième famille plus forte (comme les Hautes Terres au chapitre 1) et Dévoreur.
- Les forces des ennemis (PV, dégâts, cadence des vagues) suivent cette même pente ; `enemy_hp_mult` et
  `enemy_damage_mult` des arènes corrigent une famille trop forte ou trop faible pour sa place.

## Application au chapitre 2 « Les Terres dévastées »

Familles et descriptions complètes : prompt Codex du 22 octobre (conservé dans les `job.json` de chaque monstre).

| Famille | Normaux | Normal à technique | Élites (technique 1 / technique 2) |
|---|---|---|---|
| Calcinés (cartes 6 à 8) | Rampe-cendre, Chien de suie, Golem de charbon, Feu-fumée | Chien de suie : **Bond** (E1) | Brute du bûcher : Bûcher écrasé (E3) / Rage du brasier (E7) ; Veuve de cendre : Ponte (E4) / Toile de suie (E5) ; Chevalier calciné : Charge (E6) / Taille tournoyante (E6) |
| Enfants du magma (cartes 9 et 10) | Acarien de magma, Rôdeur de lave, Brute d'obsidienne, Cracheur de braise | Rôdeur de lave : **Plongée** (E2) | Titan de caldeira : Éruption (E3) / Cratère ouvert (E8) ; Wyvernette : Souffle (E10) / Piqué (E9) ; Matrone des scories : Couvée (E11) / Mue (E12) |

Dévoreur **Pyrevorn** (carte 10) : planche A (idle, déplacement, griffes), B phase 1 (souffle de magma, pluie du
cratère, appel de la couvée), C (transformation, mort), D phase 2 (idle, envol et chute avec anneaux de lave, Œil de
la Faille : rayon qui balaie, E13). Depuis le 26 octobre, la séquence des cratères (sa mécanique phare) remplace le
souffle, qui reste propre au Dévoreur des Sources ; l'animation `magma_breath` n'est plus jouée.

Ordre d'introduction : carte 6 Brute du bûcher (sol brûlant, en écho aux plaques de la carte) ; carte 7 Chevalier
calciné et Chien de suie ; carte 8 Veuve de cendre (avec les nids de la carte) ; carte 9 Enfants du magma, Titan et
Rôdeur ; carte 10 Wyvernette, Matrone et Pyrevorn.

## Application au chapitre 3 « Les Marais engloutis » (prompt Codex du 26 octobre)

| Famille | Normaux | Normaux à technique | Élites (technique 1 / technique 2 ; trait passif) |
|---|---|---|---|
| Enlisés (cartes 11 à 13) | Sangsue des vases, Crapaud-gonfle, Moustique de faille (**volant**), Racine rampante | Crapaud : Saut boueux (E1 + ralentit) ; Racine : Enfouissement (E2) | Mère-spore : Spore-marque (**E14**) / Tapis de spores (E3) ; aura de soin. Gardien d'écorce : Racines entravantes (E5) / Bouclier d'écorce (**E15**) ; armure qui se fend (E8). Gueule des marais : Plongée (E2) / Charge ventrale (E6) ; rage (E7) |
| Reflets (cartes 14 et 15) | Éclat errant (**volant**), Sentinelle de verre, Golem de quartz, Miroir rampant | Miroir : Saut de reflet (**E16**) | Prêtresse-miroir : Reflets (**E17**) / Miroir renvoyeur ; téléportation quand on la frappe trop. Colosse de cristal : Rayon qui balaie (E13) / Gerbe d'éclats ; faiblesse après le rayon (E8). Chasseresse des reflets : Saut en chaîne (E16) / Marque de prisme (E14) ; invisible de loin |

Nouvelles mécaniques du chapitre 3 :

| # | Mécanique | Ce qu'elle demande au joueur |
|---|---|---|
| E14 | **Marque qui explose** : le Chasseur est marqué, la marque explose après un délai ; la Ruée l'efface | garder sa Ruée, s'écarter de ses Échos |
| E15 | **Bouclier des alliés** : les Corrompus proches de l'élite ne prennent plus de dégâts tant qu'elle tient le bouclier | tuer ou interrompre l'élite d'abord |
| E16 | **Téléportation** : disparaît et réapparaît sur un flanc du Chasseur | ne pas rester immobile |
| E17 | **Clones** : copies fragiles qui imitent ses tirs | trouver l'originale |
| — | **Volants** : survolent le décor (les tirs aussi les atteignent) | ne pas compter sur les abris contre eux |

## État du code (26 octobre 2026, mécaniques phares)

`BossData.signature` ; mécaniques qui durent au-delà d'une attaque dans des `BossMechanics` créées par le
`BossController` : `BossSignatures` (`source_orb`, `star_crown`, `crater_sequence`), `GuardianSignatures`
(`mist_veil` avec les lanternes `mist_lantern`, `pyre_ram`) et `GlauquemireMechanics`
(`mud_wall`, `root_leash`, `leech_feed`, `prism_beam`, `whirlpool`, `swallow` ; mécaniques passives de phase
`BossPhaseData.mechanics` : `facets`, `mirrors`, `tide_ring`, réglées par `mechanic_params`). Le bot les joue
(Ruée dans les orbes, entrée dans la couronne, cases retenues sept fois sur dix, Ruée à travers un miroir).
Glauquemire : `data/bosses/glauquemire.tres`, forme provisoire (manifeste : `planned`) en attendant Codex.

## État du code (26 octobre 2026)

Chapitre 3 : `MarshTechniques` (techniques appelées par `EnemyManager` quand il n'a pas `_technique_<kind>`) :
`mark` (E14), `ally_shield` (E15), `blink` (E16, en chaîne ou en fuite avec `on_hits`), `clones` (E17), `heal_aura`,
`reflect` (miroir renvoyeur), `mud_leap`, `sweep_beam` (rayon qui balaie puis cœur à nu), `shard_fan`. Volants
(`EnemyData.flying`) et furtifs (`stealth_range`). Les 14 monstres ont leur fiche avec une forme provisoire (manifeste :
statut `planned`) en attendant les sprites. Pyrevorn : `data/bosses/pyrevorn.tres`, attaques `skyfall` et `eye_beam`
ajoutées au `BossController`. Gardiens de palier : élites en version boss (`EnemyManager.spawn_mini_boss`).

## État du code (23 octobre 2026)

Techniques en données (`EnemyTechniqueData`, méthodes `_technique_<kind>` d'`EnemyManager`) : `burn_slam` (E3),
`rage` (E7), `leap` (E1, et E9 avec `airborne`), `charge` (E6, taille tournoyante en fin de ruée), `lay_eggs` (E4,
œufs `ash_egg` à casser), `web` (E5, tir qui entrave le Chasseur), `burrow` (E2), `eruption` (E3 et E8 : cratère
ouvert), `breath` (E10, cône), `brood` (E11), `molt` (E12, flaque de scories qui entrave). Les 7 Calcinés et les
7 Enfants du magma ont leur fiche (`data/enemies/`). Le rayon de Pyrevorn (E13) viendra avec le boss.
