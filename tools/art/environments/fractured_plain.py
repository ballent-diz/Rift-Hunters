"""Plaine fracturée (niveau 1) : prairie, plaques de terre, rochers, souches, ruines moussues, cristaux de Faille,
bordée d'une forêt dense. Éléments extraits du pack Ninja Adventure (CC0, assets/third_party/ninja_adventure)."""
import os
from pixelforge import packs as P

HERE = os.path.dirname(os.path.abspath(__file__))
TILESETS = os.path.abspath(os.path.join(HERE, "..", "..", "..", "assets", "third_party", "ninja_adventure", "tilesets"))


def _src(name):
    return P.load(os.path.join(TILESETS, name + ".png"))


# Rectangles en tuiles (x, y, largeur, hauteur) dans les tilesets du pack.
DETAILS = [
    # (nom, tileset, rectangle, poids)
    ("tuft_a", "TilesetFloorDetail", (0, 2, 1, 1), 5), ("tuft_b", "TilesetFloorDetail", (1, 2, 1, 1), 4),
    ("tuft_c", "TilesetFloorDetail", (2, 2, 1, 1), 4), ("tuft_d", "TilesetFloorDetail", (3, 2, 1, 1), 4),
    ("tuft_e", "TilesetFloorDetail", (4, 2, 1, 1), 3), ("flowers_red", "TilesetFloorDetail", (5, 2, 1, 1), 1.2),
    ("sprout", "TilesetFloorDetail", (6, 2, 1, 1), 2), ("clover", "TilesetFloorDetail", (7, 2, 1, 1), 2),
    ("leaves", "TilesetFloorDetail", (0, 0, 1, 1), 1.5), ("leaf_bits", "TilesetFloorDetail", (1, 0, 1, 1), 1.5),
    ("twig_a", "TilesetFloorDetail", (5, 0, 1, 1), 1), ("twig_b", "TilesetFloorDetail", (6, 0, 1, 1), 1),
    ("branch", "TilesetFloorDetail", (7, 0, 1, 1), 0.8), ("skull", "TilesetFloorDetail", (13, 0, 1, 1), 0.3),
    ("bone", "TilesetFloorDetail", (14, 0, 1, 1), 0.5), ("pebbles", "TilesetFloorDetail", (0, 1, 1, 1), 1.2),
    ("grass_a", "TilesetNature", (4, 10, 1, 1), 2), ("grass_b", "TilesetNature", (5, 10, 1, 1), 2),
    ("grass_c", "TilesetNature", (7, 10, 1, 1), 2), ("grass_d", "TilesetNature", (9, 10, 1, 1), 2),
    ("fern_a", "TilesetNature", (4, 11, 1, 1), 1.5), ("fern_b", "TilesetNature", (5, 11, 1, 1), 1.5),
    ("daisy", "TilesetNature", (6, 11, 1, 1), 0.8), ("sunflower", "TilesetNature", (0, 11, 1, 1), 0.4),
    ("red_flower", "TilesetNature", (3, 11, 1, 1), 0.5), ("clover_b", "TilesetNature", (2, 11, 1, 1), 1),
    ("stone_a", "TilesetNature", (17, 17, 1, 1), 1.2), ("stone_b", "TilesetNature", (18, 17, 1, 1), 1.2),
    ("stone_c", "TilesetNature", (19, 17, 1, 1), 1.2), ("flat_stone_a", "TilesetVillageAbandoned", (6, 3, 1, 1), 0.8),
    ("flat_stone_b", "TilesetVillageAbandoned", (7, 3, 1, 1), 0.8), ("flat_stone_c", "TilesetVillageAbandoned", (8, 4, 1, 1), 0.8),
]

PROPS = [
    ("bush_a", "TilesetNature", (0, 10, 1, 1), 3), ("bush_b", "TilesetNature", (1, 10, 1, 1), 3),
    ("bush_c", "TilesetNature", (2, 10, 1, 1), 2), ("bush_d", "TilesetNature", (3, 10, 1, 1), 2),
    ("boulder_a", "TilesetNature", (15, 14, 2, 2), 2), ("boulder_b", "TilesetNature", (15, 16, 2, 2), 2),
    ("boulder_big", "TilesetNature", (17, 14, 4, 3), 0.8), ("boulder_tall", "TilesetNature", (21, 14, 2, 3), 0.8),
    ("rock_round", "TilesetNature", (16, 8, 2, 2), 1.5), ("rock_small", "TilesetNature", (18, 9, 1, 1), 2),
    ("stump", "TilesetNature", (0, 8, 2, 2), 1.5), ("stump_small", "TilesetNature", (4, 8, 1, 1), 1.5),
    ("log", "TilesetNature", (5, 8, 1, 1), 1), ("dead_bush", "TilesetNature", (4, 9, 1, 1), 1.5),
    ("dead_tree", "TilesetNature", (4, 0, 2, 2), 1.2), ("tree_round", "TilesetNature", (0, 0, 2, 2), 0.6),
    ("pine", "TilesetNature", (2, 0, 2, 2), 0.6), ("small_tree", "TilesetNature", (6, 8, 2, 2), 0.6),
    ("crystal_violet", "TilesetNature", (2, 14, 1, 1), 1.2), ("crystal_teal", "TilesetNature", (1, 14, 1, 1), 0.6),
    ("gem_boulder", "TilesetNature", (7, 14, 2, 2), 0.5), ("gem_boulder_dark", "TilesetNature", (7, 16, 2, 2), 0.5),
    ("mossy_rock", "TilesetVillageAbandoned", (7, 5, 2, 2), 1), ("pillar", "TilesetVillageAbandoned", (2, 3, 1, 3), 0.5),
    ("broken_pillar", "TilesetVillageAbandoned", (3, 3, 1, 3), 0.5),
    ("mossy_statue", "TilesetVillageAbandoned", (0, 3, 2, 3), 0.3),
    ("ruined_wall", "TilesetVillageAbandoned", (8, 0, 3, 3), 0.25), ("ruined_house", "TilesetVillageAbandoned", (0, 0, 4, 3), 0.15),
]

BORDER = [
    ("forest_pine", "TilesetNature", (0, 2, 4, 3), 3), ("forest_green", "TilesetNature", (4, 2, 4, 3), 3),
    ("forest_dead", "TilesetNature", (0, 5, 4, 3), 1.5), ("forest_lime", "TilesetNature", (16, 2, 4, 3), 1.5),
    ("forest_mossy_a", "TilesetVillageAbandoned", (0, 6, 4, 3), 2), ("forest_mossy_b", "TilesetVillageAbandoned", (0, 9, 4, 3), 2),
    ("rock_pile", "TilesetNature", (16, 5, 4, 3), 1), ("border_pine", "TilesetNature", (2, 0, 2, 2), 1.5),
    ("border_tree", "TilesetNature", (0, 0, 2, 2), 1.5), ("border_dead", "TilesetNature", (4, 0, 2, 2), 1),
]

# Zones de terre (9-slice du bloc herbe sombre / terre du sol) : tailles en tuiles.
DIRT_SIZES = [(3, 2), (3, 3), (4, 3), (5, 3), (4, 4), (6, 4), (5, 5), (7, 4), (8, 5)]


def build(rng):
    floor = _src("TilesetFloor")
    sheets = {name: _src(name) for name in ("TilesetNature", "TilesetFloorDetail", "TilesetVillageAbandoned")}
    ground = P.tile_fill(floor, 128, (11, 12), [(12, 12), (13, 12), (14, 12), (15, 12)], 0.06, rng)
    items = []
    for i, (w, h) in enumerate(DIRT_SIZES):
        img = P.nine_slice(floor, (11, 7), w, h, rng, center_variants=[(11, 11), (12, 11)], variant_chance=0.12)
        items.append((f"dirt_{i}", "patch", 3.0 if w * h <= 12 else 1.5, img))
    items.append(("dirt_spot", "patch", 1.5, P.tiles(floor, 14, 10)))
    for group, layer in ((DETAILS, "detail"), (PROPS, "prop"), (BORDER, "border")):
        for name, sheet, rect, weight in group:
            items.append((name, layer, weight, P.isolate(P.tiles(sheets[sheet], *rect))))
    return {"ground": ground, "items": items}


SPEC = {
    "id": "fractured_plain",
    "source": "assets/third_party/ninja_adventure (Pixel-boy et AAA, CC0)",
    "seed": 77,
    "scale": 1.0,
    "build": build,
    # Nombre d'éléments par carré de 1000 x 1000 unités du monde (multiplié par decor_density de l'arène).
    "density": {"patch": 7.0, "detail": 130.0, "prop": 22.0},
    # Forêt qui borde l'arène : largeur de la bande (unités du monde) et espacement des arbres.
    "border": {"width": 300.0, "spacing": 30.0},
    "clear_radius": 150.0,
    "outside_tint": "#06120c99",
    "ambient": {"color": "#f4f0b8", "amount": 26},
}
