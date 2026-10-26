# Sorts des Marais engloutis — présentation native Godot

Livraison Codex du 26 octobre 2026 : **56 scènes autonomes**, statut `wip`, enregistrées dans
`assets/asset_manifest.json`. Le catalogue détaillé, avec propriétaire, chemin, dimensions et durée de
démonstration, est `assets/vfx/enemies/chapter3/catalog.json`.

Ces scènes produisent leur animation directement dans Godot 4.3 : rubans facettés, éclats,
racines tressées, spores, boucliers, miroirs, rayons et eau. Elles réutilisent `painted_stroke.gd`
et `effects_common.gd`. Aucun fichier image généré n'est utilisé comme animation de sort.
Les planches raster livrées séparément sont des sources artistiques, pas une dépendance de ces scènes.

## Périmètre et état

- Chapitre 3 : **31 scènes** des quatorze Enlisés et Reflets, avec techniques et traits visibles.
- Glauquemire : **16 scènes**, dont vase, murs, racine-laisse, soin des sangsues, carapace,
  miroirs, rayon réfléchi, tourbillon, marée, engloutissement et libération d'Écho.
- Chapitre 4 : **6 scènes de proposition** pour Loup de givre, Scarabée de banquise,
  Chauve-souris des neiges et Ver des glaciers. Les mécaniques et identifiants ne sont pas validés.
- Télégraphes communs : **3 scènes** de zone, ligne et secteur.

Le catalogue donne le décompte exact : 31 scènes d'ennemis du chapitre 3, 16 du boss,
6 prototypes et 3 télégraphes = 56. Les scènes sont disponibles pour raccordement par Claude ;
**aucun comportement du combat n'a été remplacé**. Les formes provisoires de `MarshTechniques`
et `GlauquemireMechanics` continuent d'être utilisées jusqu'à ce raccordement.

Glauquemire : seule la planche de corps A est proposée au propriétaire. Les cinq suivantes
restent suspendues à sa validation, conformément à `docs/design/DEVOREUR_CHAPITRE3.md`
sur la branche de Claude. Les effets de terrain ne présument pas la validation du corps.

## Contrat commun

Le script `assets/vfx/enemies/chapter3/enemy_effect.gd` n'a aucune dépendance au combat.
Il ne choisit pas de cible, ne déplace pas de projectile, ne crée ni ennemi ni collision,
et ne déclenche pas de dégâts ou de statut.

| API | Usage |
|---|---|
| `play(direction)` | Démarrer à une origine déjà placée ; axe local +X orienté vers la direction |
| `play_from(seconds, direction)` | Reprendre à l'instant réel de l'événement confirmé |
| `seek_visual(seconds)` | Figer un aperçu sans simuler le combat |
| `set_path_local(points)` | Fournir jusqu'à 64 points locaux du trajet réel, déjà arrêté et réfléchi |
| `set_secondary_offsets(points)` | Jusqu'à 8 positions locales confirmées : invocation, clones ou alliés protégés |
| `set_visual_state(strength, hardening)` | Intensité visuelle et stade de durcissement, chacun entre 0 et 1 |
| `set_facet_strengths(values)` | Quatre intégrités normalisées : droite, bas, gauche, haut ; zéro masque une face brisée |
| `release()` | Dissiper une boucle en 0,22 s ; un seul signal de fin |
| `visual_finished` | Fin graphique seulement ; ne jamais y raccorder des dégâts ou invocations |

Configurer `radius`, `width`, `travel_distance`, `half_angle_degrees` et `visual_duration`
**avant** `play`. Les valeurs du catalogue sont des exemples, pas des réglages de combat.
`width` est une largeur totale. Les projectiles sont des enfants de leur projectile réel ;
aucun déplacement fictif n'est fait par leur scène. Les marques suivent leur porteur.
`loop_visual` maintient la présentation ; `destroy_on_finish = false` autorise la réutilisation.

## Raccordement aux mécaniques existantes

| Source du combat de Claude | Scènes à raccorder | Données nécessaires |
|---|---|---|
| Crapaud `mud_leap`, Racine `burrow` | `mud_landing`, `burrow` | Point et moment exacts de sortie/atterrissage |
| `technique_mark` et explosion de la marque | `spore_mark` / `prism_mark`, puis `mark_explosion` / `prism_explosion` | Porteur, délai et rayon réels ; effacer dès annulation par Ruée |
| `technique_ally_shield` | `bark_shield` | Une scène par allié réellement protégé ; supprimer si source morte ou bouclier expiré |
| `technique_heal_aura` | `heal_aura` | Uniquement pendant un soin confirmé ; positions des alliés soignés si fournies |
| `technique_blink`, `technique_clones` | `reflection_jump`, `chain_blink`, `evasive_blink`, `clones` | Départ/arrivée réels, positions de clones déjà validées ; les scènes ne créent pas les clones |
| `technique_reflect` | `reflecting_mirror` | Direction réelle du bouclier frontal et durée restante |
| `technique_sweep_beam`, `shard_fan` | `sweep_beam`, `shard_fan` | Segment tronqué et éventail réels, avant le dessin |
| Furtivité de la Chasseresse | `reveal` | Transition vers visible uniquement ; ne pas révéler un ennemi furtif avec un effet |
| Glauquemire `puddles` | `mud_impact`, puis `mud_wall` | Géométrie de chaque flaque/mur ; `stage` = progression réelle de durcissement |
| Glauquemire `leash` | `root_leash` | Points locaux ancre → Chasseur, actualisés ; effacer dès rupture |
| Glauquemire `facets` | `facets`, `facet_break` | Rayon du boss et intégrités réelles des quatre faces |
| Glauquemire `mirrors`, `beam.paths` | `mirror`, `prism_beam` | Orientation réelle ; une scène de rayon par chemin et coordonnées converties en local |
| Glauquemire `whirl`, `tide` | `whirlpool`, `tide_ring` | Centre et rayon actuels, actualisés chaque image ; arrêt synchronisé |
| Glauquemire `swallowed` et `_release` | `swallow`, `echo_release` | Ancre réelle du boss, événements de capture/libération déjà résolus |

Pour un rayon réfléchi, garder la rotation de la scène à zéro si les points sont déjà
convertis avec `effect.to_local(world_point)`. Ne pas appliquer une seconde rotation.
Le dessin **ne trace aucun rayon** : murs et obstacles restent entièrement sous le contrôle
de `GlauquemireMechanics.trace`. Mettre à jour les points à chaque changement de miroir.
Pour deux rayons de phase 3, utiliser deux scènes indépendantes.

Les télégraphes (`shared/indicator_area`, `indicator_line`, `indicator_sector`) sont corail,
au `z_index = 100`, avec intérieur très faible ; les effets décoratifs sont au niveau 1.
Remplacer un télégraphe provisoire par son équivalent seulement si la géométrie et la durée
réelles sont fournies. Ne pas superposer deux avertissements du même danger.

## Exemple de raccordement visuel

```gdscript
var effect: Node2D = preload("res://assets/vfx/bosses/glauquemire/prism_beam.tscn").instantiate()
world.add_child(effect)
effect.global_position = boss.global_position
effect.width = float(beam["width"])
effect.play() # origine, puis trajet local calculé par le combat
var local_points := PackedVector2Array()
for point: Vector2 in confirmed_world_path:
    local_points.append(effect.to_local(point))
effect.set_path_local(local_points)
# Actualiser ces points pendant le balayage ; effect.release() à la vraie fin.
```

## Budget et vérification

Une scène = un Node2D ; aucun nœud par particule. Éclats bornés à 32, spores à 24,
points secondaires à 8 et points de rayon à 64. `particle_budget = 0` supprime les éclats secondaires.
Budget conseillé à l'intégration : 24 effets décoratifs simultanés, dont 8 de boss ; conserver
les avertissements prioritaires. Le code de combat doit appliquer ce budget : cette livraison
ne limite pas les mécaniques ou leurs dégâts. Aucun chiffre de FPS en combat n'est revendiqué.

Contrôle ciblé : `godot --headless --path . --script res://tools/art/check_marsh_vfx.gd`.
Chargement de 56 scènes, parcours conservé, orientation, arrêt, réutilisation et fin unique.
Exécuté sous Godot 4.3 dans un projet isolé contenant ces scènes et leurs deux dépendances ;
pas de test de campagne complète ou d'équilibrage.

Aperçus natifs : `tools/art/marsh_vfx_showcase.gd`, 10 groupes, 16 images par groupe,
1280 × 720, convertis en WebP animés dans `docs/previews/marais-sorts/`. Ce sont de vrais
rendus de Godot, pas les planches raster des effets. Validation artistique et raccordement
au jeu restent à faire.
