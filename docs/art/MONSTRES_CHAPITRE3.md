# Chapitre 3 — livraison des sprites de monstres

Fiche de livraison, établie le 28 octobre 2026 à partir des 14 `job.json` et des fiches `data/enemies/*.tres` du checkout `Rift-Hunters-c3-sprites`, lus sans modification. Les noms français et anglais ci-dessous reprennent les clés `ENEMY_*_NAME` de `i18n/strings.csv` dans `origin/main`, consulté avec `git show`.

Le lot comprend **14 monstres, 25 planches retenues, 54 animations peintes et 324 poses**. Ces nombres excluent les alias et les frames vides de mort commune. L’audit de découpage communiqué par l’agent principal indique qu’aucune frame ne touche un bord de cellule. Les contrôles finaux sont terminés : import Godot, assets et art verts ; résultats et limites détaillés en fin de fiche.

## Format et taille en jeu

Toutes les sorties utilisent des cellules de **256 × 256 pixels d’art**, une ancre **(128, 238)** et une échelle de manifeste **0,5**. Les hauteurs cibles d’import sont le double des hauteurs en unités de jeu indiquées dans le tableau. Cette différence exprime la densité d’art choisie, pas un agrandissement des règles ou des hitboxes.

Dans l’ordre des familles : Enlisés **30, 36, 30, 40, 60, 66, 62** unités ; Reflets **30, 40, 44, 36, 60, 72, 58** unités. Les deux volants, `rift_gnat` et `wandering_shard`, utilisent `hover: 14`, soit **14 pixels d’art** au-dessus de l’ancre ; leur fiche conserve `flying = true`. La Chasseresse conserve `stealth_range = 320.0`.

Chaque animation peinte comporte six frames. Les planches ont six colonnes et au plus trois rangées. Pour tous les monstres, `idle` est un alias de `move`. Les huit normaux n’ont pas de mort peinte : une frame vide permet au système de mort commune de prendre le relais. Les six élites disposent d’une mort peinte dans A.

## Catalogue et raccords

Les identifiants d’animation sont ceux des jobs et des données ennemies. Les intervalles ci-dessous sont les `min_range–max_range` des techniques dans les fiches actuelles, en unités de jeu ; ils ne représentent ni la taille du sprite ni nécessairement le rayon d’effet. Les valeurs 9999 servent de portée non restrictive dans ces données. Les animations de trait complètent les techniques nommées dans les fiches.

| Identifiant | Nom FR / EN | Rang ; taille | Animations peintes | Portées de déclenchement ; raccord Claude | Volant / furtif |
|---|---|---|---|---|---|
| `enemy.mire_leech` | Sangsue des vases / Mire Leech | Normal ; 30 | A : `move`, `attack` | Attaque de base ; mort commune | Non / non |
| `enemy.bloat_toad` | Crapaud-gonfle / Bloat Toad | Normal à technique ; 36 | A : `move`, `attack`, `leap` | `leap` → `mud_leap`, 180–480 ; saut boueux et effet associé | Non / non |
| `enemy.rift_gnat` | Moustique de faille / Rift Gnat | Normal ; 30 | A : `move`, `attack` | Attaque de base ; mort commune ; conserver le survol du décor | Oui, hover 14 / non |
| `enemy.creeping_root` | Racine rampante / Creeping Root | Normal à technique ; 40 | A : `move`, `attack`, `plunge` | `plunge` → `burrow`, 220–650 ; enfouissement et réapparition | Non / non |
| `enemy.spore_mother` | Mère-spore / Spore Mother | Élite ; 60 | A : `move`, `attack`, `death` ; B : `spore_mark`, `spore_carpet` ; C : `pulse` | `spore_mark` → `mark`, 0–560 ; `spore_carpet` → `burn_slam`, 0–420 ; `pulse` → `heal_aura`, 0–9999 | Non / non |
| `enemy.bark_warden` | Gardien d'écorce / Bark Warden | Élite ; 66 | A : `move`, `attack`, `death` ; B : `roots`, `bark_shield` ; C : `armor_break` | `roots` → `web`, 150–460 ; `bark_shield` → `ally_shield`, 0–700 ; raccorder le trait `armor_break` à l’ouverture de l’armure prévue | Non / non |
| `enemy.marsh_maw` | Gueule des marais / Marsh Maw | Élite ; 62 | A : `move`, `attack`, `death` ; B : `dive`, `belly_charge` | `dive` → `burrow`, 220–620 ; `belly_charge` → `charge`, 160–520 ; `rage` → `rage`, 0–9999, **alias de `attack` + effet PR78** | Non / non |
| `enemy.wandering_shard` | Éclat errant / Wandering Shard | Normal ; 30 | A : `move`, `attack` | Attaque de base ; mort commune ; conserver le survol du décor | Oui, hover 14 / non |
| `enemy.glass_sentinel` | Sentinelle de verre / Glass Sentinel | Normal ; 40 | A : `move`, `attack` | Attaque de base à distance ; mort commune | Non / non |
| `enemy.quartz_golem` | Golem de quartz / Quartz Golem | Normal ; 44 | A : `move`, `attack` | Attaque de base ; mort commune | Non / non |
| `enemy.creeping_mirror` | Miroir rampant / Creeping Mirror | Normal à technique ; 36 | A : `move`, `attack`, `blink` | `blink` → `blink`, 120–500 ; saut de reflet | Non / non |
| `enemy.mirror_priestess` | Prêtresse-miroir / Mirror Priestess | Élite ; 60 | A : `move`, `attack`, `death` ; B : `reflections`, `mirror_guard` ; C : `blink` | `reflections` → `clones`, 0–600 ; `mirror_guard` → `reflect`, 0–500 ; `blink` → `blink`, 0–9999, déclenchement `on_hits: 6` | Non / non |
| `enemy.crystal_colossus` | Colosse de cristal / Crystal Colossus | Élite ; 72 | A : `move`, `attack`, `death` ; B : `beam`, `shard_burst` ; C : `exposed_core` | `beam` → `sweep_beam`, 0–600 ; `shard_burst` → `shard_fan`, 120–520 ; raccorder `exposed_core` à la fenêtre faible après le rayon | Non / non |
| `enemy.reflection_huntress` | Chasseresse des reflets / Reflection Huntress | Élite ; 58 | A : `move`, `attack`, `death` ; B : `chain_leap`, `prism_mark` ; C : `reveal` | `chain_leap` → `blink`, 100–600, trois sauts ; `prism_mark` → `mark`, 0–520 ; alias `stealth` → `reveal`, à synchroniser avec la furtivité | Non / oui, seuil 320 |

La Gueule des marais n’a **pas de planche C** : son trait de rage réemploie `attack` et l’effet PR78. Cette réutilisation est déclarée dans `aliases`, elle ne compte pas comme une animation peinte supplémentaire.

Les gestes peints ne changent aucune règle de combat, aucun délai, dégât, rayon, seuil ou portée. Les effets de la PR78 sont déjà fusionnés ; leur raccord temporel aux nouvelles animations reste à effectuer par Claude. Les cercles d’alerte et zones au sol restent produits par le jeu. Les traits `armor_break`, `exposed_core` et `reveal` demandent leur raccord au comportement concerné ; leur présence dans une planche n’atteste pas à elle seule ce raccord.

## Échelle commune entre les planches

La modification de `tools/art/import_sheet.py` ajoute **`source_scale` par animation**. Le facteur général est calculé une fois à partir de l’animation de référence et de `target_height`. `source_scale` multiplie ce facteur pour compenser un cadrage source différent entre A, B et C. Il reste fixe pendant toute l’animation : il ne redimensionne pas chaque pose selon sa propre hauteur.

Les facteurs B/C ont été déterminés par comparaison des poses de retour au repos avec A, afin de conserver la même taille corporelle malgré les marges différentes des sources. Les valeurs exactes figurent dans les jobs ; A reste à 1. Aucun changement de `scale` du manifeste n’est nécessaire.

| Monstre | `source_scale` B | `source_scale` C |
|---|---:|---:|
| Mère-spore | 0.808219 | 0.732270 |
| Gardien d'écorce | 0.746130 | 0.653117 |
| Gueule des marais | 0.714286 | — |
| Prêtresse-miroir | 0.684211 | 0.568306 |
| Colosse de cristal | 0.823741 | 0.625683 |
| Chasseresse des reflets | 0.853372 | 0.723881 |

Le test ajouté à `tools/art/test_import.py` construit des sources de tailles différentes et attend les hauteurs `[40, 40, 10]` : le vivant et l’attaque doivent conserver la même hauteur finale, tandis que la mort affaissée reste basse. Ce test protège contre le regonflement artificiel de la mort. Sa présence a été vérifiée à la lecture ; son résultat d’exécution appartient au bilan final ci-dessous.

## Provenance et transparence

Le dernier brief de la journée autorise la génération de remplacement lorsque les octets des archives Work ne peuvent pas être récupérés. Une lecture de l’archive était possible, mais pas l’accès à ses fichiers image : les sources retenues ici sont donc des **remplacements générés ce jour avec l’outil intégré imagegen**, avec demande de fond réellement transparent. Elles ne doivent pas être présentées comme des images importées depuis l’archive Work.

Les sources retenues, les prompts exacts, les informations de normalisation et les SHA-256 sont conservés dans `assets/concepts/incoming/enemy.<id>/source/` ; les `job.json` voisins décrivent les sources, rangées, grilles, alias et facteurs utilisés. Les réglages d’import demandent `background: alpha` et ne remplacent pas la provenance par un détourage prétendument issu de Work. Les essais non retenus restent hors branche.

Les jobs observés sont au statut **`wip`**. Le passage à **`final`** est réservé à l’agent principal après les contrôles ciblés et l’examen visuel du lot.

## Résultats à compléter par l’agent principal

| Contrôle | Résultat et preuve |
|---|---|
| Import Godot headless du snapshot final | Voir les résultats finaux : commande, code de sortie, log, erreurs éventuelles |
| `tools/run_tests.sh assets` | Voir les résultats finaux : code, nombre d’assets, placeholders, erreurs, log |
| `tools/run_tests.sh art` | Voir les résultats finaux : test d’import et test `source_scale`, code et log |
| Qualité des cartes appelée par la suite art | Voir les résultats finaux : exécution effective de `map_quality`, résultat et réserves |
| Audit des cellules | Audit principal annoncé : aucune frame ne touche un bord ; joindre le rapport final |
| Bancs visuels Godot et captures | Voir les résultats finaux : chemins des captures, monstres et animations couverts, réserves |
| Statut de livraison | Résultats finaux : `wip` ou `final` |

Les captures prévues proviennent de **bancs visuels Godot**. Elles démontrent le chargement, le cadrage, les tailles relatives et les animations observées ; elles ne constituent pas un essai en combat ni une validation de l’ensemble des comportements. L’essai de gameplay par le propriétaire et le raccord des effets par Claude restent distincts.

## Contrôles finaux du 28 octobre

Import Godot headless propre : aucune erreur. `tools/run_tests.sh assets` : 424 entrées examinées, 422 valides, 2 placeholders, **0 erreur**. `tools/run_tests.sh art` : test de l’import (dont le cadrage entre planches) vert et contrôle réel de toutes les cartes finales **conforme**. Journaux dans `docs/previews/monstres-ch3/`. Aucun seuil modifié. Une première tentative a saturé le disque ; seuls des caches Godot régénérables d’anciens lots ont été nettoyés avant la tentative finale réussie.

Les deux bancs natifs 1280×720 ont été inspectés, au zoom 4/3 et à la densité de sol 2,25. Zéro région hors feuille ni contact avec le bord des cellules. WebP de six secondes : 2,47 et 2,42 Mo. La palette des Enlisés reste sombre sur terre : réserve de lisibilité à revoir lors de l’essai en combat ; les Reflets contrastent davantage. Le témoin Mousseroc est exactement l’asset actuel de main (aspect orange préexistant). Aucune capture n’est présentée comme une partie.

État livré : entrées des 14 sprites `final`. Raccords aux techniques existantes nommés dans le catalogue, effets PR78 conservés ; aucun changement de règle, de collision, de portée ou de cadence.
