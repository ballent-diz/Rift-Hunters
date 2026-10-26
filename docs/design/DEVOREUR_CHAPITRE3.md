# Glauquemire, Dévoreur des Marais engloutis (carte 15)

Statut : **proposition de Claude du 26 octobre 2026**, à valider par le propriétaire avant d'envoyer le prompt à Codex.
Cadre : [MONSTRES.md](MONSTRES.md) (boss du chapitre 3 : 3 phases), [CARTES.md](CARTES.md) (carte 15).

## Idée

Une créature des marais qui a dévoré les temples de cristal-miroir : une bête de vase et de racines (phase 1) qui
se couvre d'une carapace de cristal (phase 2), puis révèle son cœur de Faille sous la marée (phase 3). Chaque phase
reprend une mécanique du chapitre, dans l'ordre où le joueur les a découvertes.

| Phase | Seuil | Attaques (code) | Mécanique pour le joueur |
|---|---|---|---|
| 1 · Bête des vases | 100 % | griffes (`sweep`), jet de vase qui laisse une nappe collante (`slam` + vase), appel des sangsues (`summon`), Plongée sous la vase (`blink`) | rester mobile, sortir de la vase |
| 2 · Carapace de cristal | 66 % | reflets (clones, E17), miroir renvoyeur (tirs renvoyés de face), rayon qui balaie (`eye_beam`, coupé par les abris) | frapper par le flanc, se mettre à couvert |
| 3 · Cœur de la marée | 33 % | marée haute permanente sur une partie de l'arène, marque qui explose (E14), envol et chute (`skyfall`) avec anneaux de vase, enchaînements des deux phases précédentes | gérer l'espace qui rétrécit, garder sa Ruée |

## Planches (6 colonnes, 2 ou 3 rangées, cellules 512 × 512 comme Pyrevorn)

| Planche | Rangées | Usage |
|---|---|---|
| A, 6 × 3 | `idle`, `move`, `claws` | phase 1 |
| B, 6 × 3 | `mud_spit`, `leech_call`, `dive` | phase 1 |
| C, 6 × 2 | `crystallize` (transformation 1→2), `phase2_idle` | |
| D, 6 × 3 | `reflections`, `mirror_guard`, `prism_beam` | phase 2 |
| E, 6 × 2 | `rift_heart` (transformation 2→3), `death` | |
| F, 6 × 3 | `phase3_idle`, `tide_call`, `skyfall` | phase 3 |

## Prompt pour Codex

```
Tâche : sprites du Dévoreur du chapitre 3, « Glauquemire » (clé boss.glauquemire), finale des Marais engloutis.
Lis d'abord AGENTS.md (dont « Poids du dépôt »), docs/design/MONSTRES.md, docs/design/DEVOREUR_CHAPITRE3.md,
docs/ART_BIBLE.md et docs/art/PYREVORN_SPRITES.md (même format de livraison). Branche codex/boss-glauquemire depuis
main à jour, PR vers main, poids indiqué. Aucun changement dans src/ ni data/.

Créature originale (aucune ressemblance avec une licence existante) : immense bête des marais, corps de vase noire et
de racines, mâchoire de crocodile ancien, dos couvert de lotus pâles et d'éclats de cristal-miroir cyan ; en phase 2,
une carapace de cristal à facettes recouvre son dos et ses pattes avant ; en phase 3, la carapace se fend et laisse
voir un cœur de Faille violet qui pulse sous l'eau. Eau turquoise, mousse émeraude, cristal cyan pâle, violet de la
Faille seulement sur le cœur. Aucun cercle ni zone au sol peint (le jeu les dessine).

Six planches, 6 colonnes, cellules 512 × 512, ancre des pieds [256, 480], hauteur du corps environ 150 pixels d'art,
toutes générées avec la planche A en référence :
A 6×3 idle, move, claws · B 6×3 mud_spit, leech_call, dive · C 6×2 crystallize, phase2_idle ·
D 6×3 reflections, mirror_guard, prism_beam · E 6×2 rift_heart, death (carcasse de vase et de cristal éteint) ·
F 6×3 phase3_idle, tide_call, skyfall.
Chaque attaque : anticipation lisible → action → retour. Import avec tools/art/import_sheet.py (statut wip pour
validation), GIF par animation et contrôle d'échelle Godot à côté du Chasseur, fiche docs/art/GLAUQUEMIRE_SPRITES.md.
Aperçus légers dans docs/previews/glauquemire/ avec un .gdignore. ARRÊT pour validation du propriétaire après la
planche A, avant les cinq autres.
```
