"""Cendrelame (Ashblade) — créature de référence du style (v2, 64×64).

Prédateur quadrupède d'obsidienne fissurée, avant-bras terminés par des lames d'acier noir,
réseau de veines de braise. Ancre aux pieds (32, 54), 1 pixel d'art = 0,5 unité du monde.
Évolutions : Lame-Éclipse (lames allongées, croissant dorsal, palette du vide),
Brasier-Croc (crinière de flammes, obsidienne carbonisée).
"""
import math
from pixelforge import Part, Pose, Creature, Anim, Ellipse, Circle, Capsule, Poly, Arc, EntitySpec
from pixelforge.rig import wave

CELL = (64, 64)
ANCHOR = (32, 54)
SCALE = 0.5
PLATES = ("plates", 7.0, 1.1)
FINE_PLATES = ("plates", 5.0, 0.9)


def build(variant="base"):
    blade = 1.22 if variant == "eclipse" else 1.0
    ember = dict(mode="emissive", level=4, glow=True, separate=False, rim=False, texture=0.6)

    def bx(x):  # allonge les lames (Lame-Éclipse) depuis le poignet
        return 14 + (x - 14) * blade

    p = [
        # --- Plan éloigné (ton plus sombre)
        Part("horn_far", Poly([(19, -36.5), (13, -40.5), (7, -42), (10.5, -39.5), (17, -35.5)]), "obsidian", z=0,
             parent="head", pivot=(18, -36), shade=-1),
        Part("thigh_far", Ellipse(-10, -17, 5.5, 6.5), "obsidian", z=0, parent="torso", pivot=(-10, -20), shade=-1),
        Part("shin_far", Capsule(-11, -12, -13, -3, 2.6, 2.0), "obsidian", z=0, parent="thigh_far", pivot=(-11, -12), shade=-1),
        Part("paw_far", Ellipse(-12.5, -1.8, 3.2, 1.8), "obsidian", z=0, parent="shin_far", pivot=(-13, -3), shade=-1),
        Part("upper_far", Capsule(7, -16, 10, -9, 2.8, 2.2), "obsidian", z=0, parent="torso", pivot=(7, -16), shade=-1),
        Part("fore_far", Capsule(10, -9, 12, -3, 2.2, 1.8), "obsidian", z=0, parent="upper_far", pivot=(10, -9), shade=-1),
        Part("blade_far", Poly([(11, -8), (bx(24), -3.5), (bx(26), -1.8), (12, -5)]), "silver", z=0, parent="fore_far",
             pivot=(12, -6), shade=-1),
        # --- Queue
        Part("tail1", Capsule(-15, -22, -23, -24, 4.4, 3.4), "obsidian", z=1, parent="torso", pivot=(-15, -22),
             pattern=FINE_PLATES),
        Part("tail2", Capsule(-23, -24, -28.5, -29, 3.4, 2.3), "obsidian", z=1, parent="tail1", pivot=(-23, -24)),
        Part("tail_tip", Poly([(-27, -30.5), (-31.5, -38), (-30.5, -28.5)]), "silver", z=1, parent="tail2",
             pivot=(-29, -29.5), shine=True),
        # --- Plaques dorsales
    ]
    for i, (x, height) in enumerate([(-14, 6), (-9, 8), (-4, 9.5), (1, 8.5), (6, 6.5)]):
        if variant == "pyre":
            p.append(Part(f"flame_{i}", Poly([(x - 3.2, -27), (x - 0.5, -27 - height * 1.6), (x + 1.5, -31),
                                              (x + 2.2, -27 - height * 1.1), (x + 3.2, -27.5)]),
                          "ember", z=2, parent="torso", pivot=(x, -27), mode="emissive", level=4 + i % 2, glow=True,
                          separate=False, rim=False))
        else:
            p.append(Part(f"plate_{i}", Poly([(x - 3.2, -26.5), (x - 1.2, -27 - height), (x + 3.2, -27.5)]), "obsidian", z=2,
                          parent="torso", pivot=(x, -27), shade=1))
    if variant == "eclipse":
        p.append(Part("crescent", Poly([(-17, -28), (-10, -42), (2, -44), (-4, -39.5), (-10, -36), (-12, -29)]), "obsidian",
                      z=1, parent="torso", pivot=(-6, -34), shade=1, pattern=FINE_PLATES))
    p += [
        # --- Corps
        Part("torso", Ellipse(-3, -21, 15, 8.6, -0.05), "obsidian", z=3, pivot=(0, -20), pattern=PLATES, texture=0.3),
        Part("seam_a", Capsule(-13, -22, -4, -19.5, 0.8), "ember", z=4, parent="torso", **ember),
        Part("seam_b", Capsule(-4, -19.5, 4, -23, 0.8), "ember", z=4, parent="torso", **ember),
        Part("seam_c", Capsule(-4, -19.5, -6, -14.5, 0.6), "ember", z=4, parent="torso", **ember),
        Part("chest", Ellipse(9, -22, 9, 9.5), "obsidian", z=4, parent="torso", pivot=(9, -22), pattern=PLATES, texture=0.3),
        Part("seam_d", Capsule(4, -23, 10.5, -18, 0.7), "ember", z=5, parent="chest", **ember),
        Part("seam_e", Capsule(8, -27, 11, -22, 0.6), "ember", z=5, parent="chest", **ember),
        # --- Patte arrière proche
        Part("thigh_near", Ellipse(-8, -16.5, 6.5, 7.5), "obsidian", z=5, parent="torso", pivot=(-8, -20), pattern=PLATES),
        Part("seam_f", Capsule(-10, -19, -6, -13.5, 0.6), "ember", z=6, parent="thigh_near", **ember),
        Part("shin_near", Capsule(-8, -11, -9, -3, 3.0, 2.2), "obsidian", z=5, parent="thigh_near", pivot=(-8, -11)),
        Part("paw_near", Ellipse(-8.5, -1.8, 3.6, 2.0), "obsidian", z=6, parent="shin_near", pivot=(-9, -3)),
        Part("claw_a", Poly([(-6, -2.6), (-3.5, -0.6), (-6, -0.8)]), "bone", z=7, parent="paw_near", pivot=(-6, -2),
             separate=False),
        Part("claw_b", Poly([(-7.8, -2.2), (-5.6, 0.2), (-8, -0.2)]), "bone", z=7, parent="paw_near", pivot=(-8, -2),
             separate=False),
        # --- Tête
        Part("neck", Capsule(12, -26, 18, -31, 5.5, 4.2), "obsidian", z=5, parent="torso", pivot=(12, -26), pattern=FINE_PLATES),
        Part("head", Ellipse(22, -31, 7.5, 5.8, 0.18), "obsidian", z=6, parent="neck", pivot=(17, -30), pattern=FINE_PLATES),
        Part("jaw", Poly([(20.5, -28), (30, -27.5), (28.5, -24.6), (21, -25.6)]), "obsidian", z=6, parent="head",
             pivot=(21, -27), shade=-1),
        Part("tooth_a", Poly([(24.5, -28.4), (25.6, -26.4), (26.6, -28.3)]), "bone", z=7, parent="head", pivot=(25, -28),
             separate=False, rim=False),
        Part("tooth_b", Poly([(27.6, -28.2), (28.6, -26.6), (29.6, -28.1)]), "bone", z=7, parent="head", pivot=(28, -28),
             separate=False, rim=False),
        Part("snout", Poly([(22.5, -35), (32, -31.5), (31, -28.3), (22.5, -27.4)]), "obsidian", z=7, parent="head",
             pivot=(23, -31), separate=False),
        Part("brow", Poly([(18, -36.5), (26, -35.2), (24, -33.4), (18.5, -33.6)]), "obsidian", z=8, parent="head",
             pivot=(20, -35), shade=-1, separate=False),
        Part("eye", Circle(24.6, -32.7, 1.5), "ember", z=9, parent="head", mode="emissive", level=6, glow=True,
             separate=False, rim=False),
        Part("horn_near", Poly([(18.5, -35.5), (11.5, -38.5), (4, -38.5), (8, -36.6), (12, -35), (17.5, -33.5)]), "obsidian",
             z=7, parent="head", pivot=(17, -35), shade=1),
        # --- Membre-lame proche
        Part("upper_near", Capsule(10, -16, 14, -9, 3.2, 2.5), "obsidian", z=8, parent="torso", pivot=(10, -16)),
        Part("fore_near", Capsule(14, -9, 16, -3, 2.5, 2.0), "obsidian", z=8, parent="upper_near", pivot=(14, -9)),
        Part("paw_front", Ellipse(16.5, -1.8, 3.0, 1.7), "obsidian", z=8, parent="fore_near", pivot=(16, -3)),
        Part("blade_near", Poly([(13, -10), (17, -11.5), (bx(28), -6.5), (bx(31.5), -2.6), (bx(29), -1.6), (17, -6)]),
             "silver", z=9, parent="fore_near", pivot=(14, -7), shine=True),
        Part("serration", Poly([(18, -11.2), (19.5, -13.4), (21, -10.4), (22.5, -12.4), (24, -9.4), (21, -9.6)]), "silver",
             z=9, parent="blade_near", pivot=(20, -11), shade=-1),
        Part("blade_edge", Capsule(17, -6.3, bx(30.5), -2.4, 0.7), "ember", z=10, parent="blade_near", **ember),
        # --- Effets de la Danse des cendres
        Part("slash_a", Arc(12, -18, 19, 3.2, -1.25, 0.55), "ember", z=11, mode="emissive", level=5, glow=True,
             separate=False, rim=False, visible=False),
        Part("slash_b", Arc(6, -16, 23, 2.6, -2.4, -0.9), "ember", z=11, mode="emissive", level=4, glow=True,
             separate=False, rim=False, visible=False),
    ]

    seams = ["seam_a", "seam_b", "seam_c", "seam_d", "seam_e", "seam_f", "blade_edge"]

    def flicker(poses, i, bright=False):
        for k, name in enumerate(seams):
            poses[name] = Pose(level=5 if bright else (4 if (i + k) % 3 else 5))
        if variant == "pyre":
            for k in range(5):
                poses[f"flame_{k}"] = Pose(sy=1.0 + 0.22 * math.sin(i * 1.9 + k * 2.3), level=4 + (i + k) % 3)
        return poses

    def legs(s, amp=0.55):
        return {
            "thigh_near": Pose(rot=amp * s), "shin_near": Pose(rot=-0.6 * amp * max(s, 0.0)),
            "thigh_far": Pose(rot=-amp * s), "shin_far": Pose(rot=-0.6 * amp * max(-s, 0.0)),
            "upper_near": Pose(rot=-0.9 * amp * s), "fore_near": Pose(rot=0.5 * amp * max(-s, 0.0)),
            "upper_far": Pose(rot=0.9 * amp * s), "fore_far": Pose(rot=0.5 * amp * max(s, 0.0)),
        }

    def idle(i, t):
        breath = wave(t)
        poses = {
            "torso": Pose(dy=-1 if breath > 0.3 else 0),
            "chest": Pose(sy=1.0 + 0.03 * breath),
            "neck": Pose(rot=0.04 * wave(t, 0.2)),
            "head": Pose(rot=0.05 * wave(t, 0.35)),
            "tail1": Pose(rot=0.10 * wave(t, 0.1)),
            "tail2": Pose(rot=0.16 * wave(t, 0.3)),
            "tail_tip": Pose(rot=0.2 * wave(t, 0.45)),
        }
        for leg in ("thigh_near", "thigh_far", "upper_near", "upper_far"):
            poses[leg] = Pose(dy=1 if breath > 0.3 else 0)
        return flicker(poses, i)

    def move(i, t):
        s = wave(t)
        poses = legs(s)
        poses.update({
            "torso": Pose(dy=-round(abs(s) * 2.0), rot=-0.05 * s),
            "neck": Pose(rot=0.06 * wave(t, 0.25)),
            "head": Pose(rot=-0.05 * s),
            "tail1": Pose(rot=0.18 * wave(t, 0.35)),
            "tail2": Pose(rot=0.25 * wave(t, 0.5)),
            "tail_tip": Pose(rot=0.3 * wave(t, 0.65)),
        })
        return flicker(poses, i)

    def attack(i, t):
        # (dx du corps, épaule, avant-bras, mâchoire, tête)
        keys = [(0, 0.0, 0.0, 0.0, 0.0), (-2, -0.9, -0.3, 0.15, -0.1), (-3, -1.35, -0.5, 0.3, -0.18),
                (5, 0.65, 0.35, 0.5, 0.15), (6, 0.9, 0.45, 0.4, 0.12), (3, 0.45, 0.2, 0.15, 0.05), (1, 0.1, 0.0, 0.0, 0.0)]
        dx, shoulder, fore, jaw, head = keys[i]
        poses = {
            "torso": Pose(dx=dx, dy=1 if i in (1, 2) else 0, rot=0.06 if i in (1, 2) else -0.04 if i in (3, 4) else 0.0),
            "upper_near": Pose(rot=shoulder), "fore_near": Pose(rot=fore),
            "upper_far": Pose(rot=shoulder * 0.6), "fore_far": Pose(rot=fore * 0.6),
            "jaw": Pose(rot=jaw), "head": Pose(rot=head),
            "thigh_near": Pose(rot=-0.4 if i in (3, 4) else 0.1), "thigh_far": Pose(rot=0.4 if i in (3, 4) else -0.1),
            "tail1": Pose(rot=-0.2 if i in (3, 4) else 0.15), "tail2": Pose(rot=-0.25 if i in (3, 4) else 0.2),
        }
        return flicker(poses, i, bright=i in (3, 4))

    def technique(i, t):
        angle = [0.0, -0.8, -1.4, 0.9, -1.5, 1.0, -0.6, 0.0][i]
        hop = [0, -3, -6, -6, -6, -4, -2, 0][i]
        poses = legs(0.8 if hop < -2 else 0.0, 0.5)
        poses.update({
            "torso": Pose(dy=hop, rot=-0.15 * math.sin(i * 1.1)),
            "upper_near": Pose(rot=angle), "fore_near": Pose(rot=angle * 0.4),
            "upper_far": Pose(rot=-angle * 0.7), "jaw": Pose(rot=0.45 if 2 <= i <= 5 else 0.1),
            "tail1": Pose(rot=0.35 * math.sin(i * 1.3)), "tail2": Pose(rot=0.4 * math.sin(i * 1.3 + 0.6)),
            "slash_a": Pose(visible=i in (3, 4)), "slash_b": Pose(visible=i in (4, 5)),
        })
        return flicker(poses, i, bright=True)

    anims = [
        Anim("idle", 8, 8, True, idle),
        Anim("move", 8, 12, True, move),
        Anim("attack", 7, 16, False, attack),
        Anim("technique", 8, 16, False, technique),
    ]
    return Creature(p, anims)


SPECS = [
    EntitySpec("monster.ashblade", lambda: build("base"), CELL, ANCHOR, scale=SCALE),
    EntitySpec("monster.ashblade.eclipse_blade", lambda: build("eclipse"), CELL, ANCHOR, scale=SCALE,
               remap={"obsidian": "shade", "ember": "void", "silver": "glass"}),
    EntitySpec("monster.ashblade.pyrefang", lambda: build("pyre"), CELL, ANCHOR, scale=SCALE, remap={"obsidian": "char"}),
]
