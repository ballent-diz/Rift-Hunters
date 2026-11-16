# Eau du Marais des Marées — carte 8

Lot d’images peintes, sans modification du code, des collisions, du plan des terres ou des autres cartes.
Références : `docs/ART_BIBLE.md` § 3, `docs/art/RENDU_PIXEL_3D.md`, section « Carte 8 » de
`docs/maps/CARTES_3D.md` et `draft3d/level_marsh.gd`.
Le raccordement aux matériaux, au shader des rives et aux pas des monstres reste au lot d’intégration.
Le masque technique `rives.png` existant ne fait pas partie de ces 22 images peintes.

| Images | Format | Usage | Aperçu conseillé |
|---|---|---|---|
| `eau_surface.png` | 256 × 256, RGB | Eau trouble vert-de-gris, répétition X/Y | Statique |
| `eau_rides_1.png` à `_8.png` | 256 × 256, RGBA | Rides à superposer à la surface | 100 ms/image, boucle de 800 ms |
| `ecume_1.png` à `_6.png` | 512 × 32, RGBA | Écume de berge, terre en haut, eau en bas ; répétition X | 120 ms/image, boucle de 720 ms |
| `vase_mouillee.png` | 256 × 256, RGB | Terre détrempée, sombre, petits reflets ; répétition X/Y | Statique |
| `eclaboussure_1.png` à `_6.png` | 64 × 64, RGBA | Contact du pas → couronne → retombée → rides résiduelles | 80 ms/image, effet de 480 ms |

Les cadences sont celles des GIF de contrôle, indépendantes du cycle de marée :
basse 50 s, montée 8 s, haute 16 s, descente 6 s. Le code existant reste responsable de la hauteur d’eau.
À 0,024 m/texel, une tuile de 256 px couvre 6,144 m ; une bande d’écume 12,288 × 0,768 m ;
une cellule d’éclaboussure 1,536 × 1,536 m. L’impact du pas est vers (32, 46), dans une cellule fixe.

## Traitement graphique

Pixels francs, export PNG sans perte, palette commune de 28 couleurs au maximum ;
alpha 0/255 sur les animations, sans fond peint, halo flou ni anticrénelage.
Éclairage peint en haut à gauche ; creux et dessous violet-bleu, lumières vers la sauge chaude et l’ambre.
Contours sélectifs sombres, accent bas-droite `#5e407d` : mélange à 40 % du violet `#b56cf0`
avec l’ombre `#242330`, pour conserver un liseré discret sur l’eau et les gouttes.

Rampes principales (7 tons, du sombre au clair) :

- Eau : `#242330`, `#293e4c`, `#2a4e55`, `#2e5c61`, `#49746d`, `#718b80`, `#9aa68a`.
- Vase : `#211c2d`, `#2d2b35`, `#343633`, `#3c4036`, `#4a4b3e`, `#66674d`, `#878866`.
- Écume : `#242330`, `#29484b`, `#467373`, `#718b80`, `#9aa68a`, `#b4b79d`, `#d0ceb0`.

Les effets gardent leur cellule et leur placement durant la séquence. Leurs silhouettes et crêtes restent
volontairement peu contrastées pour préserver la lecture des monstres et des télégraphes.

## Contrôle visuel

[Planche des 22 PNG à ×2](controle/planche_x2.png) — chaque image est agrandie au plus proche voisin,
sans réduction dans le fichier ; le damier appartient uniquement à la planche.
La largeur de la planche est limitée à 1600 px.

- [Boucle des rides](controle/eau_rides.gif) : les huit images, composées sur l’eau.
- [Boucle d’écume](controle/ecume.gif) : les six images, terre en haut.
- [Éclaboussure d’un pas](controle/eclaboussure.gif) : les six images, répétées pour inspection.

Le dossier `controle/` est exclu de l’import Godot par `.gdignore`.
Les PNG d’animation livrés à sa racine conservent leur transparence.

Contrôles de format : 22 PNG lisibles aux dimensions attendues, palette ≤ 32 couleurs visibles par image,
alpha franc et marges verticales transparentes ; bords opposés identiques pour les deux matières et pour
la répétition horizontale de l’écume ; huit/six/six images distinctes, GIF en boucle aux cadences ci-dessus.
Les raccords des deux matières ont aussi été inspectés en mosaïque 2 × 2.
La transition dernière → première des rides et de l’écume reste dans l’amplitude des autres transitions.
Chargement ciblé des 22 fichiers PNG et de leurs `Texture2D` importées : conforme sous Godot 4.6.3.
Les métadonnées d’import des nouvelles images utilisent la compression sans perte (`compress/mode=0`).

Validation en situation à faire après raccordement à la carte 8 : marée basse et haute, retrait de l’eau,
écume sur les levées de 4 à 5 m et éclaboussures sous les monstres au zoom réel.
