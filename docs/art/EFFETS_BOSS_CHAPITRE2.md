# Effets peints des boss et du chapitre 2 — livraison du lot 4

**28 scènes natives autonomes** : seize motifs de Nébulorax, Astravorn et Pyrevorn, puis douze techniques effectivement présentes dans les fiches des Calcinés et Enfants du magma. Les entrées du manifeste sont `vfx.boss.<id>.<motif>` et `vfx.enemy.<id>.<animation>`. Chaque scène porte `visual_only`, sans cible, dégâts, collision ni déplacement réel.

## Catalogue de raccordement

| Clé | Motif | Scène | Lecture |
|---|---|---|---|
| `vfx.boss.nebulorax.claw` | Nébulorax · Griffe du vide | `assets/vfx/bosses/nebulorax/claw.tscn` | 0.85 s |
| `vfx.boss.nebulorax.shadow_wave` | Nébulorax · Vague d'ombres | `assets/vfx/bosses/nebulorax/shadow_wave.tscn` | 0.85 s |
| `vfx.boss.nebulorax.summon` | Nébulorax · Invocation | `assets/vfx/bosses/nebulorax/summon.tscn` | 0.85 s |
| `vfx.boss.nebulorax.absorb` | Nébulorax · Absorption | `assets/vfx/bosses/nebulorax/absorb.tscn` | 2.8 s |
| `vfx.boss.nebulorax.void_beam` | Nébulorax · Rayon du vide | `assets/vfx/bosses/nebulorax/void_beam.tscn` | 0.85 s |
| `vfx.boss.astravorn.claw` | Astravorn · Griffe du vide | `assets/vfx/bosses/astravorn/claw.tscn` | 0.85 s |
| `vfx.boss.astravorn.shadow_wave` | Astravorn · Vague d'ombres | `assets/vfx/bosses/astravorn/shadow_wave.tscn` | 0.85 s |
| `vfx.boss.astravorn.summon` | Astravorn · Invocation | `assets/vfx/bosses/astravorn/summon.tscn` | 0.85 s |
| `vfx.boss.astravorn.star_crown` | Astravorn · Couronne d'astres | `assets/vfx/bosses/astravorn/star_crown.tscn` | 2.0 s · boucle |
| `vfx.boss.astravorn.void_beam` | Astravorn · Rayon du vide | `assets/vfx/bosses/astravorn/void_beam.tscn` | 0.85 s |
| `vfx.boss.pyrevorn.sweep` | Pyrevorn · Griffes de basalte | `assets/vfx/bosses/pyrevorn/sweep.tscn` | 0.85 s |
| `vfx.boss.pyrevorn.crater_sequence` | Pyrevorn · Séquence des cratères | `assets/vfx/bosses/pyrevorn/crater_sequence.tscn` | 1.2 s |
| `vfx.boss.pyrevorn.rock_rain` | Pyrevorn · Pluie du cratère | `assets/vfx/bosses/pyrevorn/rock_rain.tscn` | 1.2 s |
| `vfx.boss.pyrevorn.summon` | Pyrevorn · Appel de la couvée | `assets/vfx/bosses/pyrevorn/summon.tscn` | 0.85 s |
| `vfx.boss.pyrevorn.skyfall` | Pyrevorn · Envol et chute | `assets/vfx/bosses/pyrevorn/skyfall.tscn` | 1.2 s |
| `vfx.boss.pyrevorn.eye_beam` | Pyrevorn · Œil de la Faille | `assets/vfx/bosses/pyrevorn/eye_beam.tscn` | 0.85 s |
| `vfx.enemy.ash_hound.leap` | Chien de suie · Bond | `assets/vfx/enemies/chapter2/ash_hound/leap.tscn` | 0.9 s |
| `vfx.enemy.pyre_brute.pyre_slam` | Brute du bûcher · Bûcher écrasé | `assets/vfx/enemies/chapter2/pyre_brute/pyre_slam.tscn` | 0.9 s |
| `vfx.enemy.pyre_brute.blazing_rage` | Brute du bûcher · Rage du brasier | `assets/vfx/enemies/chapter2/pyre_brute/blazing_rage.tscn` | 1.5 s · boucle |
| `vfx.enemy.ashen_widow.lay_eggs` | Veuve de cendre · Ponte | `assets/vfx/enemies/chapter2/ashen_widow/lay_eggs.tscn` | 1.3 s |
| `vfx.enemy.ashen_widow.soot_web` | Veuve de cendre · Toile de suie | `assets/vfx/enemies/chapter2/ashen_widow/soot_web.tscn` | 0.9 s |
| `vfx.enemy.cinder_knight.charge` | Chevalier calciné · Charge et taille tournoyante | `assets/vfx/enemies/chapter2/cinder_knight/charge.tscn` | 1.3 s |
| `vfx.enemy.lava_lurker.plunge` | Rôdeur de lave · Plongée | `assets/vfx/enemies/chapter2/lava_lurker/plunge.tscn` | 0.9 s |
| `vfx.enemy.caldera_titan.eruption` | Titan de caldeira · Éruption et cratère ouvert | `assets/vfx/enemies/chapter2/caldera_titan/eruption.tscn` | 1.3 s |
| `vfx.enemy.flame_wyrmling.flame_breath` | Wyvernette de flammes · Souffle de flammes | `assets/vfx/enemies/chapter2/flame_wyrmling/flame_breath.tscn` | 1.3 s |
| `vfx.enemy.flame_wyrmling.dive` | Wyvernette de flammes · Piqué | `assets/vfx/enemies/chapter2/flame_wyrmling/dive.tscn` | 0.9 s |
| `vfx.enemy.slag_matron.brood` | Matrone des scories · Couvée | `assets/vfx/enemies/chapter2/slag_matron/brood.tscn` | 1.3 s |
| `vfx.enemy.slag_matron.slag_molt` | Matrone des scories · Mue de scories | `assets/vfx/enemies/chapter2/slag_matron/slag_molt.tscn` | 0.9 s |

Les motifs de boss sont les `kind` distincts de leurs fiches, sans inventer de motif supplémentaire pour les répétitions entre phases. Les douze effets ennemis correspondent aux `anim` des `EnemyTechniqueData` réelles. La charge du Chevalier calciné comprend sa taille tournoyante finale dans le même effet ; l’Éruption du Titan possède un état de cratère ouvert, sans transformer ce trait en technique supplémentaire.

Les fiches des trois boss dans `main` à `e7701e9` ne renseignent pas encore leurs `params["vfx"]`. Les noms de scène ci-dessus sont donc le **mapping proposé pour le raccordement** ; ils ne prétendent pas être déjà appelés en combat. Aucun paramètre ou donnée de gameplay n’a été modifié.

## Contrat commun

- Rendu peint partagé avec les effets PR 78 : sous-couche colorée, grain du pinceau du Chasseur, rubans et éclats en maillage, un seul `Node2D` par scène.
- `play(direction)`, `play_from(seconds, direction)`, `duration()`, `seek_visual(seconds)` et `release()` suivent le contrat des effets C3. `seek_visual` fige la pose ; une boucle reste active jusqu’au retrait ; `release` émet une seule fin après 0,22 s.
- `destroy_on_finish=true` par défaut. Pour réemployer un nœud, le garder explicitement et réinitialiser ses paramètres visuels avant `play`.
- `radius`, `width`, `travel_distance`, `visual_duration` et `particle_budget` règlent seulement le dessin. Les dimensions et durées définitives viennent du combat, sans créer une hitbox dans l’effet.
- `set_path_local(points)` reçoit un trajet local déjà confirmé, au plus 64 points ; `set_secondary_offsets(points)` reçoit jusqu’à huit emplacements confirmés pour une invocation ou pluie groupée. Pour davantage d’impacts, émettre une scène par impact réel. Les positions de démonstration ne sont pas un choix de cible.
- `set_star_positions(points)` reçoit jusqu’à 32 positions **locales** des astres réellement actifs. Le dessin suit alors exactement ces points, y compris les brèches fournies par le jeu. Le cercle à dix astres visible sans ce paramètre est une démonstration, pas une définition de la mécanique.
- Le Titan utilise `set_visual_state(1, 0)` pendant l’éruption, puis `set_visual_state(1, 1)` pour le cratère ouvert ; le jeu maintient et retire cet état selon sa vraie fenêtre de faiblesse.
- Les effets de bond/piqué/chute montrent envol puis contact à 65 % de leur durée visuelle. S’ils sont créés seulement à l’impact confirmé, utiliser `play_from(duration() * 0.65)` pour ne pas rejouer un délai après les dégâts.
- La charge montre son sillage avant 60 %, puis une taille sur un tour complet. Le raccord peut démarrer à 60 % au moment de la taille finale réelle.
- L’Absorption regroupe aspiration puis rejet des tirs à partir de 65 % de la durée visuelle. Synchroniser la présentation avec les événements confirmés du boss, jamais les dégâts avec l’horloge graphique.

Pour les trois boss, Claude pourra renseigner `vfx_dir = "res://assets/vfx/bosses/<id>"` et les noms du catalogue dans leurs paramètres `vfx`. Ce sont des instructions de raccordement : cette livraison n’écrit pas ces champs. Pour les ennemis, charger la scène correspondante lors de leur technique confirmée. Retirer alors les anciens dessins devenus redondants. Les alertes de danger restent contrôlées par le jeu.

## Validation et aperçus

- Godot 4.3 : import propre et chargement des **28 scènes**.
- Contrat ciblé : **56 fins vérifiées, zéro erreur**, orientations, trajectoires conservées, pose figée, boucles, retraits et réemploi.
- `tools/run_tests.sh assets` : **470 entrées, 455 valides, 15 prévues, zéro erreur**. Les quinze formes prévues sont le bestiaire du chapitre 4, livré dans le lot 1 distinct ; elles ne sont pas des scènes manquantes de ce lot.
- `tools/run_tests.sh art` : importeur réussi et six cartes finales conformes ; aucun seuil changé.
- Lint des scripts réussi. Cinq GIF 1280 × 720 de 18 images chacun, tous sous 3 Mo, et captures WebP inspectées.

[Aperçus et contrôle](../previews/effets-boss-chapitre-2/). Les vignettes montrent les ressources chargées dans Godot ; le Chasseur est un repère d’échelle, sans simulation de combat. Les longues animations de vol et de chute utilisent un zoom de 0,7 dans le banc pour rester entières, contre 0,9 pour les autres ; le repère reçoit toujours le même zoom que son effet. L’Œil de la Faille est violet, les autres matières de Pyrevorn sont braise et basalte.

Reproduction du contrôle :

```bash
godot --headless --import --path .
godot --headless --path . --script res://tools/art/check_missing_effects.gd -- --catalog=res://assets/vfx/bosses/chapter2_catalog.json
tools/run_tests.sh assets
tools/run_tests.sh art
```

Les captures utilisent `preview_missing_effects.gd` avec ce catalogue, `--page=0..4` et `--out=<dossier>`, puis `encode_missing_previews.py`.

## Récapitulatif pour revue

- **Livré** : seize motifs de boss et douze techniques C2, scènes natives, catalogue, manifeste, contrats, captures et contrôles.
- **Non fait** : raccord au combat et aux phases, retrait des anciens dessins et essais en jeu par le propriétaire. Aucun changement dans `src/` ni dans les règles de `data/`.
- **Choix faits sans validation** : palettes, matière, durées visuelles par défaut, dédoublement évité pour les motifs répétés entre phases ; tous les paramètres restent réglables au raccord.
- **Raccords Claude** : renseigner les chemins `vfx_dir` et noms de motifs des boss, brancher chaque technique ennemie, fournir les astres/impacts/trajets réels et synchroniser vol, contact, taille, aspiration et cratère ouvert.

Statut `wip` : scènes livrées pour revue artistique et raccordement, sans validation artistique du propriétaire revendiquée.
