class_name DraftPixelPalette
extends Resource
## Palette d'un chapitre pour le rendu pixel 3D (docs/art/RENDU_PIXEL_3D.md), éditable dans l'inspecteur.
## Le décor est ramené aux couleurs de `colors` après l'ombrage en paliers et les contours ; sprites, effets et
## interface gardent leurs propres couleurs. Fichiers : `draft3d/render/palettes/chapter_<n>.tres`.
## Première version tirée d'une capture de la carte : `python3 tools/art/build_pixel_palette.py`.

## Couleurs permises pour le décor (64 au plus). Vide : aucune quantification.
@export var colors := PackedColorArray()
## Contour sélectif (docs/ART_BIBLE.md § 3) : sombre côté ombre, mêlé au liseré violet de la Faille sur les bords
## bas-droite ; côté lumière, la couleur du matériau assombrie de `lit_outline`.
@export var outline := Color("0e0a17")
@export var rim := Color("b56cf0")
@export_range(0.0, 1.0) var rim_strength: float = 0.4
@export_range(0.0, 1.0) var lit_outline: float = 0.55
## Faces à l'ombre (glissement vers le violet-bleu) et faces éclairées (vers l'ambre), comme les rampes des sprites.
@export var shadow_tint := Color(0.42, 0.38, 0.62)
@export var light_tint := Color(1.0, 0.97, 0.9)
## Exposition du décor avant palette (le rendu pixel passe le tonemap en linéaire ; 1,34 rend la luminosité du
## filmic d'origine).
@export_range(0.5, 2.0) var exposure: float = 1.34
## Paliers de lumière (3 ou 4).
@export_range(2, 6) var bands: int = 4
## Tramage aux transitions de paliers (0 : coupure nette).
@export_range(0.0, 1.0) var band_dither: float = 0.0
## Tramage léger avant quantification (0 : aucun).
@export_range(0.0, 1.0) var palette_dither: float = 0.0
## Relief (m de courbure de profondeur) en dessous duquel une arête n'est pas marquée : les dalles inégales et les
## joints fins restent lisses.
@export_range(0.005, 0.3) var crease_depth: float = 0.05
## Assombrissement des creux et éclaircissement des arêtes saillantes.
@export_range(0.0, 1.0) var crease_dark: float = 0.45
@export_range(0.0, 1.0) var edge_light: float = 0.18
## Textures pixel art des modules pour ce chapitre (lot suivant, docs/art/RENDU_PIXEL_3D.md) : chemin de la
## texture d'origine du pack → texture repeinte (même disposition UV). Vide : textures d'origine.
@export var textures: Dictionary = {}
