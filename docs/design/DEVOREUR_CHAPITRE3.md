# Glauquemire, Dévoreur des Marais engloutis (carte 15)

Statut : **mécaniques validées par le propriétaire le 26 octobre 2026 et codées** (forme provisoire en attendant les
sprites) ; prompt Codex ci-dessous, à envoyer.
Cadre : [MONSTRES.md](MONSTRES.md) (montée en puissance des boss, mécanique phare de chacun),
[CARTES.md](CARTES.md) (carte 15).

## Idée

Une créature des marais qui a dévoré les temples de cristal-miroir : une bête de vase et de racines (phase 1) qui se
couvre d'une carapace de cristal (phase 2), puis révèle son cœur de Faille sous la marée (phase 3). **Aucune de ses
mécaniques n'existe chez un autre boss** ; il ne reprend que des griffes et un écrasement.

Sa mécanique phare, **les miroirs à orienter**, achève l'apprentissage des deux Dévoreurs précédents : renvoyer une
attaque du boss contre lui (orbes de source, chapitre 1) et lire toute l'arène (séquence des cratères, chapitre 2).

Force : 12 500 PV, plus gros coup 34, défense 34, 3 phases (Dévoreur des Sources 6 500 · 26 · 2, Pyrevorn 9 000 · 30 · 2).

## Phases et mécaniques

| Phase | Seuil | Mécanique | Pour le joueur |
|---|---|---|---|
| 1 · Bête des vases | 100 % | **Vase qui durcit** (`mud_wall`) : trois jets de vase autour du Chasseur ; les flaques ralentissent, puis durcissent en murs 7 s (ils bloquent tout le monde et arrêtent le rayon de prisme) | sortir de la vase ; plus tard, s'en servir d'abri |
| | | **Racine-laisse** (`root_leash`) : une racine attache le Chasseur à un point (laisse de 170) pendant que le boss prépare un coup sur ce point (rayon 150) | casser la racine d'une Ruée, ou s'écarter au bout de la laisse |
| | | **Sangsues nourricières** (`leech_feed`) : 4 sangsues sortent loin du boss et rampent vers lui ; chacune qui l'atteint le soigne de 2 % | les intercepter (moins de dégâts sur le boss pendant ce temps) |
| 2 · Carapace de cristal | 66 % | **Carapace à facettes** (passive `facets`) : quatre faces fixes (droite, bas, gauche, haut) ; une face intacte ne laisse passer que 30 % des coups venus de son côté ; elle se brise après 3,5 % des PV en coups bruts et repousse en 14 s | tourner autour, frapper une face déjà brisée |
| | | **Miroirs à orienter** (passive `mirrors` + attaque `prism_beam`, **mécanique phare**) : quatre miroirs autour du boss. Une Ruée contre un miroir le tourne dans le sens de la Ruée (au huitième de tour près). Le rayon de prisme balaie toute l'arène (un tour en 3,2 s) ; il suit la flèche de chaque miroir qu'il touche. Renvoyé sur le boss (à 30° près) : toutes les faces volent en éclats, étourdi 3 s et dégâts ×2. Au début de chaque rayon, le boss trouble les miroirs | se placer derrière un miroir (il protège du rayon) et s'élancer vers le boss à travers lui |
| 3 · Cœur de la marée | 33 % | **Anneau de marée** (passive `tide_ring`) : l'eau monte depuis les bords, l'arène rétrécit (de 950 à 300) ; hors de l'anneau, l'eau blesse et ralentit ; chaque coup porté au boss fait reculer l'eau | attaquer plutôt que fuir |
| | | **Tourbillon** (`whirlpool`) : aspire le Chasseur, les Échos et les Corrompus vers le boss 4,5 s, puis se referme (coup de 34 au centre) | marcher contre le courant, garder la Ruée pour la fin |
| | | **Engloutissement** (`swallow`) : avale l'Écho le plus proche 8 s ; frapper le boss (5 % de ses PV) le libère et sonne le boss ; sinon l'Écho ressort sonné 4 s | concentrer les coups sur le boss |
| | | Miroirs toujours là ; rayon de prisme double (deux rayons opposés, un demi-tour chacun) | |

Réglages : `data/bosses/glauquemire.tres` (attaques, `mechanic_params` des phases). Code :
`src/entities/bosses/glauquemire_mechanics.gd`. Tests : `tests/unit/test_glauquemire.gd`.

## Planches (6 colonnes, cellules 512 × 512 comme Pyrevorn)

| Planche | Rangées | Usage |
|---|---|---|
| A, 6 × 3 | `idle`, `move`, `claws` | toutes phases (griffes et écrasement) |
| B, 6 × 3 | `mud_spit`, `root_lash`, `leech_call` | phase 1 |
| C, 6 × 2 | `transform` (vase → cristal, puis cristal → cœur), `phase2_idle` | |
| D, 6 × 2 | `prism_beam`, `hurt` (étourdi, carapace brisée) | phase 2 |
| E, 6 × 3 | `phase3_idle`, `whirlpool`, `swallow` | phase 3 |
| F, 6 × 1 | `death` | |

Le jeu dessine lui-même les miroirs, la vase, les murs, la racine, le rayon, l'eau et le tourbillon (formes
provisoires) ; Codex pourra les habiller plus tard (effets peints, comme pour le Dévoreur des Sources).

## Prompt pour Codex

```
Tâche : sprites du Dévoreur du chapitre 3, « Glauquemire » (clé boss.glauquemire), finale des Marais engloutis.
Lis d'abord AGENTS.md (dont « Poids du dépôt »), docs/design/MONSTRES.md, docs/design/DEVOREUR_CHAPITRE3.md,
docs/ART_BIBLE.md et docs/art/PYREVORN_SPRITES.md (même format de livraison). Branche codex/boss-glauquemire depuis
main à jour, PR vers main, poids indiqué. Aucun changement dans src/ ni data/ (le combat est déjà codé).

Créature originale (aucune ressemblance avec une licence existante) : immense bête des marais, corps de vase noire et
de racines, mâchoire de crocodile ancien, dos couvert de lotus pâles et d'éclats de cristal-miroir cyan ; en phase 2,
une carapace de cristal à facettes recouvre son dos et ses pattes avant ; en phase 3, la carapace se fend et laisse
voir un cœur de Faille violet qui pulse sous l'eau. Eau turquoise, mousse émeraude, cristal cyan pâle, violet de la
Faille seulement sur le cœur. Aucun cercle ni zone au sol peint (le jeu les dessine).

Six planches, 6 colonnes, cellules 512 × 512, ancre des pieds [256, 480], hauteur du corps environ 150 pixels d'art,
toutes générées avec la planche A en référence :
A 6×3 idle, move, claws (coup de griffes devant lui) ·
B 6×3 mud_spit (crache trois jets de vase vers le haut), root_lash (plante une racine dans le sol devant lui),
leech_call (gonfle le dos, des sangsues s'en détachent) ·
C 6×2 transform (la vase se couvre de cristal à facettes), phase2_idle (carapace de cristal) ·
D 6×2 prism_beam (gueule ouverte, un prisme de cristal s'allume dans la gorge, tête qui pivote lentement),
hurt (étourdi, carapace qui vole en éclats) ·
E 6×3 phase3_idle (carapace fendue, cœur violet qui pulse), whirlpool (tourne sur lui-même, eau qui s'enroule),
swallow (gueule grande ouverte qui happe puis se referme, ventre qui luit) ·
F 6×1 death (carcasse de vase et de cristal éteint).
Chaque attaque : anticipation lisible → action → retour. Import avec tools/art/import_sheet.py (statut wip pour
validation), GIF par animation et contrôle d'échelle Godot à côté du Chasseur, fiche docs/art/GLAUQUEMIRE_SPRITES.md.
Les noms de rangées doivent correspondre exactement à l'entrée boss.glauquemire du manifeste (attack = claws).
Aperçus légers dans docs/previews/glauquemire/ avec un .gdignore. ARRÊT pour validation du propriétaire après la
planche A, avant les cinq autres.
```
