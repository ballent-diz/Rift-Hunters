"""Plaine fracturée : terre sèche fendue sous un ciel de Faille, ruines, ossements, fissures violettes."""
from pixelforge import decor as D

GROUND = D.hexramp(["#0d0c14", "#15151f", "#1c1d2a", "#242635", "#2d2f3e", "#393a47", "#4a4a52"])
DUST = D.hexramp(["#110e12", "#1b1619", "#251f21", "#2f2827", "#3a322e", "#463d36", "#554a40"])
PEBBLE = D.hexramp(["#0f0e15", "#1a1a24", "#262733", "#323442", "#3f4150", "#4f5160", "#666672"])
STONE = D.hexramp(["#0f0e17", "#1b1b27", "#272836", "#343647", "#434658", "#56586a", "#717282"])
RUIN = D.hexramp(["#100f16", "#1d1b24", "#2a2731", "#37333e", "#46414b", "#58525b", "#6f6870"])
GRASS = D.hexramp(["#121210", "#1e1d17", "#2b291f", "#3a3727", "#4a4630", "#5c573a", "#716a47"])
BONE = D.hexramp(["#1a1716", "#2e2a27", "#48423b", "#655c51", "#827769", "#9d9282", "#b8ad9b"])
BARK = D.hexramp(["#110d0e", "#1c1517", "#2a1f20", "#382a29", "#473733", "#58463f", "#6b574c"])
WOOD = D.hexramp(["#2a1f1c", "#3d2e28", "#524036", "#665143", "#7a6250", "#8d735f", "#a08670"])
CORRUPT = D.hexramp(["#120b1a", "#1d1029", "#2a163b", "#3a1d4f", "#4b2563", "#5d2f77", "#70398b"])
RIFT = D.hexramp(["#1a0f2e", "#2d1857", "#45238a", "#6a3cc4", "#8f5ef0", "#b590ff", "#dcc8ff"])
CLIFF = D.hexramp(["#08070d", "#121119", "#1b1b26", "#262735", "#323445", "#424456", "#56586a"])
NEBULA = D.hexramp(["#05040a", "#090713", "#0e0a1e", "#150f2b"])
STARS = D.hexramp(["#2a2640", "#4c4669", "#9a93c2"])
VOID = (5, 4, 10)

D.register_ramp("bone_plain", BONE)
D.register_ramp("bark_plain", BARK)
D.register_ramp("wood_plain", WOOD)
D.register_ramp("void_dark", [(7, 6, 12)] * 7)


def decals(rng):
    """[(nom, couche, poids, image, halo ou None)]."""
    out = []

    def add(name, layer, weight, img, halo=None):
        out.append((name, layer, weight, img, halo))

    for i, (w, h) in enumerate(((180, 120), (230, 150), (150, 100))):
        add(f"dirt_{i}", "patch", 3, D.patch(rng, DUST, w, h, "dirt"))
    for i, (w, h) in enumerate(((210, 136), (160, 110), (250, 160))):
        add(f"grass_patch_{i}", "patch", 3, D.patch(rng, DUST, w, h, "grass", GRASS))
    for i, (w, h) in enumerate(((150, 110), (120, 90))):
        add(f"flagstones_{i}", "patch", 1.2, D.flagstones(rng, RUIN, DUST, w, h))
    for i, (w, h) in enumerate(((90, 84), (120, 100))):
        add(f"veins_{i}", "patch", 1, D.veins(rng, CORRUPT, w, h, 6 + i))
    for i, (w, h) in enumerate(((150, 48), (110, 40), (200, 60))):
        img, halo = D.fissure(rng, GROUND, RIFT, w, h)
        add(f"fissure_{i}", "rift", 1, img, halo)
    for i in range(6):
        size = [(20, 18), (26, 22), (16, 14), (22, 20), (30, 24), (18, 16)][i]
        add(f"grass_{i}", "detail", 4, D.grass_tuft(rng, GRASS, size[0], size[1], int(rng.integers(10, 18))))
    for i in range(5):
        size = [(14, 10), (18, 12), (10, 8), (22, 14), (12, 10)][i]
        add(f"pebbles_{i}", "detail", 3, D.pebbles(rng, PEBBLE, size[0], size[1], int(rng.integers(2, 6))))
    for i in range(4):
        size = [(44, 20), (32, 16), (56, 24), (28, 14)][i]
        add(f"crack_{i}", "detail", 2.5, D.small_crack(rng, GROUND, size[0], size[1]))
    add("bones_0", "detail", 0.6, D.bones(rng, "bone_plain", 18, 12, 2))
    add("bones_1", "detail", 0.6, D.bones(rng, "bone_plain", 20, 14, 3))
    add("skull_0", "detail", 0.4, D.skull(rng, "bone_plain"))
    add("roots_0", "detail", 0.8, D.roots(rng, "bark_plain"))
    add("roots_1", "detail", 0.8, D.roots(rng, "bark_plain", 28, 14))
    for i, (w, ht) in enumerate(((22, 6), (30, 8), (40, 11), (18, 5), (34, 9))):
        add(f"rock_{i}", "prop", 3, D.rock(rng, STONE, w, ht))
    add("column_0", "prop", 1, D.column_stump(rng, RUIN, 9, 18))
    add("column_1", "prop", 1, D.column_stump(rng, RUIN, 11, 11))
    add("fallen_column_0", "prop", 0.8, D.fallen_column(rng, RUIN, 58, 8))
    add("ribcage_0", "prop", 0.6, D.ribcage(rng, "bone_plain"))
    add("stump_0", "prop", 1, D.dead_stump(rng, "bark_plain", "wood_plain"))
    add("stump_1", "prop", 1, D.dead_stump(rng, "bark_plain", "wood_plain", 28, 28))
    for i in range(2):
        img, halo = D.crystal_shards(rng, RIFT, 18 + i * 4, 22 + i * 4, 2 + i)
        add(f"crystals_{i}", "prop", 0.7, img, halo)
    for i in range(4):
        add(f"rubble_{i}", "rubble", 1, D.pebbles(rng, PEBBLE, 8 + i * 2, 6 + i, int(rng.integers(1, 3))))
    return out


SPEC = {
    "id": "fractured_plain",
    "seed": 1201,
    "ground": lambda rng: D.cracked_ground(1024, rng, {"ground": GROUND, "dust": DUST, "pebble": PEBBLE}),
    "void": lambda rng: D.void_tile(rng, 512, NEBULA, STARS),
    "edges": {
        "south": lambda rng: (D.cliff_strip(rng, CLIFF, 512, glow_ramp=RIFT), 6),
        "north": lambda rng: (D.rim_strip(rng, CLIFF, 512, 0.9, VOID)[::-1], 8),
        "west": lambda rng: (D.rim_strip(rng, CLIFF, 512, 0.6, VOID)[::-1].transpose(1, 0, 2), 8),
        "east": lambda rng: (D.rim_strip(rng, CLIFF, 512, 0.2, VOID).transpose(1, 0, 2), 8),
    },
    "decals": decals,
    # Nombre d'éléments par carré de 1000 x 1000 unités du monde (multiplié par decor_density de l'arène).
    "density": {"patch": 12.0, "rift": 3.0, "detail": 220.0, "prop": 18.0},
    "scatter": 3,
    "clear_radius": 160.0,
    "ambient": {"color": "#8d84b0", "amount": 36},
    "wall_color": "#8a5cf0",
    "void_color": "#05040a",
}
