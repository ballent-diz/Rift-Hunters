# Glauquemire et lanterne de brume — livraison visuelle

Les six planches de Glauquemire couvrent ses trois phases : **14 animations, 84 poses**. Une planche de lanterne ajoute **trois états animés, 18 poses**. Aucun `src/`, donnée de gameplay, collision, dégât ou minuterie n'est modifié. Les effets de terrain sont ceux de la PR #78 déjà fusionnée ; ils ne sont pas régénérés ici.

## Sources et choix de production

Sources retenues, prompts exacts, facteurs de cadrage et SHA256 :

- `assets/concepts/incoming/boss.glauquemire/` : six sources A–F et `job.json` ;
- `assets/concepts/incoming/object.mist_lantern/` : source unique et `job.json`.

Les images proviennent uniquement de la génération intégrée, sans API payante ni ressource tierce. Les essais écartés restent hors dépôt. L'archive Work précédemment annoncée n'étant pas téléchargeable par les outils disponibles, ces sources sont des remplacements, pas un import de cette archive.

Le brief autonome du 28 octobre (« ne bloque pas sur une question, choisis et explique ») a été appliqué pour retenir A puis produire B–F. Cette décision dépasse l'ancien arrêt de la fiche de conception après A ; **elle ne constitue pas une validation artistique du propriétaire**.

Le corps conserve la mâchoire crocodilienne, les membres-racines, les lotus pâles et le dos moussu. La phase 2 ajoute la carapace cyan ; la phase 3 l'ouvre sur un petit cœur violet. Le violet est réservé au cœur, sans lave ni orange. `transform` montre la croissance vase → cristal ; le passage cristal → cœur est représenté par l'état distinct de E, **sans seconde animation de métamorphose séparée**. Ce raccord doit rester explicite côté Claude.

## Atlas, échelle et cadence

`boss.glauquemire` : atlas `assets/sprites/bosses/glauquemire/glauquemire_sheet.png`, cellules **512 × 512**, ancre **[256, 480]**, `scale = 0.5`, hauteur cible **150 pixels d'art**, conformément à la fiche. La cellule réserve les mouvements ; sa taille n'est pas celle du corps. L'échelle du manifeste et les données de combat restent inchangées.

Chaque animation contient six poses. Le cadrage variable de A–F est compensé par **un facteur fixe par planche** (`source_scale`, dans chaque entrée du job). La largeur corporelle de poses de repos sert de référence ; F est mesurée sur sa première pose, pour ne pas regonfler le cadavre final. Les 84 poses ne sont jamais redimensionnées individuellement à une même hauteur. Les facteurs exacts sont dans `source/normalization.json`.

Le réglage de l'importeur et son test reprennent à l'identique ceux de la PR #82. Les deux PR peuvent être fusionnées sans introduire deux versions de cet outil ; aucune fonction de gameplay n'en dépend.

| Planche | Animation runtime | Cadence ; durée d'un passage | Boucle | Déclenchement attendu |
|---|---|---|---|---|
| A, rangée 0 | `idle` | 8 fps ; 0,75 s | oui | Attente phase 1 |
| A, rangée 1 | `move` | 10 fps ; 0,6 s | oui | Déplacement |
| A, rangée 2 | `claws` | 12 fps ; 0,5 s | non | Griffes et écrasement de base |
| B, rangée 0 | `mud_spit` | 12 fps ; 0,5 s | non | Préparation/émission des jets de vase |
| B, rangée 1 | `root_lash` | 12 fps ; 0,5 s | non | Pose de la racine-laisse |
| B, rangée 2 | `leech_call` | 10 fps ; 0,6 s | non | Appel des sangsues |
| C, rangée 0 | `transform` | 10 fps ; 0,6 s | non | Recouvrement de cristal |
| C, rangée 1 | `phase2_idle` | 8 fps ; 0,75 s | oui | Attente sous carapace |
| D, rangée 0 | `prism_beam` | 10 fps ; 0,6 s | non | Prisme dans la gorge, rayon fourni séparément |
| D, rangée 1 | `hurt` | 12 fps ; 0,5 s | non | Étourdissement, armure brisée |
| E, rangée 0 | `phase3_idle` | 8 fps ; 0,75 s | oui | Attente, cœur de Faille exposé |
| E, rangée 1 | `whirlpool` | 10 fps ; 0,6 s | non | Tourbillon, eau de terrain séparée |
| E, rangée 2 | `swallow` | 12 fps ; 0,5 s | non | Gueule qui happe et se referme |
| F, rangée 0 | `death` | 8 fps ; 0,75 s | non | Mort vers carcasse éteinte |

`attack` est un alias de `claws`, sans rangée ni animation peinte supplémentaire. Les répétitions nécessaires à un maintien de technique doivent suivre l'état réel du combat ; les cadences ci-dessus ne changent aucune durée de gameplay.

## Lanterne de brume

`object.mist_lantern` : atlas `assets/sprites/objects/mist_lantern/mist_lantern_sheet.png`, cellules **128 × 128**, ancre **[64, 118]**, échelle **0,5**, hauteur d'import **90 pixels d'art**. Pierre grise moussue, petit capuchon métallique, flamme bleu-blanc et brume violette contenue. Aucun dôme, ombre au sol ni barre de vie peint.

| Rangée | Animation | Cadence | Boucle | Alias compatible |
|---|---|---|---|---|
| 0 | `lit_idle` | 6 poses à 8 fps | oui | `idle` |
| 1 | `extinguish` | 6 poses à 12 fps | non | `death` |
| 2 | `unlit_idle` | 6 poses à 8 fps | oui | — |

L'absence de flamme, davantage que la fissure très fine de la vitre, signale l'extinction. Le moteur reste responsable de l'ombre, des fils de brume, des cibles, des dégâts et de la disparition de l'objet.

## Contrat de raccordement

- Charger les frames par les identifiants du manifeste ; conserver leurs ancres et échelles.
- Choisir `phase2_idle` et `phase3_idle` selon la phase réelle. Une variante de pose ne déclenche ni transition ni invulnérabilité.
- Pour le rayon, ne peindre ni tracer la trajectoire depuis le sprite : utiliser les points réfléchis et l'effet `assets/vfx/bosses/glauquemire/prism_beam.tscn` de la PR #78.
- Vase/murs, racine-laisse, sangsues, facettes, miroirs, tourbillon, anneau de marée et capture/libération d'Écho gardent les contrats de `docs/art/MARAIS_SORTS_GODOT.md` ; aucune scène d'effet n'est refaite.
- Les six poses de corps sont un support d'animation ; la synchronisation préparation/action/impact, les portées, les collisions et le choix des cibles restent au code de Claude.
- La lanterne fournit `idle` et `death` pour les appels existants, plus `unlit_idle` si le code doit conserver son socle éteint.

## Contrôles et limites

Les contrôles finaux et les aperçus sont joints dans `docs/previews/glauquemire/` après exécution. Les bancs 1280 × 720 montrent les trois phases côte à côte, la lanterne et les témoins à l'échelle du manifeste : **ils ne sont pas des captures de combat**. Le sol utilise 2,25 texels/unité et le zoom 4/3.

Réserves artistiques à examiner en jeu : phase 1 sombre sur terre, cœur violet de phase 3 relativement petit, transition vers le cœur non séparée. Aucune preuve de lisibilité en combat contre 90 Corrompus n'est déduite de ces bancs.

## Résultats finaux

- Import Godot headless propre, sans erreur après reconstruction du cache.
- `tools/run_tests.sh assets` : **424 entrées, 410 valides, 14 placeholders, 0 erreur**. Les 14 placeholders sont les monstres C3 du main de base : leurs sprites sont livrés séparément par la PR #82, non encore fusionnée lors de ce contrôle.
- `tools/run_tests.sh art` : **vert**, test de l’import et contrôle réel de toutes les cartes finales exécutés ; verdicts conformes. Aucun seuil changé.
- 14 clips natifs de boss et un de lanterne ; chaque WebP sous 3 Mo, durées de poses vérifiées à la cadence du manifeste. Atlas inspectés : aucune région hors feuille ni contact opaque avec le bord.
- GPU : code de sortie 0 et images complètes, mais un message `initialize(shader_gles3.cpp:798)` apparaît dans les journaux natifs. Il est conservé ; aucun succès « GPU sans erreur » n’est revendiqué. Cela est distinct de l’import et des suites headless, verts.

Le cache temporaire de vérification est régénérable ; les sources, atlas, métadonnées `.import` et journaux sont conservés dans le dépôt.
