# C8 — fiche de génération et d’import

Préparation du lot : neuf nouveaux Échos, Mirelle et rework de Cendrelame. Génération par le propriétaire.
Les images ne sont pas encore livrées ; aucun nouveau sprite n’est déclaré final.

## Commencer ici

[Prompts du lot C8 uniquement](C8_PROMPTS.md) : 11 références et 55 bandes d’animation.
Le catalogue commun [art_prompts.md](../art_prompts.md) contient les mêmes sections.
Les deux fichiers sont générés par tools/art/prompts.py à partir de tools/art/echo_sprite_specs.py.
Modifier la source puis relancer le générateur pour éviter des versions différentes.

1. Générer la **référence seule** de l’Écho choisi. Vérifier sa silhouette face aux Échos existants et la palette.
   La planche assets/concepts/incoming/planches_communes/sprite_monsters.png peut être jointe comme référence
   de style uniquement ; l’image de la nouvelle créature devient ensuite la référence d’identité des animations.
2. Conserver cette référence approuvée. Pour chaque animation, joindre **la même référence** au générateur
   en mode référence de personnage / image-to-image ; garder les réglages de style et l’identité constants.
   Une seed fixe peut aider si le générateur le permet, mais ne remplace pas la référence.
3. Copier le prompt complet de l’animation, avec le style commun. Le prompt négatif est donné dans chaque section.
4. Générer une seule animation par image : une seule rangée, jamais plusieurs créatures ou plusieurs lignes.
   Les poses sont séparées par du vert vide. Si le générateur limite le format panoramique, laisser du vert
   au-dessus et au-dessous de la rangée ; ne pas répartir les poses sur deux lignes pour remplir l’image.
5. Garder les originaux dans source/. Déposer les bandes de travail à côté de job.json avec les noms ci-dessous.
   Commencer par la référence et idle permet de corriger le style avant de produire toutes les bandes.

| Fichier | Frames | Cadence d’import | Boucle |
|---|---:|---:|---|
| source/reference.png | 1 pose | — | — |
| idle.png | 8 | 8 images/s | Oui |
| move.png | 8 | 12 images/s | Oui |
| attack.png | 7 | 16 images/s | Non |
| technique.png | 8 | 16 images/s | Non |
| death.png | 8 | 10 images/s | Non |

Ces cadences décrivent l’animation graphique. Elles ne changent ni les attaques ni les sorts du lot C7.
Les gestes de technique proposés sont des intentions visuelles ; Claude conserve la responsabilité des règles.

## Avant de déposer une bande

- Même créature que la référence : nombre de pattes, cornes, facettes, rayures et proportions inchangés.
- Vue de côté vers la **droite**, légère plongée trois quarts, caméra et taille fixes ; la course se joue sur place.
- Aucun bout d’aile, queue, arme ou effet coupé ; silhouettes séparées et marges vertes suffisantes.
- Pieds sur une ligne stable pour les terrestres. Pour les volants, bas du corps stable, aucune pose d’atterrissage ;
  les effets et petits éclats restent au-dessus de cette ligne afin de ne pas faire sauter l’ancrage.
- Fond strictement uni **#00D648**, sans halo vert peint, décor, ombre portée, lettres, chiffres, grille ou watermark.
- Idle et move bouclent sans saut. Attack et technique montrent une anticipation, une frappe et un retour.
- La dernière pose de death conserve quelques fragments visibles : une cellule entièrement verte devient vide
  après détourage et doit être traitée séparément par l’importeur ; éviter ce cas dans les sources initiales.

## Dossiers prêts

Sous assets/concepts/incoming/, un dossier par identifiant :

| Dossier | Écho | Appui |
|---|---|---|
| monster.cinderwing | Pyraile | Volant, hover 10 |
| monster.magmander | Scoriade | Sol |
| monster.hollowflame | Spectrâtre | Volant, hover 8 |
| monster.moonspore | Sporelune | Sol |
| monster.gravishell | Gravelune | Sol ; seul l’anneau orbite |
| monster.grovestag | Sylvécaille | Sol |
| monster.sunclaw | Solgriffe | Sol |
| monster.glowmoth | Lueurine | Volant, hover 10 |
| monster.stormshell | Égidor | Sol |
| monster.mirrorling | Mirelle | Volant, hover 8 |
| monster.ashblade | Cendrelame, rework | Sol |

Chaque dossier contient job.json en statut wip, README.md et source/ pour les originaux.
Aucun fichier .import n’est ajouté sous incoming/ (exclu de Godot par son .gdignore).

## Échelle et détourage

Les Échos actuels ne suivent plus tous l’ancien exemple 64 × 64 de la Bible. Mesure de référence sur
la première pose de Mousseroc : 74 pixels visibles × scale 0,65 = **48,1 unités monde**.
La recette C8 suit scale 0,75 et anchor_mode mass indiqués dans ECHOS.md, avec une hauteur cible 64
pour une créature standard : **48 unités monde hors contour**, environ 49,5 avec le contour ajouté,
soit une hauteur voisine de Mousseroc. Les volants sont plus légers,
les grandes oreilles ou les bois comptent dans la silhouette ; la comparaison visuelle reste indispensable.
Le Cendrelame actuel ne fait qu’environ 28,6 unités de haut : le rework cible 48 pour rejoindre ce niveau de détail.

Cellule commune de travail : 128 × 112, ancre (64, 102), avec de la marge pour ailes, queue et gestes.
La cellule ne définit pas la taille apparente : celle-ci dépend de target_height × scale.
keep_size=false impose la même échelle à toutes les animations à partir de la hauteur médiane de idle.
Ne pas redimensionner chaque bande indépendamment : cela ferait grossir ou rétrécir la créature entre animations.
Si une pose devient trop large pour la cellule, vérifier le découpage et adapter la cellule de travail
sans changer l’échelle effective ni rogner les appendices.

Fond #00D648, tolerance 30 et holes 12 : point de départ à ajuster après aperçu. La palette commune reste à 32 couleurs,
avec contour discret. **despill=false** : le retrait global du vert supprimerait aussi la mousse et les feuilles.
Ne pas augmenter aveuglément la tolérance : contrôler les verts légitimes et les petits détails.
Les volants utilisent hover pour relever le corps au-dessus de l’ancre ; aucune ombre n’est peinte dans la source.

## Import au fil des livraisons

Exemple pour Pyraile, lorsque ses cinq bandes sont présentes :

~~~bash
python3 tools/art/import_sheet.py assets/concepts/incoming/monster.cinderwing/job.json --preview-only
~~~

L’aperçu n’écrit pas les sprites du jeu ni le manifeste. Vérifier orientation, nombre de poses, découpage,
transparence, palette et absence de halo. S’il manque une bande, ne pas lancer cette recette telle quelle ;
préparer un essai temporaire hors des assets de production ou attendre la bande manquante.

Après ce premier contrôle :

~~~bash
python3 tools/art/import_sheet.py assets/concepts/incoming/monster.cinderwing/job.json
godot --headless --import --path .
tools/run_tests.sh assets
tools/run_tests.sh art
~~~

L’import crée l’entrée monster.cinderwing dans assets/asset_manifest.json, la feuille et l’icône.
Aucune donnée data/monsters/*.tres n’est créée pour cela. Les sprites en jeu de Cendrelame et le repli de Mirelle
restent inchangés tant que leurs nouvelles images ne sont pas importées.

Contrôle final par Écho : animation en boucle, ancre et pieds, comparaison avec Mousseroc et le Cendrelame
actuel, puis rendu sur le sol des Ruines des Cascades. Une fois le visuel validé, passer le job à final et réimporter.
La planche finale montrera les **16 Échos côte à côte à la même échelle**, sans agrandir chaque silhouette pour
remplir sa case. Elle sera produite après réception des images ; aucun emplacement vide ne vaut validation.

## Corrections à demander au générateur

| Problème observé | À régénérer | Ajout ciblé au prompt |
|---|---|---|
| Anatomie différente entre poses | Bande concernée avec la référence approuvée | Preserve exactly the reference anatomy and appendage count in every frame; no creature redesign. |
| Images collées ou effets qui relient deux poses | Bande concernée | Separate all poses with clear green columns; effects stay inside each cell; no trail between frames. |
| Orientation gauche ou face | Bande concernée | Every frame faces RIGHT in the same slight top-down side view; no rotation toward the camera. |
| Taille ou caméra changeantes | Bande concernée | Fixed camera and identical body proportions in all frames; run in place without changing scale. |
| Pieds ou corps flottant qui sautent | Bande concernée | Stable supporting-foot baseline or lower-body reference line; no particles below that line. |
| Halo vert ou dégradé | Bande concernée si le détourage ne suffit pas | Flat exact #00D648 background, crisp silhouette edges, no green bounce light or glow on the body. |
| Aile ou arme coupée | Bande concernée | Full creature and effects within every cell; add margins without shrinking only some frames. |
| Mauvais nombre de frames | Bande concernée | EXACTLY the requested number of poses in one horizontal row, no extra pose or blank last cell. |

## État de cette livraison

Préparation uniquement : 66 prompts et 11 recettes. Les images du propriétaire, leur validation et la planche
finale des 16 sont encore attendues. La PR de préparation ne remplace aucun sprite existant et ne prétend
pas terminer la phase d’import du lot C8.

Vérifications de la préparation : 11 références + 55 prompts d’animation, 11 recettes wip,
quatre volants correctement relevés et aucun .import dans leurs dossiers. Import Godot réussi ;
tools/run_tests.sh complet terminé avec code 0 : 207/207 tests unitaires, scripts, persistance,
assets (148 entrées, zéro erreur), art, smoke et lint réussis. Ces résultats valident la préparation
et l’état actuel du jeu ; ils ne valident pas les sprites encore à recevoir.
