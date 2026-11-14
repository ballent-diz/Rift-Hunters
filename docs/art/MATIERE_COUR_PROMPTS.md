# Matière de la Cour — consignes de génération

Images produites avec **l'outil imagegen intégré**, puis conditionnées par `build_cour_matter.py`.
Les briefs ci-dessous conservent les contraintes artistiques des générations retenues ; le dernier prompt de
retouche est reproduit en entier. Les essais écartés restent hors dépôt.

## Atlas de matières

Production d'un atlas carré de 4 × 4 cellules égales jointives, sans marge, titre ni séparateur.
Pixel art peint net, détail natif proche de 128 px par cellule, albedo neutre sans éclairage directionnel,
ombres, perspective ni objets. Palette limitée, ardoise, olive, chêne usé, or terni, bordeaux et indigo délavés,
rares accents violets. Référence de finesse et de couleurs : feuille du Chasseur.
Matières dans l'ordre : dallage, pierre grise, mousse, maçonnerie ; chêne, bois fendu, fer, bronze ;
bordeaux, indigo, gravats, terre ; pierre corrompue, fissures, calcaire, algues.
Raccords périodiques, usure en amas de pixels lisibles, pas de dégradé photographique ni de lumière cuite.
Les matières minérales finales viennent de la seconde source ci-dessous pour éviter un double dessin des pavés.

## Détails transparents

Planche exacte de 4 colonnes × 6 rangées, cellules égales sur fond réellement transparent.
Pixel art peint de finesse native 64 × 64 par objet, même direction de lumière et palette que le Chasseur,
ni halo, cercle d'alerte, ombre circulaire ni grande lumière. Objets isolés, marge transparente, pied centré.
Herbes et fougère debout ; traces et débris vus pour le sol.
Ordre : herbe olive, herbe large, herbe sèche, fougère ; gravats, ardoise, brique, graviers ; flaque, humidité,
feuilles sèches, feuilles vertes ; racine moussue, liane murale, lierre, racine sèche ; toile ronde,
toile d'angle, crâne, ossements ; fissure fine, fissure ramifiée, corruption, veines violettes.
Références : atlas de matières et feuille du Chasseur. La liane murale incluait un bout de mur et a été refusée.

## Pierre calme : retouche retenue

Source initiale : atlas de 2 × 2 pierres plates homogènes, grain fin, calcaire gris, calcaire pâle,
ardoise sombre et lichen olive ; aucun pavé ni maçonnerie, lumière neutre et raccords périodiques.
Le premier résultat étant trop ponctué, ce prompt de retouche a produit la source `pierres_neutres.png` retenue :

> Edit this texture atlas to remove ALL fine grain, noise, stippling, speckles, dithering, checkerboard pixels
> and white flecks. Preserve the exact 2x2 layout of four square seamless stone albedo textures. Replace the
> noisy finish with deliberate HAND-PLACED pixel clusters, like high quality painted 16-bit game environmental
> textures: broad calm stone color fields, a few sparse angular hairline fissures, larger low-contrast chipped
> patches, barely visible worn streaks and subtle mottled staining. Restrained three or four tone grey per tile,
> only 10 percent value variation, NO tiny isolated bright pixels. Upper-left neutral grey stone; upper-right
> lighter limestone; lower-left dark slate; lower-right grey stone with sparse desaturated olive lichen patches.
> Existing game geometry already creates the blocks, so NO stones, NO bricks, NO pavement outlines. Flat material
> only, no directional light or shadows. Native texture detail should look like 160x160 pixels per tile enlarged
> nearest, crisp square clusters, never photographic or blurry. No text, no grid lines, no objects.

## Remplacement du sol : terre, pierre et verdure

Prompt intégral de la texture retenue (`source/terrain.png`), génération neuve avec imagegen intégré :

Production game asset: ONE perfectly seamless repeating terrain ALBEDO texture, square, strictly orthographic
top-down, edge-to-edge surface, no margins, no grid. Dark fantasy ruined courtyard ground: about 65 percent
compacted warm grey-brown earth and weathered dusty mineral soil, 20 percent muted olive moss and sparse short
grass hugging irregular patches, 15 percent scattered FLAT worn grey limestone fragments and pebbles partially
embedded in the earth. Natural uneven DISTRIBUTION and organic transitions with broad quiet open soil patches
for character readability. No pavement pattern, no hexagons, no regular tile grid, no evenly spaced rocks, no
black crack lines or drawn scratches. The texture represents a 16 meter by 16 meter area; the largest flat stone
is 40-60 centimeters and most pebbles are 5-15 centimeters. Texture detail intended for a final 640x640 texel
asset, sharp deliberate pixel-art clusters, 16-bit painted game environment style, color restricted to subdued
earth brown, cool desaturated grey slate and olive green, approx 24-32 colors. Rich intentional shapes rather
than random grain, NO white speckle noise, NO dithering, NO blur, NO photographic fine grain. Neutral diffuse
color only, NO directional light, NO baked highlights, NO cast shadows, NO perspective depth, NO 3D rocks, NO
tufts projecting above ground, NO objects, NO grass field, NO water, NO symbols, NO characters. The soil and
moss must remain low to medium contrast so colorful pixel-art characters can stand out. All four boundaries tile
seamlessly. Do not paint an illustrative scene: produce a usable horizontal terrain texture.

Le conditionnement est assuré par `build_cour_ground.py` : 640 × 640, 16 m par répétition, palette commune,
marges périodiques et nearest. Le maillage continu est créé dans le jeu, sans collision supplémentaire.

## Conditionnement technique des atlas et des détails

Les images générées ne sont pas importées directement comme feuilles finales : découpage des cellules,
réduction nearest, palette commune prélevée sur les sprites, marges périodiques des textures, alpha binaire
et pied fixe des petits objets. Ces opérations sont reproductibles et ne redessinent aucun décor du jeu.
