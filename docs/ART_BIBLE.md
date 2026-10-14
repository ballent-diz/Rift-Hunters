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
| Dévoreurs | 320×320 | centre de masse : Nébulorax (160, 160), Vorgranite (160, 188) | 220–280 |
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

## Cartes : exigences du propriétaire

Pour les décors de niveaux, appliquer aussi [MAP_GUIDELINES.md](MAP_GUIDELINES.md). Les exigences de netteté à l’écran, d’échelle des décors, de routes dégagées et de grandes surfaces de manœuvre priment sur les anciennes recettes de maps.
