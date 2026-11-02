# Effets peints des mécaniques — livraison du lot 3

**20 scènes natives Godot autonomes**, sans dégâts, collisions, cibles ni déplacement réel. Chaque scène porte la métadonnée `visual_only` et une entrée `vfx.mechanic.<nom>` dans le manifeste. Le raccord au combat reste à Claude.

## Catalogue et lecture

Préfixe des scènes : `res://assets/vfx/mechanics/`. Les durées sont visuelles ; elles ne définissent pas de durée de statut ou de danger. Le cercle du duel est tenu huit secondes comme demandé.

| Nom | Élément | Lecture | Durée visuelle |
|---|---|---|---:|
| `duel_circle` | Cercle du duel | Lecture unique | 8 s |
| `silk_thread` | Fil de soie | Boucle jusqu’au retrait | 2 s |
| `slag_shell` | Carapace de scories | Boucle jusqu’au retrait | 2 s |
| `slag_rain_impact` | Impact de scories | Lecture unique | 0.65 s |
| `bark_shield` | Bouclier d’écorce | Boucle jusqu’au retrait | 2 s |
| `dive_ripple` | Ride de plongée | Boucle jusqu’au retrait | 1.6 s |
| `dive_burst` | Sortie de plongée | Lecture unique | 0.8 s |
| `snowball` | Boule de neige | Boucle jusqu’au retrait | 1.1 s |
| `ice_prison` | Prison de glace | Boucle jusqu’au retrait | 2 s |
| `hush_circle` | Cercle de silence | Boucle jusqu’au retrait | 2 s |
| `blizzard_vortex` | Tourbillon de blizzard | Boucle jusqu’au retrait | 1.6 s |
| `frost_mist` | Brume de givre | Boucle jusqu’au retrait | 2 s |
| `ice_crack` | Fissure de glace | Lecture unique | 0.9 s |
| `spell_echo_volley` | Gerbe de sort renvoyé | Lecture unique | 0.8 s |
| `ice_spikes` | Pics de glace | Lecture unique | 1.1 s |
| `shatter_floor` | Plaque qui cède | Lecture unique | 1.2 s |
| `spell_capture` | Capture de sorts | Boucle jusqu’au retrait | 1.6 s |
| `rockfall` | Chute de roche | Lecture unique | 0.9 s |
| `tide_water` | Marée sur chaussée | Boucle jusqu’au retrait | 2 s |
| `cold_aura` | Chaleur du brasero | Boucle jusqu’au retrait | 2 s |

## Contrat de raccordement

Le script partagé hérite du rendu peint de la PR 78 : pinceau du Chasseur, rubans de matière et éclats en maillage commun. Une sous-couche colorée conserve la lisibilité sur les sols clairs. Chaque effet reste un seul `Node2D` ; aucun nœud par particule. Le budget exporté vaut 20, borné par les dessins et le contrat existant. Aucun mélange additif global ne blanchit les acteurs.

- `play(direction)` démarre ; `play_from(seconds, direction)` reprend à un point visuel confirmé ; `duration()` donne la durée visuelle.
- `seek_visual(seconds)` fige une pose pour le banc documentaire.
- `release()` dissipe en 0,22 s et émet une seule fois `visual_finished`. Une boucle ne termine pas seule. `destroy_on_finish` est vrai par défaut ; le mettre à faux pour réutiliser explicitement le nœud.
- `radius`, `width`, `travel_distance` et `visual_duration` sont fournis par le raccord. Les valeurs de catalogue sont des exemples de présentation, jamais des hitboxes.
- `set_path_local(points)` reçoit les points déjà confirmés par le jeu, au plus 64. Le fil relie les deux extrémités ; la fissure suit les segments. Aucun calcul de cible, obstacle ou portée ici.
- `set_visual_state(strength, stage)` fournit les états : carapace intacte `strength=1`, fendue proche de zéro ; fil tendu `stage=0`, coupé `stage=1` ; prison intacte `strength=1`, brisée zéro. `release()` déclenche aussi la rupture de ces trois effets.
- Pour réemployer un effet cassé comme un objet intact, appeler `set_visual_state(1, 0)` avant `play`. L’état fourni par le combat n’est pas secrètement remis à zéro.
- Boule de neige : `stage` de 0 à 1 augmente sa taille de 60 à 100 % du rayon ; sa texture tourne indépendamment. La progression réelle vient du jeu, pas d’une simulation de projectile dans le visuel.
- Marée : `stage` pilote le niveau ; `travel_distance` donne la largeur représentée et `radius` la hauteur. Poser le dessin sur la chaussée déjà définie par le jeu.
- `cold_aura` est bien le **halo chaud** du brasero demandé : ambre, ivoire et petites braises, malgré le nom technique conservé.

Les scènes restent sous les acteurs (`z_index=1`, repère acteur à 3). L’image de la prison conserve un cœur translucide. Les cercles peints sont des présentations ; les vrais états de danger, collisions et alertes sont toujours contrôlés par le jeu. Au raccordement, retirer les anciens dessins devenus redondants sans superposer deux présentations du même élément.

## Validation et aperçus

- Import propre sous Godot 4.3.
- Contrôle ciblé : **20 scènes**, trajectoires conservées, temps figé, orientations, boucles, retraits et réemploi ; **40 fins vérifiées, zéro erreur**.
- `tools/run_tests.sh assets` : **462 entrées : 447 valides, 15 prévues pour le chapitre 4 du lot 1, zéro erreur** après actualisation sur `main` (PR #89).
- `tools/run_tests.sh art` : importeur et six cartes finales conformes, sans modification de seuils.
- Lint des nouveaux scripts réussi.
- Quatre groupes capturés dans Godot à **1280 × 720**, avec GIF de 18 images chacun, tous sous 3 Mo. Les états tendu/coupé, intact/brisé et les changements de niveau sont visibles dans les GIF.

[Aperçus et contrôle](../previews/effets-mecaniques/). Le Chasseur sert uniquement de repère d’échelle ; la chaussée grise du banc sert à lire la transparence de l’eau. Aucun combat n’est simulé dans ces captures.

Reproduction du contrôle :

```bash
godot --headless --import --path .
godot --headless --path . --script res://tools/art/check_missing_effects.gd -- --catalog=res://assets/vfx/mechanics/catalog.json
tools/run_tests.sh assets
tools/run_tests.sh art
```

Pour les captures, utiliser `preview_missing_effects.gd` avec le même `--catalog`, `--page=0..3` et `--out=<dossier>`, puis `encode_missing_previews.py`. Activer les outils du cloud et Xvfb comme indiqué dans la configuration.

## Récapitulatif pour revue

- **Livré** : les vingt éléments demandés, scènes natives, catalogue, manifeste, contrat, captures et contrôles.
- **Non fait** : raccord aux événements et états du combat, suppression des anciens dessins lors de ce raccord et essais en campagne par le propriétaire. Aucun `src/` ni règle de `data/` modifié.
- **Choix faits sans validation** : palettes et dessin des matières, durées visuelles par défaut hors cercle de duel, états normalisés pour neige/eau/rupture ; paramètres documentés et réglables.
- **Raccords Claude** : fournir dimensions et trajets réels ; démarrer sur événement confirmé ; maintenir puis retirer les effets en boucle ; synchroniser fil, carapace, glace, croissance et marée.

Statut `wip` : livré pour revue artistique et raccordement, aucune validation artistique du propriétaire revendiquée.
