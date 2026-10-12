"""Rastérisation pixel art d'une image : pièces ordonnées par z, ombrage quantifié, contour sélectif."""
import math
import numpy as np
from .palette import ramp, outline_for, hexrgb, OUTLINE
from .rig import Pose

_L = np.array([-0.55, -0.75, 0.6])
LIGHT = _L / np.linalg.norm(_L)
LIGHT2 = np.array([-0.6, -0.8])


def _hash(ix, iy):
    v = np.sin(ix * 12.9898 + iy * 78.233) * 43758.5453
    return v - np.floor(v) - 0.5


def render_frame(creature, anim, index, size, anchor, remap=None):
    """Retourne un tableau RGBA uint8 (H, W, 4) pour l'image `index` de l'animation."""
    remap = remap or {}
    w, h = size
    xs = np.arange(w) + 0.5 - anchor[0]
    ys = np.arange(h) + 0.5 - anchor[1]
    X, Y = np.meshgrid(xs, ys)
    t = index / float(anim.frames)
    poses = anim.pose_fn(index, t)
    transforms = creature.world_transforms(poses)

    owner = np.full((h, w), -1, dtype=int)
    level = np.zeros((h, w), dtype=int)
    entries = []  # (part, material, effective z)
    ordered = []
    for order, part in enumerate(creature.parts):
        pose = poses.get(part.name, Pose())
        visible = part.visible if pose.visible is None else pose.visible
        if not visible:
            continue
        z = part.z if pose.z is None else pose.z
        ordered.append((z, order, part, pose))
    ordered.sort(key=lambda e: (e[0], e[1]))

    for z, _, part, pose in ordered:
        m = transforms[part.name]
        inv = np.linalg.inv(m)
        scale = math.sqrt(abs(np.linalg.det(m[:2, :2])))

        def local(xa, ya):
            return inv[0, 0] * xa + inv[0, 1] * ya + inv[0, 2], inv[1, 0] * xa + inv[1, 1] * ya + inv[1, 2]

        lx, ly = local(X, Y)
        d = part.shape.sdf(lx, ly) * scale
        inside = d < 0.0
        if not inside.any():
            continue
        material = remap.get(pose.material or part.material, pose.material or part.material)
        n = len(ramp(material))
        forced = pose.level if pose.level is not None else part.level
        if part.mode == "emissive":
            lv = np.full((h, w), n - 1 if forced is None else forced)
        elif part.mode == "flat":
            lv = np.full((h, w), n // 2 if forced is None else forced) + part.shade
        else:
            lx2, ly2 = local(X + 0.5, Y)
            lx3, ly3 = local(X, Y + 0.5)
            gx = (part.shape.sdf(lx2, ly2) * scale - d) / 0.5
            gy = (part.shape.sdf(lx3, ly3) * scale - d) / 0.5
            gl = np.maximum(np.hypot(gx, gy), 1e-6)
            gx, gy = gx / gl, gy / gl
            depth = np.clip(-d / max(part.shape.thickness() * scale, 0.8), 0.0, 1.0)
            # Ombrage « pixel art » : côté tourné vers la lumière (haut-gauche) éclairé, côté opposé dans l'ombre,
            # cœur légèrement plus clair, reflet sur la zone éclairée à mi-profondeur.
            lit = gx * LIGHT2[0] + gy * LIGHT2[1]
            rim = np.clip(1.0 - depth * 1.15, 0.0, 1.0)
            mid = (n - 1) / 2.0
            lvf = mid + lit * rim * (n - 1) * 0.42 + (depth - 0.4) * 0.6 + part.shade
            highlight = (lit > 0.35) & (depth > 0.15) & (depth < 0.65)
            lvf = np.where(highlight, lvf + 0.6, lvf)
            if part.texture > 0.0:
                lvf = lvf + _hash(np.round(lx), np.round(ly)) * part.texture
            lv = np.round(lvf).astype(int)
        if part.mode == "round":
            # Éclairage de bord (lumière zénithale) : reflet sur l'arête haute, ombre portée sur l'arête basse.
            above = _shift(inside, 1, 0, False)
            below = _shift(inside, -1, 0, False)
            lv = np.where(inside & ~above, lv + 1, lv)
            lv = np.where(inside & ~below, lv - 1, lv)
        lv = np.clip(lv, 0, n - 1)
        idx = len(entries)
        entries.append((part, material, z))
        owner = np.where(inside, idx, owner)
        level = np.where(inside, lv, level)

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    if not entries:
        return rgba
    # Lignes de séparation : bord d'une pièce qui recouvre une pièce plus lointaine.
    zs = np.array([e[2] for e in entries])
    sep = np.array([e[0].separate for e in entries])
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        neigh = _shift(owner, dy, dx, -1)
        mask = (owner >= 0) & (neigh >= 0) & (neigh != owner)
        if not mask.any():
            continue
        o = np.where(mask, owner, 0)
        nb = np.where(mask, neigh, 0)
        behind = mask & (zs[nb] < zs[o]) & sep[o]
        level = np.where(behind, np.minimum(level, 1), level)
    ramps = [ramp(e[1]) for e in entries]
    for i, (part, material, _) in enumerate(entries):
        sel = owner == i
        if not sel.any():
            continue
        colors = np.array(ramps[i], dtype=np.uint8)
        rgba[sel, :3] = colors[level[sel]]
        rgba[sel, 3] = 255
    # Contour sélectif (pixels transparents touchant la silhouette).
    alpha = owner >= 0
    best = np.full((h, w), -1, dtype=int)
    best_z = np.full((h, w), -1e9)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        neigh = _shift(owner, dy, dx, -1)
        cand = (~alpha) & (neigh >= 0)
        nz = np.where(neigh >= 0, zs[np.maximum(neigh, 0)], -1e9)
        take = cand & (nz > best_z)
        best = np.where(take, neigh, best)
        best_z = np.where(take, nz, best_z)
    for i, (part, material, _) in enumerate(entries):
        sel = best == i
        if not sel.any():
            continue
        color = ramp(material)[-2] if part.glow else outline_for(material)
        rgba[sel, :3] = color
        rgba[sel, 3] = 255
    return rgba


def _shift(a, dy, dx, fill):
    out = np.full_like(a, fill)
    h, w = a.shape
    ys = slice(max(dy, 0), h + min(dy, 0))
    yd = slice(max(-dy, 0), h + min(-dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0))
    xd = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = a[yd, xd]
    return out
