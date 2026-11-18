# Fiches visuelles des mutations des six sorts v2 — à produire par Codex (planches PixelFX)

Complète `docs/design/FICHES_VFX_GAMEPLAY_V2.md` (conventions communes : vue 2,5D à 46°, sprites face caméra, effets
au sol en ellipse aplatie ≈ 0,7, pixel art lumière haut-gauche et liseré violet bas-droite, fond transparent, sans
texte, ≈ 64 px par mètre). Claude Code ne dessine rien : ces fiches décrivent ce que le jeu attend. Code des sorts :
`draft3d/rift_spells.gd` (Pluie : zone dans `draft3d/spells.gd`, `_step_zones`).

## 1. Convention de nommage et raccord

- **Identifiant** : `mutation_<id de la carte de mutation>`, l'id étant le nom du fichier `draft3d/spells/<id>.tres`
  (`mark_execute` → `mutation_mark_execute`). Même logique que `combo_<id>` et `passive_<id>`.
- **Fichiers** : `assets/vfx/pixelfx/<identifiant>/violet.png` + `violet.json` (format PixelFX du dépôt :
  `frames[].frame {x, y, w, h}` dans l'ordre de lecture, `meta.pixelfx {fps, loop, frames, frameSize, columns}`).
  Une seule famille (`violet`) : la palette ne dépend pas de l'ennemi.
- **Raccord** : déposer les deux fichiers suffit, puis `godot --headless --import --path .`. Le jeu met la première
  image à la **largeur en jeu** de la fiche (`DraftPixelFx.size_for`) ; seules proportions et lisibilité comptent.
- **Repli** : tant qu'une planche manque, le jeu joue exactement l'effet actuel (colonne « Repli »). Quand il n'y a
  rien aujourd'hui (« aucun »), il n'affiche rien de plus. Code : `DraftRun.fx_or` (avec repli) et
  `DraftPixelFx.dedicated` (sans repli).
- **Télégraphes ennemis** : les effets dédiés au sol sont dessinés en priorité `DraftPixelFx.UNDER_TELEGRAPHS` (-1),
  sous les zones annoncées des ennemis (priorité 0). Les effets ancrés sur un ennemi ou le Chasseur
  (`DraftPixelFx.OVER_TARGET`) partagent la priorité des personnages pour ne pas être cachés par leur cible, et tout
  effet dédié est avancé vers la caméra pour ne pas être coupé par le sol (validation :
  `docs/design/VALIDATION_FX_COMPETENCES_V2.md`). Les effets au sol (Ombre piégée, Orage) doivent rester **translucides au
  centre** (alpha ≤ 50 % hors du bord) et ne jamais utiliser le rouge ni l'orange des zones ennemies.
- **Contrôle** : `python3 tools/art/check_v2_vfx.py` (images, fps, boucle, cohérence de la planche). Test du raccord :
  `tests/unit/test_draft3d_mutation_vfx.gd`.

## 2. Inventaire des FX existants et décision par mutation

| Sort | Mutation (carte) | FX actuel | Effet distinct ? | Raison |
|---|---|---|---|---|
| Marque du traqueur | Exécution (`mark_execute`) | `dark_explosion` violet, identique aux explosions d'ombre | **oui** | Le coup de grâce (≤ 20 % PV) doit se distinguer d'une explosion ordinaire |
| Marque du traqueur | Traque (`mark_hunt`) | aucun : le sceau `hex_sigil` saute sans transition | **oui** | Le transfert de la marque est invisible aujourd'hui |
| Fente du vide | Double fente (`rend_double`) | même fente que la base | non | Seconde fente = même geste ; la fenêtre gratuite est déjà lisible sur la barre de sorts |
| Fente du vide | Fente perçante (`rend_pierce`) | `hit` sur chaque ennemi, comme la base | **oui** | Montrer que la fente traverse toute la ligne |
| Pas de faille | Deux charges (`step_charges`) | même téléportation (`blink_out` / `blink_in`) | non | Les charges sont affichées par la barre de sorts |
| Pas de faille | Ombre piégée (`step_trap`) | `dark_explosion`, identique à la base | **oui** | Le ralentissement laissé doit se voir à l'éclatement |
| Onde de stase | Éclats de stase (`stasis_shards`) | aucun repère sur les ennemis exposés | **oui** | Le bonus de dégâts (+20 %) n'a aucun signe |
| Onde de stase | Onde circulaire (`stasis_circle`) | `frost_nova` centré sur le Chasseur | non | `frost_nova` est déjà une nova circulaire |
| Pluie d'éclats | Orage (`rain_storm`) | `star_fall` ponctuels, aucune zone visible | **oui** | Montrer que la zone suit le Chasseur |
| Pluie d'éclats | Concentration (`rain_focus`) | `star_fall`, identique à la base | **oui** | Impacts plus lourds sur une zone plus petite |
| Voile de cendre | Voile mobile (`veil_mobile`) | `smoke_bomb` qui suit déjà le Chasseur | non | Le nuage suit déjà le Chasseur |
| Voile de cendre | Contrecoup (`veil_recoil`) | `smoke_puff` à chaque tir détruit | **oui** | Le soin rendu par chaque tir bloqué n'est pas visible |

## 3. Fiches techniques (8 animations)

| ID (dossier) | Déclencheur | Effet à montrer | Largeur en jeu | Durée · images · fps | Boucle | Ancrage | Repli |
|---|---|---|---|---|---|---|---|
| `mutation_mark_execute` | La cible marquée passe sous 20 % PV (Exécution) ; une fois, sur la cible | Le sceau se referme en lame verticale qui tombe sur la cible, flash blanc-violet (40-55 %), éclats sombres qui retombent | 2,2 m | 0,5 s · 12 · 24 | non | centre de la cible, 0,6 m au-dessus du sol | `dark_explosion` |
| `mutation_mark_hunt` | La cible marquée meurt et la marque saute sur l'ennemi le plus proche (Traque) ; sur le nouvel ennemi | Sceau violet qui se « verrouille » : anneau qui se contracte puis petit éclair vers le haut, vers le sceau `hex_sigil` (1,6 m) | 1,6 m | 0,4 s · 8 · 20 | non | centre du nouvel ennemi, 1,0 m au-dessus du sol | aucun |
| `mutation_rend_pierce` | Fente perçante : chaque ennemi traversé | Déchirure horizontale fine (violet sombre, cœur blanc), traits qui traversent de part en part ; non orientée (le jeu ne la tourne pas) | 1,6 m | 0,25 s · 6 · 24 | non | centre de l'ennemi, 0,6 m au-dessus du sol | `hit` |
| `mutation_step_trap` | Ombre piégée : l'ombre laissée au départ éclate (1 s après) | Ellipse d'ombre au sol qui éclate, puis vrilles/chaînes d'ombre qui restent 2-3 images (ralentissement) ; bord net, centre translucide | 2 × rayon de l'ombre (≈ 2,7 m) | 0,6 s · 12 · 20 | non | point de départ, 0,3 m au-dessus du sol | `dark_explosion` |
| `mutation_stasis_shards` | Éclats de stase : chaque ennemi figé (8 au plus par onde) | Fissures de givre cyan qui apparaissent sur un cristal autour de l'ennemi puis se figent (signe « vulnérable ») | 1,2 m | 0,5 s · 8 · 16 | non | centre de l'ennemi, 0,9 m au-dessus du sol | aucun |
| `mutation_rain_storm` | Orage : toute la durée de la Pluie (3 s), la zone suit le Chasseur | Ellipse au sol d'éclats tournoyants (cyan `#8fe6ff` et violet), bord marqué, centre très translucide ; se superpose bien à elle-même | 2 × rayon de la zone (6 m) | 0,8 s · 8 · 10 (cycle) | **oui** (retiré avec la zone) | Chasseur, 0,3 m au-dessus du sol | aucun |
| `mutation_rain_focus` | Concentration : chaque éclat qui tombe (toutes les 0,4 s) | Éclat lourd qui s'écrase : trait vertical cyan épais, impact en étoile et petite onde au sol | 1,6 m | 0,33 s · 8 · 24 | non | point d'impact, 0,8 m au-dessus du sol | `star_fall` |
| `mutation_veil_recoil` | Contrecoup : chaque tir ennemi détruit par le voile | Le tir se dissout en cendre puis une étincelle or-verte part vers le haut (soin) | 1,2 m | 0,4 s · 8 · 20 | non | position du tir détruit | `smoke_puff` (calcinés) |

Taille d'image conseillée (64 px/m) : 140 px (Exécution), 104 px (Traque, Perçante, Concentration), 176 px
(Ombre piégée), 80 px (Éclats, Contrecoup), 384 px (Orage).

## 4. Liste finale des FX à créer

```
assets/vfx/pixelfx/mutation_mark_execute/violet.png + violet.json
assets/vfx/pixelfx/mutation_mark_hunt/violet.png + violet.json
assets/vfx/pixelfx/mutation_rend_pierce/violet.png + violet.json
assets/vfx/pixelfx/mutation_step_trap/violet.png + violet.json
assets/vfx/pixelfx/mutation_stasis_shards/violet.png + violet.json
assets/vfx/pixelfx/mutation_rain_storm/violet.png + violet.json
assets/vfx/pixelfx/mutation_rain_focus/violet.png + violet.json
assets/vfx/pixelfx/mutation_veil_recoil/violet.png + violet.json
```

Pas d'effet dédié pour Double fente, Deux charges, Onde circulaire et Voile mobile (raisons ci-dessus).
Retour attendu de Codex : les deux fichiers par effet et une capture de contrôle de l'animation ; Claude Code intègre,
ajuste largeur ou ancrage si besoin et fournit des captures en jeu.
