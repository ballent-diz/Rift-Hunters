# Sorts des Marais engloutis — présentation native Godot

Livraison Codex du 26 octobre 2026 : **56 scènes autonomes**, statut `wip`, enregistrées dans
`assets/asset_manifest.json`. Le catalogue détaillé, avec propriétaire, chemin, dimensions et durée de
démonstration, est `assets/vfx/enemies/chapter3/catalog.json`.

Ces scènes produisent leur animation directement dans Godot 4.3 : rubans peints, éclats,
racines tressées, spores, boucliers, miroirs, rayons et eau. Elles réutilisent `painted_stroke.gd`
et `effects_common.gd`. La reprise du 27 octobre emploie aussi la matière peinte du ruban du
Chasseur : pas de nouvelle feuille d'animation ni de ressource tierce.
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
| `surface` | Profil graphique `organic`, `crystal` ou `ice`, déjà configuré dans chaque scène ; aucun effet sur les règles |
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
Pour `blink` et `clones`, le plafond des éclats est partagé entre les positions secondaires,
et non multiplié par leur nombre. Les rubans et formes principales restent visibles sans particules.
Budget conseillé à l'intégration : 24 effets décoratifs simultanés, dont 8 de boss ; conserver
les avertissements prioritaires. Le code de combat doit appliquer ce budget : cette livraison
ne limite pas les mécaniques ou leurs dégâts. Aucun chiffre de FPS en combat n'est revendiqué.

Contrôle ciblé : `godot --headless --path . --script res://tools/art/check_marsh_vfx.gd`.
Chargement de 56 scènes, parcours conservé, orientation, arrêt, réutilisation et fin unique.
Exécuté sous Godot 4.3 dans un projet isolé contenant ces scènes et leurs deux dépendances ;
pas de test de campagne complète ou d'équilibrage.

Aperçus natifs : `tools/art/marsh_vfx_showcase.gd`, 19 groupes de trois effets maximum, 16 images par groupe,
1280 × 720, convertis en WebP animés dans `docs/previews/marais-sorts/`. Ce sont de vrais
rendus de Godot, pas les planches raster des effets. Validation artistique et raccordement
au jeu restent à faire.

## Reprise visuelle du 27 octobre

- Même ruban peint que Taille fendante, converti en masque de luminance neutre à son premier
  chargement pour préserver les palettes des monstres. Une texture partagée de 256 × 96,
  avec mipmaps ; aucun traitement d'image dans la boucle de rendu.
- Frappes et griffes : accent de contact immédiat, balayage accéléré, trois traînées peintes,
  pointes claires et disparition progressive. Aucune temporisation de dégâts ajoutée.
- Impacts : expansion vive, fragments qui ralentissent et retombent, intérieur sombre réduit
  de 72 % à 20 % pour conserver le sol et les silhouettes visibles.
- Projectiles : masse de vase et gouttes distinctes des aiguilles et éclats à trois faces.
  Le corps reste attaché à l'origine fournie ; seul le sillage est animé.
- Racines : croissance initiale sans réinitialisation brutale à chaque boucle, ramifications
  et fils lumineux. Les liens suivent exclusivement le chemin confirmé.
- Boucliers et miroirs : facettes et reflets mobiles ; aucun grand disque opaque ajouté.
- Rayons : cœur étroit et reflets le long du trajet confirmé, sans tracer de nouveau segment.
- Glauquemire : engloutissement convergeant vers la gueule, distinct de la rage montante et
  des fentes du cœur exposé ; murs de vase plus volumétriques, écume sur tourbillon et marée.
  L'anneau de marée représente cette mécanique d'eau, pas une nouvelle enceinte d'arène.
- Les télégraphes corail gardent leur géométrie et leur dessin sans texture peinte.

Les 56 scènes conservent les mêmes dimensions, durées, couleurs, points et signaux. Le profil
de matière est le seul paramètre graphique ajouté. Les six scènes du chapitre 4 restent des
prototypes ; aucune validation de leurs monstres ou mécaniques n'est présumée.

Les nouveaux aperçus utilisent le sol de la Mangrove, le Chasseur et Mousseroc à l'échelle du
manifeste, avec zoom 4/3. Ce sont des montages natifs Godot, clairement identifiés ; aucune
partie, intelligence ennemie ou collision n'y est simulée. Les comparaisons avant/après
reprennent la version initiale exacte de la PR, commit `1d41723`, aux mêmes phases.

## Aperçus reproductibles et performance de la reprise

`tools/art/run_context.py` prépare un projet isolé ; `context_showcase.gd` le dessine ;
`render_groups.py` produit les 19 groupes sans réimporter un snapshot inchangé. Sous Windows,
le projet de rendu utilise un nouveau dossier TEMP court pour éviter les limites de chemin
du cache GLES3. Audio Dummy, aucune modification du profil ou des réglages du jeu.

```sh
python3 tools/art/run_context.py --project=after-project --output=controle --check-only --short-path
python3 tools/art/render_groups.py --work-dir=<dossier-externe> --project=after-project --count=19
```

Employer le même `--work-dir` dans les deux commandes si la valeur par défaut est remplacée.
Les séquences sont à phases normalisées pour l'observation ; ce ne sont pas des vidéos à
vitesse réelle commune. Les durées runtime restent celles du catalogue.

Les rubans peints et leur contour sont groupés en une commande par ruban ; tous les éclats
d'une scène sont regroupés en un seul maillage. Le lien de racine et le cœur des rayons
conservent une âme continue pour leur lisibilité. Le mur de vase a une silhouette irrégulière
et des faces ombrées, sans les anciens rectangles superposés.

Contrôle final : **56 scènes, zéro erreur** ; lint des scripts modifiés propre. Les dimensions,
durées, couleurs, chemins et signaux du contrat restent inchangés. Les fichiers de gameplay
`src/` et `data/` sont identiques à main.

Mesure GLES3 sur Intel Iris Xe / i5-1135G7, 1280×720, zoom 4/3, 24 effets dont 8 de boss,
90 sprites témoins Mousseroc, 30 images d'échauffement exclues puis 120 mesurées :

| Mesure | AVANT | APRÈS |
|---|---:|---:|
| Intervalle médian (ms) | 21.37 | 21.847 |
| 95e centile (ms) | 28.94 | 27.964 |
| Appels de dessin médians | 1141 | 702 |

Ce n'est **pas un benchmark de combat avec 90 Corrompus** : ni IA, collision ni dégâts.
Le temps médian reste voisin de la référence, les appels de dessin baissent. L'essai
intermédiaire à 30,926 ms a été écarté, puis l'essai trop fin à 17,321 ms a été corrigé pour
retrouver la visibilité ; leurs images lourdes restent hors Git. Aucun gain de FPS en partie
n'est revendiqué. [Mesures exactes](../previews/marais-sorts/performance.json).

[Exemple animé](../previews/marais-sorts/groupe_11.webp) ·
[Comparaison avant/après](../previews/marais-sorts/comparaison_11.webp) ·
[Catalogue des captures](../previews/marais-sorts/controle.json).

Poids des nouveaux fichiers uniques de la livraison courante : **84.2 Mo**. [Mesure](../previews/marais-sorts/poids.json).
