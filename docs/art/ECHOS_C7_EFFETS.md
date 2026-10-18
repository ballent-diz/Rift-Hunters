# Effets et icônes des neuf nouveaux Échos — C5-bis / raccordement C7

## Périmètre et provenance

Ressources autonomes de présentation dans `assets/vfx/echoes/`. Aucune lecture du contexte de partie,
aucune collision, aucun dégât, soin, statut, déplacement réel ou choix de cible.
La source fonctionnelle reste `docs/design/ECHOS.md` ; ses propositions sont illustrées,
sans inventer de valeurs d'équilibrage ni de bonus de Signature. Claude conserve le lot C7.

Les animations sont dessinées par Godot avec le vocabulaire peint du Chasseur : rubans texturés,
facettes, éclats, branches, circuits et trajectoires déterministes. Aucun nœud par particule.
Un shader anime la matière à l'intérieur des traits : stries mobiles et touches claires,
sans flou ni grand halo. Les plumes ont une nervure et des barbes ; les flammes une enveloppe
déchirée et un cœur fumé. Les attaques précèdent leurs traînées d'une préparation brève,
puis laissent une dissipation distincte. L'indicateur reste indépendant de ces phases.
Les illustrations sont générées avec l'outil imagegen intégré ; chaque original, prompt exact
et empreinte SHA-256 est conservé dans `assets/concepts/incoming/icon.echo.<id>/source/`.
Aucune ressource tierce nouvelle. Le statut `wip` signifie : livré pour validation visuelle du propriétaire.

## Catalogue de raccordement

Préfixe des scènes : `res://assets/vfx/echoes/<écho>/`. Les noms ci-dessous se terminent par `.tscn`.
Clés du manifeste : `vfx.echo.<écho>.<nom_de_scène>`. Les affiches SVG `poster.svg` sont de simples
repères du catalogue ; elles ne sont pas utilisées pour dessiner l'animation en jeu.

| Écho / palette | Attaque `attack` | Technique / scène | Second sort / scène | Statut `status` |
|---|---|---|---|---|
| Pyraile `cinderwing`, orange / jaune électrique | Plume vive avec sillage de braise | Pluie de cendres `ash_rain` : plumes qui descendent et impacts | Piqué foudroyant `thunder_dive` : sillage et décharge sur une ligne | Flamme de Brûlure, petite et localisée |
| Scoriade `magmander`, rouge lave / basalte | Mâchoires de roche qui se referment | Coulée `lava_flow` : croûtes successives et fissures incandescentes | Geyser `geyser` : jets ascendants et fragments | Petite flaque fissurée de lave |
| Spectrâtre `hollowflame`, bleu pâle / noir fumé | Flamme creuse à sillage | Implosion `implosion` : fragments aspirés, contraction puis éclat | Flamme errante `wandering_flame` : flamme avec parcours de rebonds fourni par C7 | Marque d'implosion à fragments convergents |
| Sporelune `moonspore`, turquoise / beige | Petit nuage de spores projeté | Nuée de spores `spore_cloud` : spores dispersées, peu opaques | Bourgeon `bud_trap` : pousse puis émission de spores | Spores flottantes localisées sur la cible |
| Gravelune `gravishell`, gris-bleu / or | Choc de carapace et fragment orbital | Singularité `gravity_well` : fragments et arcs orbitaux convergents | Météore `meteor` : chute oblique, impact et éclats | Petits fragments soumis à la gravité |
| Sylvécaille `grovestag`, mousse / ambre | Ramure à deux cristaux en avant | Bosquet `healing_grove` : pousses cristallines et feuilles de soin | Ronces protectrices `protective_thorns` : deux branches épineuses en garde | Pousses et liaisons de soin vers les bénéficiaires réels |
| Solgriffe `sunclaw`, or / ivoire | Trois griffes balayées | Éclat solaire `solar_flare` : éventail de rayons | Bond lumineux `radiant_leap` : courbe et rémanences | Petit éclat d'aveuglement ; rayon à réduire autour de la tête |
| Lueurine `glowmoth`, jaune-vert / blanc | Poussière d'ailes projetée | Essaim de lucioles `firefly_swarm` : points lumineux aux ailes battantes | Poudre d'ailes `wing_dust` : poussière et traits fins | Lucioles et traits de vitesse autour du bénéficiaire |
| Égidor `stormshell`, acier bleu / jaune | Choc de carapace électrifiée | Dôme conducteur `conductive_dome` : arcs de coque, intérieur transparent | Décharge `discharge` : onde électrique segmentée | Coque conductrice et arcs vers les cibles fournies |

Chaque dossier contient aussi `indicator.tscn`, indicateur allié pointillé et pulsant.
Il s'emploie pour les deux sorts, en passant `target_shape` : `area`, `line` ou `cone`.
Pour Coulée, Piqué et Bond : `line`. Pour Éclat solaire : `cone`. Les autres : `area`.
La forme, le rayon et la longueur sont toujours fournis par les données définitives de C7.

## Paramètres communs et cycle de vie

| Paramètre / méthode | Contrat |
|---|---|
| `radius` | Rayon visuel en unités du monde. Défaut 44 pour attaque/statut, 88 pour les sorts ; jamais une hitbox. Réduire les marques portées à 12–24 selon le sprite. |
| `visual_duration` / `duration()` | Durée graphique en secondes, dissipation comprise. Défauts 0,75 attaque ; 1,6 sort/indicateur ; 2 statut. C7 remplace ces exemples par la durée réellement voulue. |
| `travel_distance` | Longueur graphique du trajet depuis l'origine locale vers +X ; 180 pour les exemples d'attaque, 240 pour les sorts, 0 pour un statut porté. |
| `color`, `accent` | Palette du sprite C8. Préserver les couleurs alliées ; aucun accent principal magenta. |
| `particle_budget` | Budget d'éclats dessinés, défaut 18 ; boucles bornées à 48 au maximum. Un seul Node2D par effet, zéro nœud par particule. |
| `play(direction)` | Commence à zéro et oriente l'axe +X. Une direction nulle utilise +X. Aucun déplacement du lanceur. |
| `play_from(seconds, direction)` | Reprend la lecture à une phase donnée, pour synchroniser un contact déjà confirmé sans attendre la préparation. |
| `play_between(from, to)` | Place l'effet au départ et ajuste longueur et direction ; représente le trajet complet. Ne pas doubler avec la translation d'un projectile réel. |
| `set_secondary_offsets(points)` | Jusqu'à 8 positions locales réelles : rebonds de Flamme errante, liaisons de soin ou décharges. C7 convertit ses points monde avec `to_local()`. Aucune sélection de cible interne. |
| `loop_visual` | Répète la présentation d'une zone, marque ou visée tant que C7 la maintient ; ne prolonge aucune règle. |
| `release()` | Termine la boucle et lance les 0,25 dernières secondes de dissipation ; à appeler quand la zone, marque, garde ou visée est retirée. |
| `visual_finished` | Signal de fin graphique uniquement ; ne doit pas déclencher dégâts, soin ou apparition. |
| `destroy_on_finish` | `true` par défaut. `false` permet la réutilisation ; le propriétaire de la scène assure alors sa libération. |
| `seek_visual(seconds)` | Lecture figée pour contrôle, sans avancer la simulation. |

Déclenchement : attaque à l'armé ou au départ du projectile confirmé ; zone au point d'impact confirmé ;
statut seulement quand C7 confirme son application ; soin seulement après confirmation du bénéficiaire.
Pour un projectile simulé par C7 : attacher un effet à `travel_distance = 0` et laisser C7 le déplacer,
ou jouer le trajet autonome depuis le point de tir, mais pas les deux.
Le piqué et le bond ne déplacent que le dessin : la position réelle de l'Écho reste gérée par C7.
L'indicateur précède le lancement et est libéré à la validation/annulation de la visée.
Pour synchroniser : la préparation occupe environ les 12 premiers pour cent de la durée ;
la translation du piqué/bond va de 12 à 70 %, celle des flammes de 10 à 85 %.
Météore frappe graphiquement à 52 % : s'il est créé au contact déjà confirmé, utiliser
`play_from(duration() * 0.52)` pour jouer directement l'impact. Ces repères ne pilotent aucun dégât.
Pour les zones maintenues, C7 choisit la durée réelle et active `loop_visual`, puis `release()` au retrait.

Placer la couche d'effets au `z_index = 1`, sous les personnages (`3`) et sous les projectiles ennemis.
Les zones n'ont pas de grand remplissage lumineux ; les flaques ont un fond sombre à opacité limitée.
Ne pas ajouter de mélange additif global qui blanchirait les personnages ou les télégraphes.

## Plafond partagé

Utiliser `assets/vfx/echoes/effect_layer.gd` sur un Node2D du monde :

```gdscript
var scene = load("res://assets/vfx/echoes/moonspore/spore_cloud.tscn")
var fx = effects.emit_effect(scene, target_position, Vector2.RIGHT, {
    "radius": actual_radius,
    "visual_duration": actual_duration,
})
```

`max_effects = 24`, borné à 32. À saturation, `emit_effect` retourne `null` et refuse seulement
un visuel excédentaire ; C7 exécute l'action normalement. Pour une marque ou une zone persistante,
conserver la référence et appeler `release()` à sa suppression. Vider la couche à la fin de partie.
Ne pas créer une couche par ennemi : le plafond doit être partagé par toute l'équipe.
La couche adapte les détails : jusqu'à 6 effets, rubans peints et 18 éclats ; de 7 à 12,
traits simplifiés et 8 éclats ; au-delà, 4 éclats. Le budget demandé par le lanceur n'est jamais dépassé.
Le rendu complet revient quand le nombre baisse. Les rayons, trajectoires et durées ne changent pas.

## Icônes et arbres

45 PNG HD 512 × 512 : `assets/ui/icons/skills/echo_<écho>_<rôle>.png`.
Rôles : `might`, `focus`, `spell_base`, `spell_alt`, `signature`.
Clés : `icon.echo.<écho>_<rôle>` ; les deux sorts réutilisent leurs illustrations de nœud.
Les identifiants de techniques C7 ne sont pas imposés ici : ils peuvent pointer vers ces mêmes images.
Le lookup existant `EchoTreeBoard.node_icon` les retrouvera quand C7 ajoutera les nœuds correspondants.
Aucun changement de l'écran, des arbres, de leurs règles ou des données de gameplay.

Import commun : `python3 tools/art/finish_echo_icons.py`, qui appelle `import_sheet.py` pour chaque recette.
Couleurs conservées, transparence, rééchantillonnage Lanczos, aucune réduction de palette ou contour ajouté.
Les textures d'interface ont `mipmaps/generate=true`. La planche de contrôle compare 112 px et 48 px.
Les Signatures illustrent l'identité de la créature ; leur mécanique définitive appartient à C7.

## Reproduction et validation

1. `python3 tools/art/prepare_echo_effects.py` prépare scènes, manifeste et recettes.
2. `godot --headless --import --path .` puis `res://tools/art/check_echo_effects.tscn` :
   chargement des 45 scènes, lecture, fin et refus des effets excédentaires.
3. Lancer `res://tools/art/c7_echo_preview.tscn` avec le rendu graphique et la variable
   `C7_FRAME_DIR` dirigée vers un dossier local de travail.
4. `python3 tools/art/encode_echo_effects.py --frames <dossier>` : neuf captures et dix-huit GIF de sorts.
5. `tools/run_tests.sh` complet à la fin du lot ; ne pas le relancer à chaque réglage graphique.

Les captures sont produites dans la véritable scène `run.tscn` des Ruines des Cascades à 1280 × 720,
avec 90 Corrompus, simulation gelée et profil en lecture seule. Le nouveau sprite est posé par l'outil :
ce sont des démonstrations de présentation, pas une intégration du comportement C7.
Mousseroc, le Chasseur et le HUD de la partie restent présents. Les barrières sont masquées uniquement
dans cet outil pour ne pas interférer avec le contrôle des effets.
`performance.json` compare 60 images sans/avec 24 effets pour chacun des neuf Échos,
géométrie redessinée à chaque image. Les chiffres ne mesurent pas le coût de toute l'IA.
Validation artistique et essai du raccordement final par le propriétaire après C7.

## Résultats de la livraison

Import Godot sans erreur, puis `tools/run_tests.sh` complet : **code 0**.
224 scripts vérifiés, **215/215 tests unitaires**, persistance écriture/relecture,
**249/249 ressources**, art, smoke et lint réussis. Contrôle dédié des 45 scènes et du plafond,
des boucles, de leur retrait et du rétablissement des détails : réussi. Lint des scripts VFX
dans `assets/` effectué explicitement, en plus du lint commun.
Le nettoyage des tests conserve l'avertissement préexistant de 17 CanvasItem à la fermeture.

Audit : 45 PNG distincts de 512 px, transparence, mipmaps, empreintes des originaux conformes ;
aucun `.import` dans leurs dossiers incoming. Neuf captures et dix-huit GIF de vingt images,
tous à 1280 × 720. Les GIF utilisent une palette commune par séquence pour réduire le poids
et éviter les variations du décor dues à la quantification.

Rendu local sur Intel Iris Xe / OpenGL Compatibility, 90 Corrompus et 24 effets redessinés :
médianes avec effets **16,66 à 16,74 ms**, p95 **16,88 à 17,95 ms** sur 60 images par cas.
Simulation gelée : ces mesures ne couvrent pas le coût des règles de combat ni de toute l'IA.
Les ressources restent proposées à la validation artistique du propriétaire et au raccordement C7.

## Raccordement en jeu (Claude, lot C7)

- `src/entities/allies/echo_vfx.gd` crée une seule couche `effect_layer.gd` pour toute l'équipe et joue les scènes
  par convention : `attack` (comportements), `<id du sort>` ou `params.vfx` (Singularité → `gravity_well`),
  `status` (premier statut de l'attaque de l'Écho, au plus toutes les 0,35 s ; flaques de Scoriade et soins de
  Sylvécaille joués par leur règle) et `indicator` (option « aperçu » : touche maintenue).
- Rayons, durées et trajets passés aux scènes = valeurs réelles des données. Un effet refusé par le plafond ne
  change rien au jeu ; les projectiles réels restent, plus discrets sous la peinture.
- Correctif : `echo_effect.gd` ignore les polygones de surface nulle (début de croissance des flaques), qui
  faisaient échouer la triangulation de Godot (« Invalid polygon data »).
