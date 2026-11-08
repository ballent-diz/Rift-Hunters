# Bible graphique — pixel art

Référence unique pour tout visuel du jeu, qu'il soit généré par `tools/art/` (procédural),
dessiné à la main ou produit par un générateur d'images puis importé. Les prompts de génération
(`docs/art_prompts.md`) et l'outil d'import (`tools/art/import_sheet.py`) appliquent ces règles.

## 1. Intention

- Dark fantasy « Faille » : fonds sombres et désaturés, créatures détaillées aux accents lumineux.
- **Lisibilité d'abord** (pilier 1 du GDD) : à 300 ennemis, on doit voir le Chasseur, ses Échos,
  les projectiles dangereux et les télégraphes. Un beau sprite illisible est refusé.
- Pixel art net : pixels francs, aucun flou d'anticrénelage, aucun dégradé lisse.

## 2. Échelle et tailles

La caméra de jeu est zoomée × 4/3. Avec `"scale": 0.5` dans le manifeste, **1 pixel d'art ≈ 1 pixel
d'écran en 1080p** : le détail dessiné est le détail vu. Toutes les entités utilisent cette échelle
(densité de pixels identique partout).

| Catégorie | Cellule | Ancre | Hauteur visible (`target_height`) |
|---|---|---|---|
| Chasseur | 64×64 | (32, 54) | 40–46 |
| Échos (au sol) | 64×64 | (32, 54) | 38–50 |
| Échos (volants) | 64×64 | (32, 58), `hover` 6–10 | 34–44 |
| Corrompus petits (Grouillard) | 48×48 | (24, 42) | 22–28 |
| Corrompus (autres, élites) | 64×64 | (32, 54) | 30–50 |
| Dévoreurs | 320×320 | centre de masse : Nébulorax (160, 160) | 220–280 |
| Projectiles / effets | 32×32 ou 64×64 | centre | — |

- L'**ancre** est le point posé au sol (les pieds), sauf pour les Dévoreurs (centre du corps).
- Les élites sont agrandies par le moteur : ne pas produire de feuille séparée.
- Ordre de grandeur : largeur visible en pixels d'art ≈ 1,6 × `size` du placeholder (`VisualData`).

## 3. Lumière, couleurs, contour

- **Lumière principale en haut à gauche.** Les faces tournées vers le haut-gauche sont claires,
  le bas-droite est dans l'ombre.
- **Liseré de Faille** : fine bande violette (`#b56cf0`) sur les bords bas-droite, à 40 % environ.
  C'est la signature visuelle du jeu ; elle reste discrète.
- **Rampes de 7 tons par matériau, avec glissement de teinte** : les ombres glissent vers le
  violet-bleu (teinte 262°), les lumières vers l'ambre (48°). On n'assombrit jamais en ajoutant
  simplement du noir. Les rampes sont définies dans `tools/art/pixelforge/palette.py` :

  | Matériau | Couleur médiane | Usage |
  |---|---|---|
  | obsidian | `#2f2a3c` | carapaces, plaques sombres |
  | ember | `#f07a2a` | braises, veines de feu (émissif) |
  | stone / moss | `#5d616d` / `#4f9446` | golems, lichen |
  | glass / silver | `#3fa6c4` / `#7c86a3` | cristaux, ailes, lames |
  | storm / gold | `#e0c232` / `#d9a531` | foudre, runes |
  | corrupt / void / flesh | `#6a3378` / `#6a1fd0` / `#a24a72` | Corrompus, Faille |
  | shade / char | `#36265a` / `#4a1f18` | variantes sombres, calcinées |

- **Contour sélectif** : `#0e0a17` côté ombre, contour teinté (version sombre du matériau) côté
  lumière. Pas de contour noir uniforme.
- **Éléments émissifs** (yeux, veines, cœurs) : couleur saturée sans ombrage + halo de 1 à 2 pixels.
- **Code couleur fonctionnel** (GDD § 2, non négociable) :
  - violet → magenta = Vide, Corrompus, danger. **Aucun Écho n'utilise le magenta comme accent principal.**
  - blanc / cyan = Chasseur ;
  - chaque Écho a sa couleur vive propre (braise, lichen, prisme, ronce, foudre, ombre, miroir).
- Palette par feuille : 24 à 32 couleurs au maximum (l'import réduit automatiquement).

## 4. Silhouette et détail

- Test de silhouette : remplie en noir, la créature doit rester reconnaissable.
- 3 niveaux de détail : la masse (silhouette), les formes secondaires (membres, plaques, ailes),
  les accents (yeux, veines, reflets). Les accents sont rares : ils guident l'œil.
- Matières lisibles : plaques fissurées, écailles, facettes de cristal, mousse tachetée.
- Vue de côté tournée **vers la droite**, légère plongée 3/4. Le moteur retourne le sprite.
- **Pas d'ombre au sol dans le sprite** : le moteur la dessine (ellipse sous l'ancre).
- Rien ne dépasse de la cellule ; laisser 1 à 2 pixels de marge pour le halo et le contour.

## 5. Animations

| Catégorie | Animations (frames @ fps) |
|---|---|
| `player` | idle 6@8, move 8@12, dash 4@16, hurt 3@12, death 8@10 |
| `monster` | idle 8@8, move 8@12, attack 7@16, technique 8@16 |
| `enemy` | move 6@10, attack 4@12 (si elle attaque), death 6@12 |
| `boss` | idle 6@8, move 8@8, attack 6@12, death 8@10 + celles de sa fiche concept |

**À partir du chapitre 2** (le chapitre 1 garde ses planches) : normaux = déplacement + attaque (6 × 2, mort par effet
commun) ; élites = planche A déplacement / attaque / mort + planches de techniques ; boss = 4 planches et plus.
Règles complètes, mécaniques et montée en puissance : [design/MONSTRES.md](design/MONSTRES.md).

- Toutes les frames : même créature, mêmes proportions, même palette, mêmes pieds sur la même ligne.
- Boucles (`idle`, `move`) : la dernière frame s'enchaîne sur la première sans saut.
- Attaques : anticipation (1–2 frames) → frappe (1–2 frames, la plus lisible) → retour.
- Une animation manquante peut réutiliser une autre ligne (`aliases` dans l'import).

## 6. Deux sources, un seul format

| Source | Outil | Statut dans le manifeste |
|---|---|---|
| Procédural (sprites de travail) | `python3 tools/art/build.py <préfixe>` | `wip` |
| Images importées (générateur, dessin) | `python3 tools/art/import_sheet.py <job.json>` | `final` |

- Un statut `final` n'est **jamais** écrasé par la génération procédurale.
- Mode d'emploi de l'import : `assets/concepts/incoming/README.md`. Prompts : `docs/art_prompts.md`.

## 7. Liste de contrôle avant validation

1. Aperçu agrandi (`assets/concepts/previews/`) : silhouette, lumière haut-gauche, liseré violet discret.
2. `godot --headless --import --path .` puis `tools/run_tests.sh assets` : aucune `ERREUR`.
3. Capture en jeu (`tools/screenshot.tscn`) : lisible au milieu de la foule, distinct des Corrompus.
4. Le code couleur fonctionnel est respecté.

## Échelle des décors — règle du propriétaire, 3 novembre 2026

Les décors ont tous la même densité (2,25 pixels par unité du monde), mais les **éléments peints** doivent aussi être à
l'échelle des personnages. Référence : le **Chasseur mesure environ 52 unités** de haut (Cendrelame, environ 1,3 fois
plus) ; les Ruines des Cascades (carte 1) sont la carte étalon.

| Élément peint | Taille attendue (unités du monde) | Par rapport au Chasseur |
|---|---|---|
| Marche d'escalier (profondeur) | 12 à 16 | environ 1/4 de sa hauteur |
| Pavé, dalle | 15 à 26 | au plus 1/2 de sa hauteur |
| Porte, arche de passage | 75 à 90 de haut | environ 1,5 fois sa hauteur |
| Colonne, pilier | 30 à 45 de large | moins de sa largeur d'épaules × 2 |
| Arbre adulte | 120 à 200 de haut | 2,5 à 4 fois sa hauteur |
| Abri (bloc, rocher) | 110 à 160 de large | assez pour s'y cacher entièrement |

Chaque carte se valide sur une **capture au zoom réel** avec le Chasseur et un Écho posés sur un escalier, un dallage
et près d'une porte ou d'une colonne. Écarts relevés le 3 novembre : carte 15 (escaliers et colonnes 3 à 4 fois trop
grands) et carte 4 (dalles environ 2 fois trop grandes). Réglé le 8 novembre sans repeindre : une carte trop grande
se réduit en jeu par son réglage `decor_scale` (ArenaData), qui réduit l'image, les collisions, la mini-carte et toutes
les positions de la carte (docs/maps/ECHELLE_CHAPITRES_4_5.md). À l'intégration d'une carte, mesurer et poser ce facteur.

## Objets posés sur les cartes — règle du propriétaire, 3 novembre 2026

Tout objet ajouté par le jeu sur une carte (portails, cristaux, autels, abris, mannequins, nids, bulbes, braseros…)
doit **se fondre dans la direction artistique de la carte où il apparaît** :

- **sprite peint**, de la même facture que le décor de la carte ; aucun dessin vectoriel en aplats ;
- **palette prélevée sur la carte**, pas de couleur saturée étrangère au décor ;
- même finesse de détail, **lumière en haut à gauche**, **ombre portée** au sol ;
- les repères utiles au jeu (couleur commune aux deux portails d'une paire, état prêt ou en recharge, sortie annoncée)
  restent **discrets** : lueur ou liseré dans les teintes de la carte, jamais un grand halo ou un anneau criard ;
- validation sur une **capture au zoom réel**, l'objet posé dans son décor.

Les rendus vectoriels provisoires (miroirs-portails, cristaux-miroirs, mannequin) sont atténués en attendant leurs
sprites peints ; les rochers-abris dessinés par le jeu ont été retirés : les abris se peignent dans le décor.

## Cartes : exigences du propriétaire

Pour les décors de niveaux, appliquer aussi [MAP_GUIDELINES.md](MAP_GUIDELINES.md). Les exigences de netteté à l’écran, d’échelle des décors, de routes dégagées et de grandes surfaces de manœuvre priment sur les anciennes recettes de maps.

## Illustrations de l’arbre du Chasseur — précision du 17 octobre 2026

Pour les illustrations d’interface, préserver les détails des originaux : sorties 512 × 512,
transparence conservée, réduction de qualité Lanczos, sans réduction de palette à 32 couleurs
ni contour ajouté. Affichage filtré et vue détaillée par voie avec nœuds de 80 px et aperçu de 144 px.
Les 64 × 64 et les palettes limitées restent les recettes des sprites de gameplay ; ne pas les appliquer
aux illustrations détaillées de cet écran. Conserver les originaux pour les prochains imports.

## Typographie des menus — 17 octobre 2026

- **Cinzel** (titres : noms de compétences, de cartes, de chapitres, en-têtes) et **Inter** (texte, boutons, chiffres à
  chasse fixe pour les compteurs). Polices libres SIL OFL 1.1 dans `assets/fonts/` (licences jointes, créditées).
- Accès en code : `UiKit.font(&"body" | &"strong" | &"numbers" | &"title")`, `UiKit.title()`, `UiKit.caption()`.
  Cinzel n'est jamais utilisé pour un paragraphe.
- Inter n'a pas certains symboles : utiliser « ✓ » (pas « ✔ »), « ★ / ☆ », « · », « — » ; pas d'emoji.
- Principes des menus (inspirés de Hades, Diablo IV, Path of Exile 2) : une décision par écran, l'essentiel visible
  sans défiler à 1280 × 720, détails en infobulle au survol, action conseillée mise en avant, chiffres clés en couleur.
