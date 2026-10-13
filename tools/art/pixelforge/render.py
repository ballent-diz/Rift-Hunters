"""Rastérisation pixel art v2 : ombrage 7 tons à glissement de teinte, motifs de matière, lumière de Faille
(contre-jour violet), reflets, contour sélectif éclairé/ombré, halos des pièces lumineuses."""
import math
import numpy as np
from .palette import ramp, outline_for, lit_outline_for, hexrgb
from .rig import Pose
from . import patterns

LIGHT2 = np.array([-0.6, -0.8])   # lumière principale : haut-gauche
RIM2 = np.array([0.55, 0.83])     # contre-jour de la Faille : bas-droite
RIM_COLOR = hexrgb("#b56cf0")


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
    rim = np.zeros((h, w), dtype=bool)
    entries = []
    ordered = []
    for order, part in enumerate(creature.parts):
        pose = poses.get(part.name, Pose())
        visible = part.visible if pose.visible is None else pose.visible
        if visible:
            ordered.append((part.z if pose.z is None else pose.z, order, part, pose))
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
        part_rim = np.zeros((h, w), dtype=bool)
        if part.mode == "emissive":
            lv = np.full((h, w), n - 1 if forced is None else forced)
            if part.texture > 0.0:
                lv = lv - (np.abs(_hash(np.round(lx * 0.7), np.round(ly * 0.7))) < part.texture * 0.25)
        elif part.mode == "flat":
            lv = np.full((h, w), (n - 1) // 2 if forced is None else forced) + part.shade
        else:
            lx2, ly2 = local(X + 0.5, Y)
            lx3, ly3 = local(X, Y + 0.5)
            gx = (part.shape.sdf(lx2, ly2) * scale - d) / 0.5
            gy = (part.shape.sdf(lx3, ly3) * scale - d) / 0.5
            gl = np.maximum(np.hypot(gx, gy), 1e-6)
            gx, gy = gx / gl, gy / gl
            depth = np.clip(-d / max(part.shape.thickness() * scale, 0.8), 0.0, 1.0)
            lit = gx * LIGHT2[0] + gy * LIGHT2[1]
            edge = np.clip(1.0 - depth * 1.1, 0.0, 1.0)
            mid = (n - 1) / 2.0
            lvf = mid + lit * edge * (n - 1) * 0.40 + (depth - 0.45) * 1.1 + part.shade
            highlight = (lit > 0.3) & (depth > 0.12) & (depth < 0.6)
            lvf = np.where(highlight, lvf + 0.9, lvf)
            if part.texture > 0.0:
                lvf = lvf + _hash(np.round(lx), np.round(ly)) * part.texture
            if part.pattern:
                lvf = lvf + patterns.apply(part.pattern, lx, ly, lit)
            if part.shine:
                sparkle = (lit > 0.55) & (depth > 0.15) & (depth < 0.55) & (_hash(np.round(lx), np.round(ly)) > 0.32)
                lvf = np.where(sparkle, n - 1, lvf)
            lv = np.round(lvf).astype(int)
            # Arêtes : reflet en haut, ombre portée en bas (lumière zénithale).
            above = _shift(inside, 1, 0, False)
            below = _shift(inside, -1, 0, False)
            lv = np.where(inside & ~above, lv + 1, lv)
            lv = np.where(inside & ~below, lv - 1, lv)
            if part.rim:
                part_rim = inside & (d > -1.0) & (gx * RIM2[0] + gy * RIM2[1] > 0.7)
        lv = np.clip(lv, 0, n - 1)
        idx = len(entries)
        entries.append((part, material, z))
        owner = np.where(inside, idx, owner)
        level = np.where(inside, lv, level)
        rim = np.where(inside, part_rim, rim)

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    if not entries:
        return rgba
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
    for i, (part, material, _) in enumerate(entries):
        sel = owner == i
        if not sel.any():
            continue
        colors = np.array(ramp(material), dtype=np.uint8)
        rgba[sel, :3] = colors[level[sel]]
        rgba[sel, 3] = 255
    # Contre-jour de la Faille : liseré violet sur les arêtes bas-droite (lisibilité sur sol sombre).
    if rim.any():
        base = rgba[rim, :3].astype(float)
        rgba[rim, :3] = (base * 0.6 + np.array(RIM_COLOR) * 0.4).astype(np.uint8)
    _outline(rgba, owner, entries, zs)
    _glow(rgba, owner, entries)
    return rgba


def _outline(rgba, owner, entries, zs):
    h, w = owner.shape
    alpha = owner >= 0
    best = np.full((h, w), -1, dtype=int)
    best_z = np.full((h, w), -1e9)
    lit_side = np.zeros((h, w), dtype=bool)
    # (dy, dx) : direction vers le voisin opaque. Voisin à droite/en bas => le pixel est sur l'arête haute/gauche.
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        neigh = _shift(owner, -dy, -dx, -1)
        cand = (~alpha) & (neigh >= 0)
        nz = np.where(neigh >= 0, zs[np.maximum(neigh, 0)], -1e9)
        take = cand & (nz > best_z)
        best = np.where(take, neigh, best)
        best_z = np.where(take, nz, best_z)
        if dy > 0 or dx > 0:
            lit_side = lit_side | (cand & True)
    for i, (part, material, _) in enumerate(entries):
        sel = best == i
        if not sel.any():
            continue
        if part.glow:
            rgba[sel, :3] = ramp(material)[-2]
        else:
            dark = np.array(outline_for(material), dtype=np.uint8)
            light = np.array(lit_outline_for(material), dtype=np.uint8)
            lit_sel = sel & lit_side
            rgba[sel, :3] = dark
            rgba[lit_sel, :3] = light
        rgba[sel, 3] = 255


def _glow(rgba, owner, entries):
    """Halo semi-transparent de 2 pixels autour des pièces lumineuses (yeux, braises, cristaux)."""
    glow_parts = [i for i, e in enumerate(entries) if e[0].glow]
    if not glow_parts:
        return
    source = np.isin(owner, glow_parts)
    ring1 = np.zeros_like(source)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (-1, -1), (1, -1), (-1, 1)):
        ring1 |= _shift(source, dy, dx, False)
    ring2 = np.zeros_like(source)
    for dy, dx in ((0, 2), (0, -2), (2, 0), (-2, 0)):
        ring2 |= _shift(source, dy, dx, False)
    color = None
    for i in glow_parts:
        color = ramp(entries[i][1])[-3]
    empty = rgba[:, :, 3] == 0
    for ring, alpha in ((ring1, 150), (ring2 & ~ring1, 70)):
        sel = ring & empty
        rgba[sel, :3] = color
        rgba[sel, 3] = alpha


def _shift(a, dy, dx, fill):
    out = np.full_like(a, fill)
    h, w = a.shape
    ys = slice(max(dy, 0), h + min(dy, 0))
    yd = slice(max(-dy, 0), h + min(-dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0))
    xd = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = a[yd, xd]
    return out
