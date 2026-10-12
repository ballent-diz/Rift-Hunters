"""Squelette : pièces hiérarchiques, poses par image, animations."""
import math
import numpy as np


class Part:
    """Une pièce : forme, matériau, ordre d'affichage (z) et pivot (articulation) dans le repère de repos.

    mode : "round" (ombrage pseudo-3D), "flat" (ton fixe), "emissive" (lumineux, sans ombre).
    shade : décalage de ton (−1 = plus sombre, pour les membres éloignés).
    level : ton forcé (mode flat/emissive), index dans la rampe.
    glow : contour clair au lieu de sombre (yeux, braises, cristaux).
    separate : trace une ligne sombre là où la pièce recouvre une pièce plus lointaine.
    texture : intensité du grain (0 = lisse), fixe sur la pièce (suit l'animation).
    """

    def __init__(self, name, shape, material, z=0, parent=None, pivot=(0.0, 0.0), mode="round", shade=0,
                 level=None, glow=False, separate=True, texture=0.0, visible=True):
        self.name = name
        self.shape = shape
        self.material = material
        self.z = z
        self.parent = parent
        self.pivot = pivot
        self.mode = mode
        self.shade = shade
        self.level = level
        self.glow = glow
        self.separate = separate
        self.texture = texture
        self.visible = visible


class Pose:
    """Transformation locale d'une pièce pour une image (autour de son pivot)."""

    def __init__(self, dx=0.0, dy=0.0, rot=0.0, sx=1.0, sy=1.0, visible=None, z=None, material=None, level=None):
        self.dx, self.dy, self.rot, self.sx, self.sy = dx, dy, rot, sx, sy
        self.visible, self.z, self.material, self.level = visible, z, material, level


class Anim:
    def __init__(self, name, frames, fps, loop, pose_fn):
        """pose_fn(frame_index, t) -> {nom de pièce: Pose}, t dans [0, 1[."""
        self.name, self.frames, self.fps, self.loop, self.pose_fn = name, frames, fps, loop, pose_fn


class Creature:
    def __init__(self, parts, anims):
        self.parts = parts
        self.anims = anims
        self.by_name = {p.name: p for p in parts}

    def world_transforms(self, poses):
        """Matrice 3x3 monde de chaque pièce (parents d'abord)."""
        result = {}

        def compute(part):
            if part.name in result:
                return result[part.name]
            pose = poses.get(part.name, Pose())
            px, py = part.pivot
            c, s = math.cos(pose.rot), math.sin(pose.rot)
            local = (_translate(px + pose.dx, py + pose.dy) @ np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
                     @ np.diag([pose.sx, pose.sy, 1.0]) @ _translate(-px, -py))
            if part.parent:
                local = compute(self.by_name[part.parent]) @ local
            result[part.name] = local
            return local

        for part in self.parts:
            compute(part)
        return result


def _translate(x, y):
    return np.array([[1.0, 0.0, x], [0.0, 1.0, y], [0.0, 0.0, 1.0]])


def wave(t, phase=0.0):
    return math.sin(2.0 * math.pi * (t + phase))
