Tâche : cartes 9 et 10 du chapitre 2 « Les Terres dévastées » — composition puis, après validation du
propriétaire seulement, passe de régions. Deux cartes indépendantes (une branche et une pull request par carte).

Lis d'abord : AGENTS.md, docs/maps/GENERER_UNE_CARTE.md (§ 1 bis « Variété » : obligatoire),
docs/maps/QUALITE_DES_CARTES.md, docs/design/DIFFICULTE.md, docs/maps/LISIERE_CALCINEE.md (livraison des plaques),
et les fiches des cartes 7 et 8 pour ne pas en reprendre les plans. Aucun changement dans src/ ni data/ : Claude
code les mécaniques et les niveaux.

Montée en puissance du chapitre : la carte 9 fait **revenir la lave**, la carte 10 est la **finale volcanique**.
Les abris restent demandés par le propriétaire : 3 à 5 gros blocs de roche par carte dans les zones (≥ 120 unités,
espacés d'au moins 350, jamais sur les routes).

---

## Carte 9 — « Coulées de braise » (id `ember_flows`)

### Mécanique de carte (codée par Claude) : coulées de lave qui débordent

Des **chenaux de lave** traversent la carte : la lave elle-même est infranchissable. Le long de certains chenaux,
des **lits de débordement** (croûte de lave refroidie, noire et fissurée, **praticable**) se remplissent de lave
à intervalles : alerte visible (la croûte rougeoie, la lave monte), puis débordement qui blesse fort tout ce qui s'y
trouve et laisse derrière lui des plaques brûlantes pendant quelques secondes. Le Chasseur en sort par le côté ou
par la Ruée ; les Corrompus attirés dessus sont ravagés. C'est le retour de la lave, plus impactant : il coupe des
routes pendant quelques secondes et change le terrain sous les pieds.

### Format, identité et plan

Format **panorama 3:1** (monde 5016 × 1672, composition 1536 × 512), parcours **de droite à gauche** (l'inverse des
cartes 1 et 6). Mode prévu : **fermeture de failles** (4 failles à refermer), puis gardien.

Identité : roche noire et basalte brun, cendre, **rivières de lave orange vif** (la lave fait son retour : c'est le
seul orange vif, avec les lits de débordement en alerte), fumées, quelques ruines englouties à moitié. Violet discret.

| Repère | X,Y % | Intention |
|---|---|---|
| Départ | 92,55 | replat sûr à droite, aucun chenal à moins de 12 % |
| Faille 1 | 74,35 | sur un plateau de basalte |
| Faille 2 | 55,70 | dans une cuvette entourée de deux chenaux |
| Faille 3 | 36,30 | sur une île de roche reliée par deux ponts de basalte |
| Faille 4 | 18,65 | près d'une ruine engloutie |
| Combat final | 8,40 | **pas d'arène** : grande étendue libre au bord gauche, le jeu dessine le cercle d'énergie |

- 3 chenaux de lave principaux, de travers (pas parallèles), avec **5 à 6 lits de débordement** praticables le long
  d'eux, de 150 à 250 unités de large et 500 à 1000 de long.
- Chaque chenal se traverse par au moins **deux ponts ou gués de basalte** solides ; un débordement ne doit jamais
  bloquer la seule route : il y a toujours un détour sûr.

Livrables propres à la mécanique : `flows.png` (mêmes dimensions que la composition puis que la carte finale ;
noir = rien ; **une couleur pure par lit de débordement** ; enveloppe de la croûte praticable seulement) et le tableau
des lits dans la fiche `docs/maps/COULEES_DE_BRAISE.md` (centre, longueur, largeur, sens du flot).

### Prompt de composition (anglais)

```
Top-down video game map for Rift Hunters, a 2D survivor-like. ONE complete continuous full-bleed 3:1 panorama,
1536 x 512 pixels, no borders, no text, no UI, no characters. COMPOSITION ONLY.
STYLE REFERENCES ONLY (art language, NOT layout): image1 Waterfall Ruins, image2 Scorched Verge, image3 Ash Vents.
Theme: EMBER FLOWS, chapter 2 THE DEVASTATED LANDS: black rock and brown basalt, ash, three slanted rivers of
bright orange LAVA crossing the map (not parallel), smoke, half-sunken ruins, restrained violet.
Along the lava rivers, five or six broad flat OVERFLOW BEDS of cooled black cracked lava crust, walkable, 150-250
units wide. Each lava river is crossed by at least two sturdy basalt bridges or fords.
Route from RIGHT to LEFT: safe start ledge at (92,55); basalt plateau (74,35); basin between two rivers (55,70);
rock island linked by two basalt bridges (36,30); half-sunken ruin (18,65); huge open area at the left edge (8,40),
NO arena, NO plaza. Inside the zones: 3 to 5 large boulders big enough to hide behind, spread apart, never on roads.
Bright orange ONLY for the lava itself. At least 50% flat open walkable ground. Clear sharp boundaries between lava,
cliffs and walkable rock. Uniform steep overhead game camera, top-left light.
```

---

## Carte 10 — « Cœur du volcan » (id `volcano_heart`), finale du chapitre

### Mécanique de carte (codée par Claude) : pluie de roches magmatiques

Pendant toute la partie, des **roches magmatiques tombent au hasard** sur la carte : chaque chute est annoncée par
une ombre et un cercle au sol, puis la roche s'écrase (dégâts à tout le monde, Corrompus compris) et laisse une petite
plaque brûlante. La cadence augmente au fil des zones et pendant le combat contre Pyrevorn. Elle **s'ajoute** aux
lits de débordement de la carte 9 (2 à 3 lits ici aussi) : la finale combine les deux mécaniques du chapitre.
**Rien à peindre pour les roches** : ombres, cercles, roches et impacts sont dessinés par le jeu.

### Format, identité et plan

Format **1:1** (monde 5016 × 5016, composition 1536 × 1536), parcours **en spirale qui monte** vers le cratère
(ni droite ni U ni zigzag). Mode : vagues par zone, puis **Pyrevorn** (Dévoreur du chapitre 2).

Identité : paysage volcanique, roche noire, lave orange vif en lacs et rivières, ciel de cendres (bords de carte
sombres et fumants), lueurs rouges sur la roche. Le plus spectaculaire du chapitre, sans perdre la lisibilité du sol.

| Repère | X,Y % | Intention |
|---|---|---|
| Départ | 50,92 | pied du volcan, au sud |
| Zone 1 | 22,70 | coulée refroidie, large, ouest |
| Zone 2 | 30,25 | terrasses de basalte, nord-ouest |
| Zone 3 | 76,30 | flanc est, champs de cendre |
| Arène | 55,52 | **la caldeira** au centre : un **anneau de roche en croissant** autour d'un lac de lave (le lac n'est pas praticable), largeur de l'anneau ≥ 500 unités, longueur ≥ 1800 ; une seule montée large depuis la zone 3 ; deux grosses aiguilles de roche comme abris, décalées |

- Les passages entre zones sont des **rampes taillées** et des **cols** entre les coulées, courts et nets.
- 2 à 3 lits de débordement (comme la carte 9) près des passages ; même livrable `flows.png`.
- L'arène doit laisser de la place au boss (envols, souffles) : l'anneau est large et dégagé.

### Prompt de composition (anglais)

```
Top-down video game map for Rift Hunters, a 2D survivor-like. ONE complete continuous full-bleed SQUARE composition,
1536 x 1536 pixels, no borders, no text, no UI, no characters. COMPOSITION ONLY.
STYLE REFERENCES ONLY (art language, NOT layout): image1 Waterfall Ruins, image2 Scorched Verge, image3 Ember Flows.
Theme: VOLCANO HEART, finale of chapter 2: volcanic landscape, black rock, bright orange lava lakes and rivers,
red glows on the rock, ash sky darkening and smoking the map edges. Spectacular but the walkable ground stays
clearly readable. Restrained violet rift cracks near the summit.
Route SPIRALING UP towards the crater: start at the volcano foot (50,92); wide cooled lava flow to the west (22,70);
basalt terraces to the north-west (30,25); ash fields on the east flank (76,30); the final ARENA is the CALDERA in the
center (55,52): a broad CRESCENT-shaped ring of flat rock around a central lava lake (the lake is not walkable), ring
at least 500 units wide and 1800 long, one broad ramp up from the east flank, two large rock spires as cover, offset.
Short clean carved ramps and passes between zones. Two or three broad OVERFLOW BEDS of cooled cracked lava crust
(walkable) near the passes. Inside the zones: 3 to 5 large boulders big enough to hide behind, never on roads.
NOT a round plaza, NOT a square. At least 50% flat open walkable ground. Clear sharp boundaries between lava,
cliffs and walkable rock. Uniform steep overhead game camera, top-left light.
```

### Livraison (les deux cartes)

Étape 1 : composition + fiche (`docs/maps/COULEES_DE_BRAISE.md`, `docs/maps/COEUR_DU_VOLCAN.md`) + `flows.png`
provisoire, **arrêt pour validation du propriétaire**. Étape 2 après validation : régions, `check_map_quality.py`
conforme, contrôle de netteté, tuiles finales, `flows.png` final aux dimensions de la carte. Aperçus dans
`docs/previews/<carte>/` avec un `.gdignore`.
