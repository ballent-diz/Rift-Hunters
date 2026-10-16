# Chasseur v2 — livraison visuelle C5, première partie

## Périmètre

Habillage du futur arbre, maquettes statiques, 24 prompts d’icônes et deux familles d’effets.
Aucun fichier de `src/`, scène fonctionnelle du refuge ou comportement de sort n’est modifié.
Claude raccorde ces ressources dans C1/C2. Les dix autres familles d’effets restent à livrer
progressivement ; C5 reste « En cours (Codex) ».

## Livre des maquettes

Captures natives Godot, 1920 × 1080, dans `docs/previews/c5/` :

1. `overview.png` : tronc commun, quatre voies de cinq niveaux, compteur de points,
   trois builds et quatre emplacements A/E/R/F ; détail de Taille fendante à droite.
2. `focus.png` : détail de la Lame, variantes et clé de voûte ; tronc commun distinct.
3. `states.png` : quatre états et raccords, exclusivité A/B et unicité de clé de voûte.
4. `effects.png` et `effects.webp` : les six formes des deux premiers sorts, avec le vrai
   sprite du Chasseur à l’échelle du monde, sans caméra ni zoom de gameplay.

Les glyphes internes des nœuds sont des repères temporaires de maquette. L’apprentissage
permanent avec des Éclats et l’activation par Points de Chasseur sont présentés séparément.
L’exemple active 20 points : Vigueur 1, Entraînement 1, Taille 2, Ruée tranchante 2,
Tourbillon 1, Bond 2, Maître-lame 4, Lance 2, Rupture 2, Propagation 2, Résonance 1.
Le Troisième sceau est un déblocage de campagne du tronc, pas une cinquième voie.
Les rangs/chiffres, restrictions de chapitre et états effectifs seront fournis par C2.

Reproduire les captures : lancer `res://tools/art/c5_preview.tscn` avec le moteur graphique,
argument `--out=res://docs/previews/c5`. L’outil rend dans un SubViewport 1920 × 1080 ;
la résolution de la fenêtre ne recadre pas les captures. Il ne crée aucun bouton fonctionnel.
Puis `python tools/art/encode_c5_preview.py` assemble les 48 images natives en WebP animé à 24 i/s.
Les images intermédiaires restent locales et le dossier de captures est ignoré par Godot.

## Ressources pour C2

38 SVG et `catalog.json` : `assets/ui/hunter_tree/`. Tous sont déclarés dans
`assets/asset_manifest.json` sous `ui.hunter_tree.*`. Le catalogue donne les dimensions,
marges de découpe et rectangles d’icône. Lire aussi le README de ce dossier.
Le fond japonais nocturne est la texture existante du refuge ; les cadres reprennent
le bleu nuit, le cuivre et l’ivoire des menus, avec des accents or/cyan/lilas discret/jade.
Verrouillage, disponibilité, apprentissage et activation ont des signes distincts.

Tous les textes des maquettes sont dans `i18n/strings.csv`, clés `C5_*`, en français et anglais.
Les identifiants des sorts futurs du catalogue sont provisoires côté ressources : conserver
la correspondance avec les identifiants définitifs choisis par C1, sans copier la logique
depuis `mockup_data.json`. Les clés C5 sont réutilisables par C2.
À petite résolution, C2 doit privilégier une vue de voie avec défilement et détail latéral,
plutôt que réduire tout le panorama : corps de texte d’au moins 16 px et cadres non déformés.

## Icônes à générer par le propriétaire

24 prompts complets et recettes : `assets/concepts/incoming/ui.hunter_tree_icons/PROMPTS.md`
et `prompts.json`. Chaque `icon.hunter.<id>/job.json` attend son image dans `source/icon.png`.
Le dossier incoming est ignoré par Godot ; aucune image source ou fichier `.import` n’y est ajouté.

Les prompts suivent `docs/ART_BIBLE.md` : pixel art net, palette maîtrisée, lumière haut gauche,
contour sombre, fond transparent, blanc/cyan allié ; aucun grand halo magenta ennemi.
Les variantes A/B utilisent l’icône du sort avec un badge, pas 24 illustrations supplémentaires.
Le propriétaire génère les images. Aucune icône définitive fictive n’est ajoutée au manifeste.

Après réception, importer chaque recette avec `python tools/art/import_sheet.py <chemin/job.json>`.
La catégorie `icon` est maintenant reconnue par le pipeline et range les planches dans
`assets/sprites/skills/hunter/`, et les icônes dans `assets/ui/icons/skills/`.
Les recettes prévoient une cellule 64 × 64, sujet de hauteur 50 px et fond alpha.
Contrôler les marges et la lisibilité à taille réelle avant d’accepter les images.

## Contrat des effets pour C1

Scènes autonomes dans `assets/vfx/hunter/`, identifiants `vfx.hunter.cleaving_slash`
et `vfx.hunter.prismatic_lance` dans le manifeste. Le champ `scene` désigne l’animation ;
le champ `sheet` est uniquement une affiche SVG de catalogue, pas une planche animée.
Ce sont des Node2D qui dessinent des formes nettes : aucun dégât, entrée, collision,
statut, déplacement du joueur ou accès au contexte de partie.

```gdscript
var effect = load("res://assets/vfx/hunter/cleaving_slash/cleaving_slash.tscn").instantiate()
effects_parent.add_child(effect)
effect.global_position = caster.global_position
effect.play(aim_direction, &"base")
```

`direction` est un vecteur monde ; la scène tourne depuis l’axe +X. Une direction nulle
utilise +X. Par défaut, `visual_finished` est émis en fin de lecture et l’effet se détruit.
`destroy_on_finish = false` permet la réutilisation. `seek_visual(seconds)` sert aux aperçus
et arrête la lecture temporelle. `duration()` donne la durée courante.

| Scène / variante | Durée | Taille en unités du monde |
|---|---:|---|
| Taille / `base` | 0,34 s | Balayage 120°, rayon 150, liserés et éclats |
| Taille / `whirlwind` | 0,55 s | Balayage complet de rayon 150, diamètre 300 |
| Taille / `thrust` | 0,40 s | Longueur 320, largeur 20, cœur ivoire 2 |
| Lance / `base` | 0,977 s | Portée 700, vitesse 950/s, pointe de largeur 28 |
| Lance / `fan` | 0,977 s | Trois traits à −14°, 0°, +14°, même portée |
| Lance / `overcharge` | 0,977 s | Même portée, pointe de largeur 42 et anneaux orbitaux |
| Lance / `charge` | Pilotée par C1 | Boucle locale, six fragments en orbite, rayon jusqu’à 27 |

Les durées de Lance comprennent 0,24 s de dispersion après la traversée. Les exports
`spell_range`, `projectile_speed`, `half_width`, `fan_angle_degrees`, `thrust_range` et
`half_angle_degrees` permettent à C1 de reprendre les vraies données du sort.
La taille visuelle ne définit jamais sa hitbox. Les dimensions de référence sont dans
les métadonnées `variants` du manifeste.

Pour Surcharge : `play(direction, &"charge")`, puis `set_charge_ratio(0..1)` pendant
la charge. Au lâcher, appeler `play(direction, &"overcharge")`. À l’annulation,
retirer l’effet. La charge réelle et la décision de tir restent dans C1.
La préparation de la lame précède son mouvement de quelques centièmes de seconde.
C1 peut lancer l’effet à l’armé et synchroniser le coup visuel à 0,10 s pour Taille,
0,16 s pour Tourbillon et Estoc, sans déduire un timing de dégâts depuis cette animation.
Les éclats sont décoratifs : enveloppe maximale d’environ 180 autour de la Taille,
et 360 × 80 pour Estoc. Les impacts de Lance peuvent dépasser le point final de 70 unités.
Ne pas attacher la lance à un projectile mobile en plus de sa translation interne :
la scène se place au point de tir et représente le trajet visuel complet.

## Suite du lot

Retour du propriétaire du 16 octobre pris en compte dans cette livraison : reprise de la
chorégraphie, préparation, balayage effectif, rémanences, filaments, cristaux à plusieurs
faces, fragments orbitaux, étincelles et dispersion. Les deux scènes restent marquées
`wip` tant que le propriétaire n’a pas validé leur rendu. La vitesse de projectile et les
portées de référence sont conservées ; les durées visuelles incluent la dissipation.

À produire au fil de C1/C2 : Bond de faille, Parade, Rupture, Cristal réfracteur,
Singularité, Mur de faille, Failles jumelles, Appel de meute, Égide de faille, Permutation.
Les images d’icônes seront importées après génération par le propriétaire.
La validation de la scène d’arbre fonctionnelle et des sorts raccordés revient à C1/C2.

## Vérifications de cette livraison

Import Godot terminé sans erreur. Validation des ressources : 71 entrées, 70 valides,
un placeholder préexistant (`monster.mirrorling`), aucune erreur. Captures natives des
trois maquettes et lecture des six variantes sur 48 images sans erreur de rendu.
Contrôle ciblé : 117 clés C5 uniques et complètes en FR/EN, 24 recettes d’import
avec chemins résolus, 40 nouvelles ressources présentes. Aucun changement dans `src/`.
Conformément à AGENTS.md, pas de relance de toute la suite pour ce lot visuel ;
le raccordement et les essais en jeu restent à faire dans C1/C2 puis par le propriétaire.
