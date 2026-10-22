# Mission Claude — intégrer le Dévoreur des Sources, finale du chapitre 1

Après fusion de la PR #55, récupère `main` à jour et crée une branche dédiée `claude/devoreur-sources`.
Lis `AGENTS.md`, `docs/design/CARTES.md` (Source des Cascades, carte 5), les documents de campagne,
`docs/art/MONSTRES_CHAPITRE2.md` et `docs/art/DEVOREUR_SOURCES_EFFETS.md`.

## Objectif

Intégrer le Dévoreur du chapitre 1 dans la Source des Cascades, avec ses compétences réellement
jouables, ses quinze animations et les effets Godot préparés par Codex. Le propriétaire a validé
le design du boss : titan de pierre moussue et de racines, énorme gueule et cœur de Faille violet.
Il doit être plus imposant qu’un gardien et rester lisible face au Chasseur accompagné de ses Échos.

Ne redessine pas le boss ni ses effets. L’identifiant visuel est `boss.source_devourer` ; les scènes
sont dans `assets/vfx/bosses/source_devourer/`, avec `catalog.json` et quatorze entrées
`vfx.boss.source_devourer.*` au manifeste. L’identifiant de gameplay et les clés de traduction
restent à créer ; utilise un nom FR/EN cohérent avec « Dévoreur des Sources / Devourer of the Sources ».
Ne modifie pas les autres familles de monstres dans ce lot.

## Combat à raccorder

Réutilise l’architecture de boss et de phases existante. Garde toutes les valeurs d’équilibrage
dans les données, avec les boss existants comme référence. N’utilise jamais une durée d’effet
graphique comme source de dégâts. Le changement de phase doit être un événement du gameplay,
avec son seuil configurable ; le visuel ne lit pas les PV.

Phase 1 :

- Griffes : anticipation visible puis frappe dans un secteur orienté ; animation `attack`, effet
  `claw`. La visée est décidée par le combat, pas par la scène d’effet.
- Double écrasement : poings levés, impact télégraphié au sol ; `heavy_slam` pour le sprite et
  l’effet. Les fissures dessinées ne sont pas des hitboxes.
- Souffle de Faille : charge de la gueule puis attaque en ligne ; `rift_breath`. Le télégraphe
  annonce la largeur et la longueur réellement dangereuses.
- Racines : balayage devant le boss ; `root_sweep`, avec avertissement en secteur et rayon réel.
- Appel : `summon`, puis invocations dans des positions praticables et confirmées, avec un plafond
  d’invocations actives. Transmets ces positions à `set_secondary_offsets` après conversion en local.
- Rugissement : `roar` pour l’introduction ou un événement choisi par le combat. Aucun dégât
  implicite simplement parce que l’animation joue.

Phase 2 :

- Joue `transform` une fois à la transition ; utilise ensuite `phase2_idle` au repos.
- Raccorde `phase2_attack` au VFX `phase2_claw`, puis `phase2_breath` et `phase2_slam` à leurs VFX.
- Renforce le rythme à travers les paramètres des données, avec des fenêtres d’esquive et de
  récupération. Pas de rayon instantané ou de dégâts ajoutés par une animation.
- Si tu utilises les fragments de Faille, `rift_fragment` est un habillage disponible : le
  projectile, sa trajectoire et sa collision restent entièrement dans la simulation.

`hurt` sert aux réactions importantes et ne doit pas interrompre chaque compétence à chaque coup.
`death` doit terminer le combat, retirer les attaques encore actives et débloquer la progression
du chapitre une seule fois. Les invocations ne doivent pas empêcher indéfiniment la fin de carte.

## Arène et deux rochers

Conserve le plan et les collisions approuvés de la Source des Cascades. L’arène finale n’est pas
circulaire et contient deux gros rochers derrière lesquels le joueur doit pouvoir se protéger.
Utilise leurs collisions réelles pour les tirs et les souffles : pas de collision avec un simple
pixel du décor. Tronque aussi le dessin des rayons à la première obstruction pour ne jamais
montrer une attaque qui traverse une couverture réellement protectrice. N’ajoute pas d’obstacle
sur les chemins et ne modifie pas les peintures de collision du propriétaire.

Le combat commence dans l’arène finale après les zones précédentes, selon le directeur existant.
Conserve les barrières, l’ordre du parcours et l’équipe Chasseur + Échos. Ne change pas les autres
cartes ni leurs gardiens.

## Raccordement graphique exact

Les animations du sprite ont six poses chacune. Les durées, noms et positions de déclenchement
sont dans les deux fiches artistiques. Utilise les API visuelles existantes pour changer
d’animation, d’orientation et d’échelle ; évite les retours immédiats à `idle` au milieu d’un coup.
Les sprites de mort et d’impact doivent garder leur taille et leur ancre.

Pour les effets :

1. Instancie la scène autonome dans le monde et fournis origine, direction, rayon, largeur,
   longueur et durée de présentation issus de la compétence réelle.
2. Attache les souffles à un point de gueule configurable, correctement retourné quand le boss
   regarde à gauche. Les impacts au sol se placent au contact confirmé, pas au centre du sprite.
3. Crée `indicator.tscn` pendant la préparation, avec `target_shape` égal à `area`, `line` ou `cone`,
   et exactement la géométrie de l’attaque. Retire-le en cas d’annulation, changement de phase ou mort.
4. Au lancement ou à l’impact confirmé, utilise `play` ou `play_from` pour synchroniser le dessin.
   N’attends pas de nouveau la préparation si l’effet est instancié après le contact.
5. Pour un projectile déjà mobile, laisse `travel_distance = 0` sur son VFX : ne double pas son
   déplacement avec le trajet graphique. Pour une invocation, aucun spawn ne dépend du signal VFX.
6. `visual_finished` ne déclenche ni dégâts, ni invocation, ni transition de phase. Les scènes
   n’appellent aucun code de combat. `release()` dissipe un effet maintenu.

Conserve la palette et les contrastes livrés : effets violets/pierre sous les personnages,
télégraphes corail à bord sombre, sans disque lumineux rempli qui cacherait le Chasseur.
Préserve surtout la lisibilité des projectiles ennemis. Plafonne les effets décoratifs comme
décrit dans la fiche, sans supprimer un avertissement nécessaire à une attaque réelle.

## Vérification et livraison

Tout texte joueur dans `i18n/strings.csv`, FR et EN ; docs et commits en français. Mets à jour
la feuille de route dans ta branche. Vérifie les deux phases, les annulations, la mort, les
invocations, l’orientation gauche/droite et la protection derrière chacun des deux rochers.
Fais un contrôle ciblé du nouveau boss et des ressources selon `AGENTS.md`, sans répéter les
suites sans raison. Ajoute des captures 1280 × 720 et un court aperçu du combat, son coupé.
Ouvre une PR vers `main` avec les contrôles exécutés et leurs résultats. Ne fusionne pas directement.
