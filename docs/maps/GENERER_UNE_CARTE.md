# Générer une carte correcte du premier coup

Pour le propriétaire (génération des images) et Codex (intégration). Complète [../MAP_GUIDELINES.md](../MAP_GUIDELINES.md)
(critères de qualité, à relire) ; la suite, de l'image au niveau jouable, est dans
[DE_L_IMAGE_AU_NIVEAU.md](DE_L_IMAGE_AU_NIVEAU.md).

> **Qualité imposée : [QUALITE_DES_CARTES.md](QUALITE_DES_CARTES.md)** (fait foi). Toute carte a la finesse et l'échelle
> de détail des Ruines des Cascades et des Hautes Terres, par unité du monde : composition validée (plan figé), puis
> une région redessinée par carré de 1672 unités (`tools/art/map_regions.py`), puis contrôle chiffré
> (`tools/art/check_map_quality.py`, verdict « conforme » obligatoire). Un agrandissement de la composition n'est
> jamais une carte finale.

## 1. Préparer le plan avant de générer

Une carte de campagne est en mode « vagues par zone » ([../design/MODE_VAGUES_PAR_ZONE.md](../design/MODE_VAGUES_PAR_ZONE.md)).
Faire un croquis rapide (même à main levée) avant le prompt :

- **Format** : petit = 3:1 (5016 × 1672 unités, comme les Ruines des Cascades), intermédiaire = 3:2 (5016 × 3344),
  grand = 1:1 (5016 × 5016, comme les Hautes Terres d'Orage).
- **Départ** : un endroit dégagé près d'un bord, avec une grande place autour.
- **Zones** : 2 à 3 grandes aires de combat qui se suivent, chacune avec au moins une grande clairière.
- **Passages entre les zones** : de vrais goulets (route, escalier, pont), nets et assez courts pour qu'une barrière
  les ferme ; jamais une frontière floue de plusieurs centaines d'unités.
- **Fin de carte** : voir § 1 bis. Une arène séparée n'est **pas obligatoire** ; si la carte en a une, sa forme est
  propre à cette carte (jamais un cercle, jamais un carré ou un trapèze par habitude). Espace libre d'au moins 900 unités
  de large pour le combat, une ou deux entrées larges.
- **Coupures volontaires** (pont cassé, rivière) : clairement infranchissables, avec un détour large et visible.

## 1 bis. Variété : chaque carte a son propre agencement (décision du propriétaire, 23 octobre 2026)

Les générations précédentes ont répété le même schéma (arène ronde ou carrée au bout, deux piliers ou rochers d'abri).
C'est interdit : **le prompt d'une carte donne son plan ; les cartes déjà faites ne servent que de référence de style,
jamais de modèle de plan.**

- **Changer au moins trois de ces points** par rapport à la carte précédente du chapitre : format, sens du parcours
  (gauche-droite, bas-haut, diagonale, boucle, spirale), forme des zones (cuvette, vallée longue, croissant, terrasses,
  île, intérieur en ruine), nature des passages (pont, rampe, brèche, tunnel, gué, escalier), fin de carte.
- **Fin de carte**, au choix du plan (varier d'une carte à l'autre) :
  - **pas d'arène** : le gardien apparaît dans la dernière zone et le jeu dessine lui-même le cercle d'énergie du
    combat (`ArenaData.finale_radii`) ; la dernière zone doit simplement offrir un grand espace libre ;
  - **arène de forme libre** : croissant, longue corniche, cratère, fourche en Y, salle en ruine, île au milieu d'un
    danger, terrasses étagées, plateau allongé… **Jamais ronde, jamais carrée ni trapézoïdale par défaut.**
- **Abris dans le combat final** : seulement si le plan de la carte les demande (0 à 3), de natures différentes d'une
  carte à l'autre. Les deux rochers-abris des cartes 5 et 6 étaient propres à ces cartes : ce n'est pas une règle.
- **Mécanique de carte** : son support graphique doit être simple à dessiner et à contrôler. Si elle repose sur des
  objets (bulbes, totems, nids…), ce sont des **sprites séparés** placés par le jeu, pas des éléments peints dans la carte.

## 2. Mesures qui comptent (en unités du monde et en part de l'image)

Le Chasseur tient dans une case de 32 unités (cellule de sprite de 64 pixels à l'échelle 0,5).
Sur une carte de 5016 unités de large :

| Élément | Minimum | Part de la largeur de l'image |
|---|---|---|
| Route principale | 200 unités | ≥ 4 % |
| Passage, pont, escalier | 120 unités | ≥ 2,5 % |
| Clairière de combat | 750 unités | ≥ 15 % |
| Arène du boss | 900 unités | ≥ 18 % |
| Sol praticable sur toute la carte | — | ≥ 50 % de la surface |

Un passage plus étroit que 120 unités bloque les hordes et les Échos (la navigation garde une marge de 16 unités de
chaque côté). Vérifier aussi l'échelle des portes, marches et arbres par rapport au Chasseur ([../MAP_GUIDELINES.md](../MAP_GUIDELINES.md)).

## 3. Lisibilité du praticable

Le joueur, les Échos et les ennemis doivent comprendre d'un coup d'œil où l'on marche. Les collisions sont ensuite
détourées à la main d'après l'image : plus l'image est franche, plus le détourage est rapide et juste.

- **Praticable** : terre, herbe rase, pavés, dalles, ponts, escaliers. Sol plat et uni, petits détails seulement.
- **Bloqué** : eau, falaises, forêts denses, bâtiments, murs, gouffres, cristaux géants.
- **Bord net** entre les deux : une rive, un pied de falaise, une lisière. Pas de dégradé ambigu.
- **Rien d'isolé sur les routes** : ni arbre seul, ni rocher, ni pilier, ni clôture au milieu d'un chemin ou d'une
  place (les petits cailloux sont permis : ils restent traversables).
- **Bords de la carte** fermés par du décor (falaises, forêt, eau) : pas de route qui sort de l'image.

## 4. Prompt type de la COMPOSITION (en anglais, plus fiable pour les générateurs)

Ce prompt produit la composition (étape 2 de [QUALITE_DES_CARTES.md](QUALITE_DES_CARTES.md)), pas la carte finale :
la finesse ET la taille des objets viennent ensuite des régions (preuve dans QUALITE_DES_CARTES.md § 2). Remplacer
les éléments entre crochets. Joindre les cartes déjà faites du chapitre (style).

```
Top-down video game map for Rift Hunters, a 2D survivor-like. Full-bleed [3:1 wide panorama | 3:2 | square],
maximum resolution, no borders, no text, no UI, no characters.
Theme: [chapter landscape, e.g. misty pine highlands with stone ruins and rivers].
Layout from [left to right | top to bottom]: [start area: description], [zone 1: description],
[passage: wide stone stairs / bridge / road gap], [zone 2: description], [passage], [final fight: the shape chosen
in THIS map's plan (§ 1 bis) — or no arena, the last zone simply keeps a huge open area].
At least 55% of the image is flat, open, unobstructed walkable ground (earth, short grass, paving).
Main roads at least 4% of image width; every bridge, stair and passage at least 2.5% of image width.
Each zone contains a HUGE open clearing for fighting hordes. Trees, rocks, ruins and buildings are grouped on the
edges of open spaces and along the map border, never in the middle of roads or clearings.
Clear, sharp boundary between walkable ground and blocking scenery (water, cliffs, dense forest, walls).
The map border is closed by scenery: no road leaves the image.
[Intentional cut: the bridge at x=..%, y=..% is destroyed, two short ends anchored to their banks, wide water gap.]
Uniform overhead game camera, same scale everywhere, top-left light. Doors, stairs and trees in proportion to a
small 32-unit-tall character. Sharp detailed fantasy game art matching image2 (reference): intricate stone,
fine foliage, textured earth. NOT blurry, NOT smooth plastic, NOT coarse pixels, NOT photorealistic.
One coherent landscape, no visible seams or pasted rectangles.
```

Pour une retouche locale (passage trop étroit, objet sur une route), recadrer la zone et demander une modification
locale en gardant le reste identique (voir les prompts « vertical » et « detail » de
`assets/concepts/incoming/map.three_rifts/job.json`).

## 5. Contrôle avant import (5 minutes)

- [ ] Format exact (3:1, 3:2 ou 1:1), sans bord ni texte ni personnage.
- [ ] Chaque zone a une grande clairière ; routes et passages assez larges (tableau ci-dessus, à l'œil sur la largeur).
- [ ] Passages entre zones nets et courts (une barrière peut les fermer).
- [ ] Fin de carte conforme au plan de cette carte (§ 1 bis) : pas de cercle ni de carré par défaut, pas d'abris non demandés,
  agencement différent de la carte précédente.
- [ ] Rien au milieu des routes ; bords de carte fermés ; coupures volontaires évidentes.
- [ ] Pas de raccord visible, pas d'objet flottant, échelle cohérente avec le Chasseur.
- [ ] Après les régions : planche `map_regions.py compare` jointe, objets à la taille des Ruines.
- [ ] Après les régions : `tools/art/check_map_quality.py` **conforme** (densité, finesse homogène, fidélité au plan),
  rapport joint à la fiche de livraison.

Si un point échoue, régénérer ou retoucher localement **avant** l'intégration : corriger une image coûte moins
cher que corriger des collisions.

## Cadence optimisée — décision du propriétaire du 19 octobre 2026

Éviter les reprises tardives de toute une carte :

1. Fixer le plan, les surfaces ouvertes et l'échelle avec les références avant la génération.
2. Densité fixée par [QUALITE_DES_CARTES.md](QUALITE_DES_CARTES.md) : une région par carré de 1672 unités, au moins
   0,75 pixel de vrai détail par unité, 2,25 pixels par unité livrés. La résolution demandée dans un prompt n'est pas
   une garantie : `map_regions.py assemble` signale une région trop petite.
3. Contrôler un petit secteur représentatif au zoom réel, avec le Chasseur et un Écho, **avant** de détailler
   toute la carte. Si le sol ou l'architecture ne conviennent pas, corriger la méthode à ce stade.
4. Regrouper les retouches indépendantes dans une seule passe. Réutiliser la composition validée et ne pas
   enchaîner plusieurs grilles de détails à des résolutions différentes.
5. Effectuer un seul contrôle ciblé de fin de lot ; aucune suite complète pour les images.
6. Publier un aperçu concret et, si demandé, une PR de brouillon avec les points non validés explicitement
   décochés. Ne pas annoncer le lot terminé tant que ses critères ne sont pas satisfaits.
