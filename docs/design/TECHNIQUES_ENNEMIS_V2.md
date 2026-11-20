# Techniques des nouvelles familles et de leurs boss (v2)

Session « Gameplay », novembre 2026. Familles dont les visuels sont fusionnés (PR #237) : Saumâtres → Saumor,
Rapiécés → L'Ourdisseur, Vernissés → Faïron. Une PR par famille, sans fusion automatique. L'équilibrage définitif
viendra après les essais en jeu du propriétaire : toutes les valeurs ci-dessous sont **provisoires**.

## 1. Socle

- **Monstres** : fiches `data/enemies/<id>.tres` (statistiques en unités v1). Les techniques sont des
  `EnemyTechniqueData` de la fiche : `cooldown` (s), `min_range`/`max_range` (unités v1), `telegraph` (s),
  `damage`, `anim` (rangée de la feuille) et `params` (mètres, secondes). Rien n'est en dur dans le code.
- **Moteur** : `draft3d/foe_techniques.gd` (`DraftFoeTechniques`, porté par `DraftEnemies`). Une technique à la fois,
  1,6 s au moins entre deux techniques d'un même monstre, première technique après 1,5 à 3,5 s. Jamais à travers un
  mur (ligne de vue) ni vers un autre niveau. Le monstre tient sa position pendant l'annonce et la récupération ;
  le contact blesse toujours. Seules les techniques connues du moteur sont jouées : les anciennes familles
  gardent leur comportement.
- **Annonces** : `DraftHazards` (cercle, couloir, onde, zone) ; les annonces restent dessinées au-dessus des effets.
  Les couloirs « abrités » (`covered`) sont arrêtés par le décor ; les ondes se coupent derrière un obstacle et une
  Ruée les traverse.
- **Contrôles** : ralentissements courts seulement (flaque 3 s, ×0,6), reculs ; aucune immobilisation, aucun
  enchaînement de contrôles imposé.
- **Boss** : fiche `data/bosses/<id>.tres` (deux phases, seuil 50 %, transition `transform`), mécanique
  `draft3d/bosses/<id>.gd` qui joue les techniques de la fiche. En phase 2, le boss passe sur `phase2_idle` et
  `phase2_move` quand sa feuille les a (désormais pour tous les boss).
- **Bestiaire** : `DraftRoster.V2_FAMILIES` ajoute la famille au chapitre (un normal de la famille après chaque
  monstre d'origine, élites en fin de liste : elles arrivent plus tard dans la partie) et son boss aux gardiens
  tirés au hasard ; le Dévoreur du chapitre reste le boss final.

## 2. FX dédiés : identifiants et déclencheurs

En attendant les animations dédiées, chaque effet joue un PixelFX existant. Dès qu'une feuille est déposée en
`assets/vfx/pixelfx/<id>/violet.png` + `.json` (format PixelFX, voir `docs/design/FICHES_VFX_GAMEPLAY_V2.md`), elle
remplace l'effet de secours, mise à la largeur indiquée (`DraftRun.fx_or`). Ancrage : centre de l'image.

| Identifiant | Déclencheur | Largeur (m) | Secours actuel |
|---|---|---|---|
| `tech_brine_jet_pool` | fin de l'annonce du Jet de saumure, au bout du jet | 2 × rayon de flaque | `splash` |
| `tech_lock_guard` | levée de la vanne, devant le Gardien | 1,6 | `shield_block` |
| `tech_mallet_slam` | frappe du maillet (centre du cône) | 2 × rayon | `quake` |
| `tech_bell_call` | départ de chaque onde des cloches | 2,4 | `thunderclap` |
| `tech_brine_blessing` | sur chaque allié béni | 1,4 | `healing_bloom` |
| `tech_scoop_charge_impact` | fin de la charge au godet | 2,0 | `dirt_explosion` |
| `tech_salt_crust_burst` | départ des six éclats | 3,0 | `ice_shatter_small` |
| `boss_saumor_gate_bite` | morsure du siphon à la fin de l'Appel de la vanne | 2 × rayon | `geyser` |
| `boss_saumor_shoulder_slam` | impact de l'Écrasement d'épaule | 2 × rayon | `quake` |
| `boss_saumor_core_burst_inner` | première pulsation (cercle intérieur) | 2 × rayon intérieur | `geyser` |
| `boss_saumor_core_burst_outer` | seconde pulsation (chaque disque de la couronne) | 2 × rayon de disque | `splash` |

Effets encore sans identifiant dédié (dessinés par le moteur) : le courant de l'Appel de la vanne (bande
translucide boss → Chasseur), les couloirs du Jet, de la Charge, des éclats et du Balayage (annonces au sol).

## 3. Lot 1 — Saumâtres et Saumor (chapitre « Le Marais des Marées »)

Famille PixelFX `enlises`. Normaux : Griffe-sel (contact), Noyé des cordages (contact), Raie des saumures (tir).

| Technique | Monstre | Fonctionnement | Réglages (`params`) |
|---|---|---|---|
| Jet de saumure `brine_jet` | Siphon de sel | couloir annoncé vers le Chasseur, abrité par le décor ; flaque ralentissante au bout du jet | `length`, `width`, `pool_radius`, `pool_time`, `pool_slow`, `recover` |
| Garde de vanne `lock_guard` | Gardien de l'écluse | garde tenue sur place : coups de face ×0,25, de dos ×1,5 (arc avant 70°) | `duration`, `front_mult`, `back_mult`, `arc` |
| Frappe du maillet `mallet_slam` | Gardien de l'écluse | cône devant (disque décalé), dégâts et recul | `reach`, `radius`, `knockback`, `recover` |
| Appel des cloches `bell_call` | Chantre de saumure | deux ondes successives (0,8 s d'écart) | `gap`, `speed`, `reach`, `recover` |
| Bénédiction saumâtre `brine_blessing` | Chantre de saumure | 3 alliés au plus (les plus proches, jamais lui-même ni un boss) encaissent ×0,5 pendant 4 s | `radius`, `targets`, `duration`, `mult` |
| Charge au godet `scoop_charge` | Dragueur de sel | couloir annoncé, course droite (arrêtée par le décor) qui blesse une fois, récupération 1,3 s | `speed`, `length`, `width`, `recover` |
| Éclatement salin `salt_crust_burst` | Dragueur de sel | six éclats en étoile, le premier décalé du Chasseur : un passage reste entre deux éclats | `count`, `length`, `width`, `recover` |

**Saumor** (`data/bosses/saumor.tres`, `draft3d/bosses/saumor.gd`, gardien du chapitre) :

| Phase | Technique | Fonctionnement | Clip |
|---|---|---|---|
| 1 | Appel de la vanne `gate_pull` | après l'annonce, aspiration vers le siphon (3,2 m/s, 2,2 s) ; un obstacle entre le boss et le Chasseur, une Ruée ou la distance la coupent ; morsure du siphon (cercle) à la fin | `gate_pull` |
| 1 et 2 | Écrasement d'épaule `shoulder_slam` | coup lourd au contact (choisi seulement à portée), recul, 1,2 s de récupération | `shoulder_slam` |
| 2 | Balayage saumâtre `brine_sweep` | 7 couloirs qui balaient 110° devant le boss, l'un après l'autre (sens tiré au hasard), abrités par le décor | `brine_sweep` |
| 2 | Explosion du siphon `core_burst` | 1) cercle intérieur de 4,2 m ; 2) 1,1 s plus tard, couronne de 10 disques à 7,2 m : le centre, déjà frappé, devient la zone sûre | `core_burst` |
| transition | ouverture des vantaux | clip `transform`, puis `phase2_idle` / `phase2_move` | `transform` |

Essais : `tests/unit/test_saumatres.gd`. Captures : `docs/previews/saumatres-v2/`.

### Problèmes connus (lot 1)

- La Raie des saumures vole (`flying`) mais suit le sol comme les autres monstres de la v2 (pas de hauteur de vol).
- Les techniques communes des boss (enchaînements, rapprochements) restent actives autour des techniques propres.
