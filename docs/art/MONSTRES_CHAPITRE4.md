# Chapitre 4 — Le Glacier silencieux : livraison des sprites

Lot demandé le 2 novembre 2026. **14 ennemis, Nivorath et un brasero**, 31 planches retenues, 69 animations peintes et **414 poses**. Les noms et gestes suivent les fiches du commit `7605b92247b98e812e9a643f7cfdd24d49237122` de `claude/utiliser-mon-git-oofk0o`, lu sans fusionner son code. Base initiale : `main` à `858c88b9d229bcb55df0fb22b3a004358420349b`, puis actualisation sur `e7701e9` (PR #89). Les fiches de référence sont désormais fusionnées dans `main` ; leurs entrées prévues sont remplacées par ces imports sans perdre les changements de gameplay.

## Format et catalogue

Ennemis et brasero : cellules 256 × 256, ancre (128, 238), échelle 0,5. Nivorath : cellules 512 × 512, ancre (256, 480), même échelle. Les hauteurs demandées en unités du monde deviennent le double en pixels d’art. Les deux volants ont un retrait de 14 pixels d’art au-dessus de l’ancre.

| Identifiant | Nom | Taille monde | Animations peintes |
|---|---|---:|---|
| `enemy.frost_crawler` | Rampe-givre | 30 | `move`, `attack` |
| `enemy.blizzard_wolf` | Loup de blizzard | 38 | `move`, `attack`, `slide` |
| `enemy.snow_wraith` | Spectre de neige | 30 | `move`, `attack` |
| `enemy.ice_golem` | Golem de glace | 46 | `move`, `attack` |
| `enemy.frost_shaman` | Chaman du gel | 60 | `move`, `attack`, `death`, `ice_prison`, `frost_mist`, `snuff` |
| `enemy.peak_yeti` | Yéti des cimes | 70 | `move`, `attack`, `death`, `avalanche`, `pounce`, `rage` |
| `enemy.rime_archer` | Archère du givre | 56 | `move`, `attack`, `death`, `chilling_arrow`, `hail_volley`, `fade` |
| `enemy.hush_shard` | Éclat du silence | 30 | `move`, `attack` |
| `enemy.ice_knight` | Chevalier de glace | 42 | `move`, `attack` |
| `enemy.frozen_sentry` | Sentinelle gelée | 40 | `move`, `attack` |
| `enemy.icebreaker` | Brise-banquise | 40 | `move`, `attack`, `dive` |
| `enemy.silence_herald` | Héraut du silence | 62 | `move`, `attack`, `death`, `hush`, `spell_echo`, `absorb` |
| `enemy.frost_mammoth` | Mammouth de givre | 76 | `move`, `attack`, `death`, `charge`, `ice_crack`, `armor_break` |
| `enemy.snow_witch` | Sorcière des neiges | 58 | `move`, `attack`, `death`, `blizzard_call`, `snow_clones`, `blink` |
| `boss.nivorath` | Nivorath, le Silence du Glacier | 150 | `idle`, `move`, `attack`, `claw`, `ice_spikes`, `blizzard_breath`, `spell_capture`, `spell_release`, `death`, `transform`, `shatter_floor`, `frozen_dive` |
| `object.brazier` | Brasero | 48 | `lit`, `dim`, `out` |

Les normaux disposent de `idle` comme alias de `move` et d’une pose de mort transparente pour la dispersion commune. Les élites ont leur mort dans A ; `idle` est aussi un alias de `move`. Ces alias et poses vides ne sont pas comptés dans les 414 dessins. Les 12 animations de Nivorath, dont `attack` et `claw`, sont toutes peintes séparément. Le brasero a `lit` et `dim` en boucle, `out` sans boucle.

## Planches, échelle et sources

A a deux ou trois rangées selon le rang. B regroupe les deux techniques des élites. C porte leur troisième geste dans sa première rangée ; la seconde est un remplissage transparent, sans animation inventée, pour garder le format 6 × 2. Nivorath utilise quatre planches 6 × 3. Chaque planche complémentaire a été générée avec A en référence.

Les sources retenues, prompts exacts, SHA-256 et facteurs communs de normalisation sont dans `assets/concepts/incoming/<identifiant>/source/`. Les 16 `job.json` utilisent le pipeline commun : alpha, contour, `anchor_mode: mass`, 32 couleurs. `source_scale` est fixé par planche, pas par pose : une mort affaissée ne regonfle pas. Les facteurs mesurés sont joints dans `normalization.json` et dans le rapport qualité. Aucun essai intermédiaire n’est versionné.

Le contrôle a révélé un dépassement du budget dans `import_sheet.py` : 32 couleurs demandaient 33 couleurs de palette, puis un contour, soit 34. Le correctif réserve le contour dans le budget de 32 ; toutes les sorties de ce lot ont été réimportées et contrôlées. Les autres sprites existants ne sont pas régénérés.

Pour réimporter une recette conservée :

```bash
source /workspace/.rift-tools/activate.sh
cd /workspace/Rift-Hunters
python3 tools/art/import_sheet.py assets/concepts/incoming/enemy.frost_crawler/job.json
godot --headless --import --path .
tools/run_tests.sh assets
tools/run_tests.sh art
```

## Préservation de main lors du merge du 3 novembre

`origin/main` (`41c6850`, PR91 fusionnée) est intégré par merge, sans rebase ni force-push. Le manifeste reprend toutes les entrées de main, dont les cartes13/14, `object.training_dummy`, `object.crystal_mirror` et les objets miroirs. Seules les entrées des quatorze ennemis du chapitre4, de Nivorath et du brasero reçoivent la livraison originale en statut `final`, avec leurs feuilles et icônes.

Les six scènes d’effets présentes dans main, ainsi que leur catalogue, sont conservées : aucun retrait d’entrée ou de fichier hors du lot de sprites. Les deux côtés du conflit ROADMAP restent présents. Tous les fichiers de `src/`, `data/`, des objets miroirs et de la carte14 restent identiques à main.

## Contrôles et aperçus

Actualisation du 3 novembre, après merge :

- Godot **4.3** : `godot --headless --import --path .` réussi, sans erreur de script ou de chargement.
- `tools/run_tests.sh assets` : **447 entrées, 445 valides, 2 placeholders, zéro erreur**.
- Chapitre4 : **16 livraisons finales**, aucune entrée encore `planned` parmi les quatorze monstres, Nivorath et le brasero.
- Restent `planned` hors chapitre4 : `object.training_dummy` (salle d’entraînement) et `object.crystal_mirror` (chapitre3), conservés comme dans main.
- Identité des **142 fichiers d’art, sources et recettes** vérifiée par SHA256 avec la branche originale au commit `337f3b1` : aucun sprite redessiné, aucune réimportation Python ni modification de cellule.
- Tous les identifiants de main sont conservés ; toutes ses entrées hors des seize livraisons sont identiques. Les six scènes d’effets auparavant retirées par la branche restent celles de main.

[Rapport après merge](../previews/monstres-chapitre-4/controle_apres_merge.json) · [Journal assets](../previews/monstres-chapitre-4/assets-apres-merge.log) · [Import](../previews/monstres-chapitre-4/godot-import-apres-merge.log).

L’audit graphique initial reste joint : 16 visuels, 414 poses, marges et ancres contrôlées, 32 couleurs opaques au plus. Les six séquences Godot et les GIF de moins de 3 Mo restent ceux de la livraison originale ; ils n’ont pas été régénérés pour ce merge.

Les deux familles et les quatre groupes d’animations de Nivorath sont dans [`docs/previews/monstres-chapitre-4/`](../previews/monstres-chapitre-4/). `qualite.json` détaille chaque animation et chaque pose. Le banc montre les vrais fichiers du manifeste à un zoom du monde de 1,8 ; il ne prétend pas être une partie du chapitre 4.

## Récapitulatif pour revue

- **Livré** : bestiaire fixé, Nivorath, brasero, recettes et sources retenues, préservation des entrées de main, aperçus et contrôles.
- **Non fait** : raccordement temporel des techniques et du brasero, essais de campagne par le propriétaire. Les fiches du chapitre 4 ont été fusionnées séparément par la PR #89. Aucun code dans `src/` ni règle de `data/` modifié.
- **Choix faits sans validation** : détails de silhouette dans le bestiaire imposé, retrait de 14 px pour les deux volants, seconde rangée transparente des planches C, facteurs de cadrage documentés. La palette reste glace bleue/blanche et Faille violette, sans lave ni vert de marais.
- **Raccords Claude** : ses fiches sont conservées telles que fusionnées dans `main` ; piloter les animations existantes et les trois états du brasero. Les cercles d’alerte et zones de gameplay restent au code.

`final` protège les sprites d’un remplacement procédural ; ce statut ne constitue pas une validation artistique du propriétaire.

Poids des fichiers ajoutés ou modifiés : environ **83.57 Mo**, inférieur à 150 Mo ([rapport](../previews/monstres-chapitre-4/poids-apres-merge.json)).
