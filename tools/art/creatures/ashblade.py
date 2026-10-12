"""Cendrelame (Ashblade) — créature de référence du style.

Quadrupède d'obsidienne aux avant-bras-lames, veines de braise. Cellule 32×32, ancre aux pieds (16, 28).
Évolutions : Lame-Éclipse (lames allongées, palette du vide), Brasier-Croc (crinière de flammes).
"""
import math
from pixelforge import Part, Pose, Creature, Anim, Ellipse, Circle, Capsule, Poly, EntitySpec
from pixelforge.rig import wave

CELL = (32, 32)
ANCHOR = (16, 28)


def build(variant="base"):
    blade_len = 1.25 if variant == "eclipse" else 1.0
    p = [
        # Plan éloigné (ton plus sombre)
        Part("leg_far", Capsule(-5, -8, -6.5, -1, 1.9, 1.3), "obsidian", z=0, parent="body", pivot=(-5, -8), shade=-1),
        Part("arm_far", Capsule(4, -8, 6, -3, 1.7, 1.2), "obsidian", z=0, parent="body", pivot=(4, -8), shade=-1),
        Part("blade_far", Poly([(5, -4), (5 + 7 * blade_len, -1.5), (6 + 7 * blade_len, -0.5), (6, -2)]), "silver", z=0,
             parent="arm_far", pivot=(5, -3), shade=-1),
        Part("tail", Capsule(-6, -11, -12.5, -14.5, 2.1, 0.9), "obsidian", z=1, parent="body", pivot=(-6, -11)),
        Part("tail_tip", Poly([(-11.5, -15.5), (-16, -19), (-12.5, -13)]), "obsidian", z=1, parent="tail", pivot=(-12, -14),
             shade=1),
        # Corps
        Part("body", Ellipse(-1, -10, 7.5, 4.2, -0.06), "obsidian", z=2, pivot=(0, -10), texture=0.6),
        Part("plate_a", Poly([(-6.5, -12.5), (-4.5, -16.5), (-2.5, -13.2)]), "obsidian", z=2, parent="body", pivot=(-4, -13),
             shade=1),
        Part("plate_b", Poly([(-2.5, -13.5), (0, -17.5), (2, -13.5)]), "obsidian", z=2, parent="body", pivot=(0, -14), shade=1),
        Part("chest", Ellipse(4, -10.5, 4.3, 4.4), "obsidian", z=3, parent="body", pivot=(4, -10), texture=0.5),
        Part("seam", Capsule(-6, -10.5, 3, -11.5, 0.55), "ember", z=3, parent="body", mode="emissive", level=3, glow=True,
             separate=False),
        Part("seam_chest", Capsule(4.5, -12.5, 6, -9, 0.5), "ember", z=4, parent="chest", mode="emissive", level=3,
             separate=False),
        # Tête
        Part("horn", Poly([(7, -15.5), (2.5, -20.5), (5, -15.5), (8.5, -14.5)]), "obsidian", z=3, parent="head", pivot=(7, -15),
             shade=1),
        Part("head", Ellipse(9, -13.8, 4.0, 3.2, 0.15), "obsidian", z=5, parent="body", pivot=(6, -12)),
        Part("snout", Poly([(10, -15.5), (15.2, -13.6), (14.6, -12), (10, -11.4)]), "obsidian", z=5, parent="head",
             pivot=(10, -13), separate=False),
        Part("eye", Circle(11.2, -14.6, 0.85), "ember", z=6, parent="head", mode="emissive", level=4, glow=True,
             separate=False),
        # Plan rapproché
        Part("leg_near", Capsule(-3, -8, -3.5, -1, 2.2, 1.5), "obsidian", z=6, parent="body", pivot=(-3, -8)),
        Part("arm_near", Capsule(5, -8, 8, -3.5, 2.0, 1.5), "obsidian", z=7, parent="body", pivot=(5, -8)),
        Part("blade_near", Poly([(7, -4.6), (9, -5.2), (8.5 + 8 * blade_len, -1.3), (8 + 8 * blade_len, 0.2), (8, -2)]),
             "silver", z=7, parent="arm_near", pivot=(8, -3.5)),
        Part("blade_edge", Capsule(9, -4.8, 8.2 + 8 * blade_len, -1.0, 0.45), "ember", z=8, parent="blade_near",
             mode="emissive", level=3, glow=True, separate=False),
        # Effets de Technique (visibles seulement pendant la Danse des cendres)
        Part("slash", Poly([(10, -18), (19, -11), (20, -6), (16, -12), (9, -16)]), "ember", z=9, mode="emissive", level=3,
             glow=True, separate=False, visible=False),
    ]
    if variant == "pyre":
        for i, (x, top) in enumerate([(-5, -19), (-1.5, -20.5), (2, -19.5), (5.5, -18)]):
            p.append(Part(f"flame_{i}", Poly([(x - 1.8, -13), (x, top), (x + 1.8, -13.5)]), "ember", z=4, parent="body",
                          pivot=(x, -13), mode="emissive", level=2 + i % 2, glow=True, separate=False))
    if variant == "eclipse":
        p.append(Part("crescent", Poly([(-8, -14), (-3, -21), (3, -20.5), (-1, -18.5), (-5, -15)]), "obsidian", z=1,
                      parent="body", pivot=(-3, -16), shade=1))

    def idle(i, t):
        bob = -1 if i in (2, 3) else 0
        poses = {
            "body": Pose(dy=bob),
            "head": Pose(rot=0.06 * wave(t)),
            "tail": Pose(rot=0.18 * wave(t, 0.2)),
            "leg_near": Pose(dy=-bob), "leg_far": Pose(dy=-bob),
            "arm_near": Pose(dy=-bob), "arm_far": Pose(dy=-bob),
        }
        _flames(poses, i)
        return poses

    def move(i, t):
        s = wave(t)
        bob = -round(abs(s) * 1.2)
        poses = {
            "body": Pose(dy=bob, rot=-0.04 * s),
            "leg_near": Pose(rot=0.65 * s, dy=-bob), "leg_far": Pose(rot=-0.65 * s, dy=-bob),
            "arm_near": Pose(rot=-0.55 * s, dy=-bob), "arm_far": Pose(rot=0.55 * s, dy=-bob),
            "head": Pose(rot=0.05 * wave(t, 0.25)),
            "tail": Pose(rot=0.3 * wave(t, 0.4)),
        }
        _flames(poses, i)
        return poses

    def attack(i, t):
        keys = [  # (dx du corps, rotation du bras, rotation de la tête)
            (0, 0.0, 0.0), (-1, -1.0, -0.1), (-1, -1.45, -0.15), (3, 0.75, 0.12), (3, 0.95, 0.1), (1, 0.25, 0.0)]
        dx, arm, head = keys[i]
        poses = {
            "body": Pose(dx=dx, dy=1 if i in (1, 2) else 0),
            "arm_near": Pose(rot=arm), "arm_far": Pose(rot=arm * 0.6),
            "head": Pose(rot=head),
            "leg_near": Pose(rot=-0.35 if i in (3, 4) else 0.0), "leg_far": Pose(rot=0.35 if i in (3, 4) else 0.0),
            "tail": Pose(rot=-0.25 if i in (3, 4) else 0.1),
        }
        _flames(poses, i)
        return poses

    def technique(i, t):
        angle = [0.0, -0.5, -1.2, 0.9, -1.4, 0.8, -0.6, 0.0][i]
        hop = [0, -2, -3, -3, -3, -2, -1, 0][i]
        poses = {
            "body": Pose(dy=hop, rot=-0.12 * math.sin(i)),
            "arm_near": Pose(rot=angle), "arm_far": Pose(rot=-angle * 0.7),
            "leg_near": Pose(rot=0.5 if hop < -1 else 0.0), "leg_far": Pose(rot=-0.5 if hop < -1 else 0.0),
            "tail": Pose(rot=0.4 * math.sin(i * 1.3)),
            "seam": Pose(level=4), "seam_chest": Pose(level=4),
            "slash": Pose(visible=i in (3, 4, 5), rot=(i - 4) * 0.35, dx=(i - 4) * 1.5),
        }
        _flames(poses, i)
        return poses

    def _flames(poses, i):
        if variant == "pyre":
            for k in range(4):
                poses[f"flame_{k}"] = Pose(sy=1.0 + 0.25 * math.sin(i * 1.7 + k * 2.1), level=2 + (i + k) % 3)

    anims = [
        Anim("idle", 6, 8, True, idle),
        Anim("move", 8, 12, True, move),
        Anim("attack", 6, 16, False, attack),
        Anim("technique", 8, 16, False, technique),
    ]
    return Creature(p, anims)


SPECS = [
    EntitySpec("monster.ashblade", lambda: build("base"), CELL, ANCHOR),
    EntitySpec("monster.ashblade.eclipse_blade", lambda: build("eclipse"), CELL, ANCHOR,
               remap={"obsidian": "shade", "ember": "void", "silver": "glass"}),
    EntitySpec("monster.ashblade.pyrefang", lambda: build("pyre"), CELL, ANCHOR, remap={"obsidian": "char"}),
]
