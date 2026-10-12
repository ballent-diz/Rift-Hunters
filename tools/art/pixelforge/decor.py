"""Générateurs de décor pixel art : sol, cailloux, rochers, ruines, herbes, ossements, fissures de Faille,
plaques de sol, bords d'arène et vide. Chaque fonction reçoit un générateur aléatoire et des rampes de couleurs
(listes de 7 tons RGB, du plus sombre au plus clair) : une nouvelle arène réutilise ces briques avec sa palette."""
import math
import numpy as np
from . import terrain as T


def hexramp(colors):
    return [tuple(int(c.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) for c in colors]


# ---------------------------------------------------------------------------------------------- sol


def cracked_ground(size, rng, ramps, crack_cells=5, stones=1800, crack_keep=0.4):
    """Terre sèche caillouteuse et fendue, périodique (se répète sans raccord).
    ramps : {"ground", "dust", "pebble"}. Retourne un tableau RGB (size, size, 3)."""
    n = size
    # Grain du sol : amas de 2 à 3 tons (et non un bruit pixel par pixel).
    grain = T.fbm(n, n, 64, 2, rng)
    fine = T.fbm(n, n, 160, 1, rng)
    macro = T.fbm(n, n, 4, 3, rng)
    hmap = (T.fbm(n, n, 10, 3, rng) - 0.5) * 0.6
    # Fissures : réseau sinueux dont seule une partie des bords est ouverte.
    warp = T.warp_field(n, n, 6, 22.0, rng)
    f1, f2, ident = T.worley(n, n, crack_cells, crack_cells, rng, warp=warp)
    open_edge = T.fbm(n, n, 10, 2, rng) > 1.0 - crack_keep
    width = 0.5 + 1.1 * T.fbm(n, n, 24, 2, rng)
    crack = ((f2 - f1) < width) & open_edge
    warp2 = T.warp_field(n, n, 12, 9.0, rng)
    g1, g2, _ = T.worley(n, n, crack_cells * 4, crack_cells * 4, rng, warp=warp2)
    branch_zone = T.blur(crack.astype(float), 8) > 0.03
    hair = ((g2 - g1) < 0.7) & branch_zone & (T.fbm(n, n, 30, 2, rng) > 0.55) & ~crack
    hmap = np.where(crack, hmap - 0.9, hmap)
    hmap = np.where(hair, hmap - 0.35, hmap)
    # Bords des fissures légèrement soulevés (plaques de terre sèche).
    lip = T.blur(crack.astype(float), 2) * 0.5
    hmap = hmap + np.where(crack, 0, lip)
    material = np.zeros((n, n), dtype=int)  # 0 sol, 1 poussière, 2 cailloux
    near_crack = T.blur(crack.astype(float), 3) > 0.12
    sediment = (T.blur(crack.astype(float), 2) > 0.18) & (grain > 0.45)
    material = np.where(crack | sediment, 1, material)
    stone_mask = np.zeros((n, n), dtype=bool)
    stone_tone = np.zeros((n, n))
    placed = tries = 0
    while placed < stones and tries < stones * 5:
        tries += 1
        cy, cx = rng.uniform(0, n, 2)
        iy, ix = int(cy) % n, int(cx) % n
        want = 0.8 if near_crack[iy, ix] else (0.4 if macro[iy, ix] < 0.45 else 0.2)
        if rng.random() > want:
            continue
        r = rng.choice([1.2, 1.6, 2.0, 2.6, 3.2, 4.2], p=[0.3, 0.27, 0.2, 0.12, 0.08, 0.03])
        ratio = rng.uniform(0.55, 0.9)
        mask, ys, xs = T.stamp_ellipse(hmap, cy, cx, r * ratio, r, rng.uniform(0, math.pi), 0.5 + r * 0.12)
        block = np.ix_(ys, xs)
        stone_mask[block] |= mask
        stone_tone[block] = np.where(mask, rng.uniform(-0.6, 0.8), stone_tone[block])
        placed += 1
    material = np.where(stone_mask, 2, material)
    lam = T.lambert(hmap, strength=3.5)
    ao = np.clip(T.blur(hmap, 2) - hmap, 0, 2)
    tone = 3.0 + (grain - 0.5) * 1.0 + (fine - 0.5) * 0.7 + (macro - 0.5) * 0.6 + lam * 5.0 - ao * 1.5
    tone = np.where(stone_mask, 3.4 + stone_tone + lam * 5.0, tone)
    tone = np.where(crack, 0.6 + lam * 1.5, tone)
    tone = np.where(hair, tone - 1.0, tone)
    levels = T.despeckle(np.clip(np.round(tone), 0, 6).astype(int), passes=2)
    return T.colorize(levels, material, [ramps["ground"], ramps["dust"], ramps["pebble"]])


# ------------------------------------------------------------------------------------------- outils


def _grid(h, w):
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    return yy + 0.5, xx + 0.5


def blob(h, w, cy, cx, ry, rx, rng, rough=0.15, detail=0.0):
    """Forme organique : ellipse au bord bosselé. Retourne (masque, rayon normalisé)."""
    yy, xx = _grid(h, w)
    u, v = (xx - cx) / rx, (yy - cy) / ry
    ang = np.arctan2(v, u)
    d = np.hypot(u, v)
    r = np.ones_like(d)
    for k in range(2, 8):
        r = r + rough / k ** 0.8 * rng.uniform(0.3, 1.0) * np.sin(k * ang + rng.uniform(0, 2 * math.pi))
    if detail > 0:
        r = r + detail * (T.fbm(h, w, (max(2, h // 5), max(2, w // 5)), 2, rng, wrap_y=False, wrap_x=False) - 0.5)
    return d < r, d / np.maximum(r, 1e-3)


def to_rgba(levels, mask, ramp, alpha=255):
    h, w = levels.shape
    out = np.zeros((h, w, 4), dtype=np.uint8)
    colors = np.array(ramp, dtype=np.uint8)
    out[mask, :3] = colors[np.clip(levels[mask], 0, len(ramp) - 1)]
    out[mask, 3] = alpha
    return out


def merge(base, top):
    """Pose `top` sur `base` (pixels opaques ou semi-opaques de top)."""
    sel = top[:, :, 3] > 0
    base[sel] = top[sel]
    return base


def cast_shadow(rgba, dx, dy=1, alpha=85, color=(6, 5, 12), rows=None):
    """Ombre portée sur le sol vers la droite (lumière haut-gauche). rows : ne projeter que le bas de l'objet."""
    a = rgba[:, :, 3] >= 200
    if rows is not None:
        a = a.copy()
        a[:rows] = False
    h, w = a.shape
    sh = np.zeros_like(a)
    for k in range(1, max(dx, 1) + 1):
        ky = min(dy, k)
        sh[ky:, k:] |= a[:h - ky, :w - k]
    sh &= rgba[:, :, 3] == 0
    rgba[sh, :3] = color
    rgba[sh, 3] = alpha
    return rgba


def finish(rgba, ramp, shadow_dx=2, shadow_rows=None, outline=True):
    if outline:
        dark = tuple(int(c * 0.45) for c in ramp[0])
        T.outline(rgba, dark, ramp[1])
    if shadow_dx:
        cast_shadow(rgba, shadow_dx, rows=shadow_rows)
    return rgba


def _plot(level_map, mask, x, y, tone):
    h, w = mask.shape
    ix, iy = int(round(x - 0.5)), int(round(y - 0.5))
    if 0 <= ix < w and 0 <= iy < h:
        if not mask[iy, ix] or level_map[iy, ix] < tone:
            level_map[iy, ix] = tone
        mask[iy, ix] = True


def jagged_path(rng, start, angle, length, step=1.0, wiggle=0.45):
    pts = [np.array(start, dtype=float)]
    a = angle
    for _ in range(int(length / step)):
        a += rng.uniform(-wiggle, wiggle)
        a = angle + np.clip(a - angle, -0.9, 0.9)
        pts.append(pts[-1] + step * np.array([math.cos(a), math.sin(a)]))
    return pts


# ------------------------------------------------------------------------------------------ objets


def rock(rng, ramp, width, height, squash=0.6):
    """Rocher vu en 3/4 : dessus facetté éclairé en haut-gauche, face avant sombre, ombre portée."""
    rx, ry = width / 2.0, width / 2.0 * squash
    pad = 3
    W = int(math.ceil(width + pad * 2 + height * 0.6))
    H = int(math.ceil(2 * ry + height + pad * 2))
    cx, cy = pad + rx, pad + ry
    top, dn = blob(H, W, cy, cx, ry, rx, rng, rough=0.16, detail=0.3)
    body = top.copy()
    for k in range(1, height + 1):
        body[k:] |= top[:-k]
    face = body & ~top
    yy, xx = _grid(H, W)
    hm = np.clip(1 - dn ** 2, 0, 1) * rx * 0.55
    _, _, ident = T.worley(H, W, max(2, H // 6), max(2, W // 6), rng, wrap=False)
    planes = rng.uniform(-0.5, 0.5, (ident.max() + 1, 2))
    hm = hm + planes[ident, 0] * (xx - cx) * 0.35 + planes[ident, 1] * (yy - cy) * 0.35
    lam = T.lambert(hm, 1.0, wrap=False)
    tone = 4.0 + lam * 4.5 - np.clip(dn - 0.8, 0, 1) * 2.0
    bottom = np.where(top.any(axis=0), H - 1 - np.argmax(top[::-1], axis=0), 0)
    frac = np.clip((yy - bottom[None, :]) / max(height, 1), 0, 1)
    strata = T.fbm(H, W, (max(2, H // 3), max(2, W // 10)), 2, rng, wrap_y=False, wrap_x=False)
    face_tone = 2.3 + 1.1 * np.clip((cx - xx) / rx, -1, 1) - 1.2 * frac + (strata - 0.5) * 1.2
    tone = np.where(face, face_tone, tone)
    rim = top & np.roll(face, -1, axis=0)
    tone = np.where(rim, tone + 1.0, tone)
    levels = T.despeckle(np.clip(np.round(tone), 0, 6).astype(int), wrap=False)
    rgba = to_rgba(levels, body, ramp)
    return finish(rgba, ramp, shadow_dx=max(2, int(height * 0.7)), shadow_rows=int(cy))


def column_stump(rng, ramp, radius, height, drum=9):
    """Tronçon de colonne en ruine (fût cannelé, assises, dessus brisé)."""
    rx, ry = radius, radius * 0.5
    pad = 3
    W = int(math.ceil(2 * rx + pad * 2 + height * 0.5))
    H = int(math.ceil(2 * ry + height + pad * 2 + 2))
    cx, cy = pad + rx, pad + ry + 2
    yy, xx = _grid(H, W)
    u = (xx - cx) / rx
    top, dn = blob(H, W, cy, cx, ry, rx, rng, rough=0.05)
    body = top.copy()
    for k in range(1, height + 1):
        body[k:] |= top[:-k]
    face = body & ~top
    curve = ry * np.sqrt(np.clip(1 - u ** 2, 0, 1))
    down = yy - (cy + curve)
    cyl = 2.0 + 2.6 * np.clip(1 - ((u + 0.35) / 0.9) ** 2, 0, 1) - 0.6 * (u > 0.55)
    flute = (np.abs(((xx - cx) % 4) - 2) < 0.6) & (np.abs(u) < 0.85)
    joint = (np.abs((down % drum) - drum + 0.5) < 0.6) & (down > 2)
    face_tone = cyl - flute * 0.8 - joint * 1.4 - np.clip(down / height, 0, 1) * 0.6
    # Dessus brisé : surface claire, éclats et fissures.
    chips = T.fbm(H, W, (max(2, H // 3), max(2, W // 3)), 2, rng, wrap_y=False, wrap_x=False)
    top_tone = 4.4 + (chips - 0.5) * 2.2 - dn * 0.8
    tone = np.where(face, face_tone, np.where(top, top_tone, 0))
    levels = T.despeckle(np.clip(np.round(tone), 0, 6).astype(int), wrap=False)
    rgba = to_rgba(levels, body, ramp)
    # Morceau manquant sur le bord du dessus (colonne cassée).
    bite, _ = blob(H, W, cy - ry * 0.4, cx + rx * rng.uniform(-0.6, 0.6), ry * 0.7, rx * 0.45, rng, rough=0.3)
    rgba[bite & top & (yy < cy), 3] = 0
    return finish(rgba, ramp, shadow_dx=max(2, int(height * 0.6)), shadow_rows=int(cy))


def fallen_column(rng, ramp, length, radius, drum=10):
    """Colonne couchée, brisée aux deux bouts."""
    pad = 3
    W = int(length + pad * 2 + 4)
    H = int(radius * 2 + pad * 2 + 6)
    cy = pad + radius
    x0, x1 = pad, pad + length
    yy, xx = _grid(H, W)
    jag0 = x0 + 3 + (T.fbm(H, 1, (4, 1), 2, rng, wrap_y=False, wrap_x=False)[:, 0] - 0.5) * 7
    jag1 = x1 - 3 + (T.fbm(H, 1, (4, 1), 2, rng, wrap_y=False, wrap_x=False)[:, 0] - 0.5) * 7
    v = (yy - cy) / radius
    body = (np.abs(v) < 1.0) & (xx > jag0[:, None]) & (xx < jag1[:, None])
    tone = 4.6 - 2.3 * (v + 1.0) * 0.5 * 1.6 + 1.2 * np.clip(1 - ((v + 0.45) / 0.4) ** 2, 0, 1)
    flute = (np.abs(((yy - cy) % 4) - 2) < 0.6) & (np.abs(v) < 0.8)
    joint = np.abs(((xx - x0) % drum) - drum + 0.5) < 0.6
    tone = tone - flute * 0.7 - joint * 1.3
    cap = body & (xx > jag1[:, None] - 2.5)
    tone = np.where(cap, 3.6 - v * 0.8, tone)
    levels = T.despeckle(np.clip(np.round(tone), 0, 6).astype(int), wrap=False)
    rgba = to_rgba(levels, body, ramp)
    return finish(rgba, ramp, shadow_dx=3)


def flagstones(rng, ramp, gap_ramp, w, h, cell=11):
    """Dallage ancien en ruine : pierres polygonales biseautées, joints de terre, pierres manquantes, bord rongé."""
    area, dn = blob(h, w, h / 2, w / 2, h / 2 - 2, w / 2 - 2, rng, rough=0.22, detail=0.8)
    warp = T.warp_field(h, w, (max(2, h // 20), max(2, w // 20)), 2.0, rng, wrap_y=False, wrap_x=False)
    f1, f2, ident = T.worley(h, w, max(2, h // cell), max(2, w // cell), rng, wrap=False, warp=warp)
    edge = f2 - f1
    count = ident.max() + 1
    keep = rng.random(count) > 0.18
    offset = rng.uniform(-0.8, 0.6, count)
    stone = (edge > 1.1) & keep[ident] & area & (dn < 0.92 + rng.uniform(-0.05, 0.05))
    hm = np.clip(edge / 3.0, 0, 1) ** 0.6 + offset[ident] * 0.15
    lam = T.lambert(hm, 3.0, wrap=False)
    tone = 2.6 + offset[ident] + lam * 4.0
    cracked = rng.random(count) < 0.25
    split = np.abs(T.fbm(h, w, (max(2, h // 8), max(2, w // 8)), 2, rng, wrap_y=False, wrap_x=False) - 0.5) < 0.03
    tone = np.where(cracked[ident] & split, tone - 1.5, tone)
    levels = np.clip(np.round(tone), 0, 6).astype(int)
    gaps = area & ~stone & (dn < 0.8)
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[stone] = to_rgba(levels, stone, ramp)[stone]
    gap_levels = np.where(T.fbm(h, w, (max(2, h // 6), max(2, w // 6)), 2, rng, wrap_y=False, wrap_x=False) > 0.5, 2, 1)
    rgba[gaps] = to_rgba(gap_levels, gaps, gap_ramp)[gaps]
    return rgba


def grass_tuft(rng, ramp, w=14, h=14, blades=9):
    """Touffe d'herbe sèche : brins courbés, pied sombre, pointes claires."""
    levels = np.zeros((h, w), dtype=int)
    mask = np.zeros((h, w), dtype=bool)
    base_y = h - 2.0
    cx = w / 2.0
    for _ in range(blades):
        x0 = cx + rng.normal(0, w * 0.12)
        length = rng.uniform(0.4, 1.0) * (h - 3)
        lean = rng.uniform(-0.7, 0.7)
        bend = rng.uniform(-0.3, 0.3)
        steps = int(length * 2) + 2
        for i in range(steps):
            t = i / (steps - 1)
            x = x0 + lean * t * length * 0.6 + bend * t * t * length
            y = base_y - t * length
            tone = int(round(1 + t * 4.6 + (lean < -0.2) * 0.8))
            _plot(levels, mask, x, y, min(tone, 6))
    for dx in (-1, 0, 1):
        _plot(levels, mask, cx + dx, base_y + 0.5, 0)
    rgba = to_rgba(levels, mask, ramp)
    return cast_shadow(rgba, 2, alpha=70)


def pebbles(rng, ramp, w, h, count):
    hm = np.zeros((h, w))
    for _ in range(count):
        r = rng.uniform(1.2, min(w, h) * 0.22)
        T.stamp_ellipse(hm, rng.uniform(r, h - r), rng.uniform(r, w - r), r * rng.uniform(0.55, 0.85), r,
                        rng.uniform(0, math.pi), 0.6 + r * 0.15, wrap=False)
    mask = hm > 0
    lam = T.lambert(hm, 4.0, wrap=False)
    levels = np.clip(np.round(3.4 + lam * 6.0 + rng.uniform(-0.4, 0.4)), 1, 6).astype(int)
    rgba = to_rgba(levels, mask, ramp)
    return finish(rgba, ramp, shadow_dx=1)


def small_crack(rng, ramp, w, h):
    """Fissure fine posée sur le sol (le fond reste transparent)."""
    levels = np.zeros((h, w), dtype=int)
    mask = np.zeros((h, w), dtype=bool)
    lip = np.zeros((h, w), dtype=bool)
    paths = [jagged_path(rng, (2, h * rng.uniform(0.3, 0.7)), rng.uniform(-0.4, 0.4), w - 4)]
    for _ in range(int(rng.integers(1, 4))):
        src = paths[0][int(rng.integers(3, len(paths[0]) - 3))]
        paths.append(jagged_path(rng, src, rng.choice([-1, 1]) * rng.uniform(0.6, 1.2), rng.uniform(5, w * 0.4)))
    for pts in paths:
        for p in pts:
            _plot(levels, mask, p[0], p[1], 0)
    lip[1:, 1:] = mask[:-1, :-1]
    lip &= ~mask
    levels = np.where(lip, 4, levels)
    rgba = to_rgba(levels, mask | lip, ramp)
    rgba[lip, 3] = 170
    return rgba


def patch(rng, ramp, w, h, kind="dirt", grass_ramp=None):
    """Plaque de sol (terre, cendre) au bord tramé, pour casser la répétition du sol."""
    area, dn = blob(h, w, h / 2, w / 2, h / 2 - 1, w / 2 - 1, rng, rough=0.2, detail=0.8)
    grain = T.fbm(h, w, (max(2, h // 6), max(2, w // 6)), 2, rng, wrap_y=False, wrap_x=False)
    hm = (grain - 0.5) * 0.5
    stones = np.zeros((h, w), dtype=bool)
    for _ in range(int(w * h / 90)):
        r = rng.choice([1.0, 1.4, 1.9])
        m, ys, xs = T.stamp_ellipse(hm, rng.uniform(0, h), rng.uniform(0, w), r * 0.7, r, rng.uniform(0, 3), 0.7, wrap=False)
        stones[np.ix_(ys, xs)] |= m
    lam = T.lambert(hm, 4.0, wrap=False)
    tone = 2.6 + (grain - 0.5) * 2.0 + lam * 5.0 - np.clip(dn - 0.75, 0, 1) * 2
    tone = np.where(stones, tone + 0.8, tone)
    levels = T.despeckle(np.clip(np.round(tone), 0, 6).astype(int), wrap=False)
    # Bord tramé : un pixel sur deux dans la bande extérieure (transition pixel art).
    yy, xx = np.mgrid[0:h, 0:w]
    border = area & (dn > 0.82) & ((yy + xx) % 2 == 0)
    inner = area & (dn <= 0.82)
    rgba = to_rgba(levels, inner | border, ramp)
    if kind == "grass" and grass_ramp is not None:
        for _ in range(int(w * h / 26)):
            gy, gx = rng.uniform(4, h - 1), rng.uniform(2, w - 2)
            if not area[int(gy), int(gx)] or dn[int(gy), int(gx)] > 0.8 * rng.uniform(0.6, 1.2):
                continue
            tuft = grass_tuft(rng, grass_ramp, 7, int(rng.integers(5, 9)), int(rng.integers(2, 5)))
            th, tw = tuft.shape[:2]
            y0, x0 = int(gy) - th + 1, int(gx) - tw // 2
            if y0 < 0 or x0 < 0 or y0 + th > h or x0 + tw > w:
                continue
            region = rgba[y0:y0 + th, x0:x0 + tw]
            sel = tuft[:, :, 3] >= 200
            region[sel] = tuft[sel]
    return rgba


def veins(rng, ramp, w, h, count=5):
    """Veines de corruption qui rampent sur le sol (sans lueur : le danger reste réservé aux Corrompus)."""
    levels = np.zeros((h, w), dtype=int)
    mask = np.zeros((h, w), dtype=bool)
    c = np.array([w / 2, h / 2])
    for i in range(count):
        a = i / count * 2 * math.pi + rng.uniform(-0.3, 0.3)
        pts = jagged_path(rng, c, a, min(w, h) * rng.uniform(0.3, 0.48), wiggle=0.5)
        for j, p in enumerate(pts):
            tone = 3 if j < len(pts) * 0.5 else 2
            _plot(levels, mask, p[0], p[1], tone)
            if j < len(pts) * 0.35:
                _plot(levels, mask, p[0] + 1, p[1], tone - 1)
        if rng.random() < 0.7:
            src = pts[len(pts) // 2]
            for p in jagged_path(rng, src, a + rng.choice([-0.8, 0.8]), len(pts) * 0.4, wiggle=0.5):
                _plot(levels, mask, p[0], p[1], 2)
    core, _ = blob(h, w, h / 2, w / 2, 3.5, 4.5, rng, rough=0.2)
    levels = np.where(core, 1, levels)
    mask |= core
    rgba = to_rgba(levels, mask, ramp)
    return rgba


def fissure(rng, ramp, rift_ramp, w, h):
    """Fissure de Faille : gorge sombre, cœur violet lumineux, lèvres éclairées, sol roussi autour.
    Retourne (image, halo) : le halo se dessine en mode additif et pulse en jeu."""
    core = np.zeros((h, w), dtype=bool)
    main = jagged_path(rng, (4, h * rng.uniform(0.35, 0.65)), rng.uniform(-0.3, 0.3), w - 8, wiggle=0.55)
    paths = [(main, 2.4)]
    for _ in range(int(rng.integers(2, 5))):
        src = main[int(rng.integers(4, len(main) - 4))]
        paths.append((jagged_path(rng, src, rng.choice([-1, 1]) * rng.uniform(0.5, 1.3), rng.uniform(6, w * 0.35),
                                  wiggle=0.6), 1.2))
    yy, xx = _grid(h, w)
    width = np.zeros((h, w))
    for pts, base in paths:
        n = len(pts)
        for i, p in enumerate(pts):
            taper = base * (0.35 + 0.65 * math.sin(math.pi * (i + 1) / (n + 1)))
            r = int(math.ceil(taper)) + 1
            y0, y1 = max(int(p[1]) - r, 0), min(int(p[1]) + r + 1, h)
            x0, x1 = max(int(p[0]) - r, 0), min(int(p[0]) + r + 1, w)
            d = np.hypot(yy[y0:y1, x0:x1] - p[1], xx[y0:y1, x0:x1] - p[0])
            width[y0:y1, x0:x1] = np.maximum(width[y0:y1, x0:x1], taper - d)
    gorge = width > 0.0
    core = width > 1.1
    hot = width > 1.9
    lip_lit = np.zeros_like(gorge)
    lip_lit[1:, 1:] = gorge[:-1, :-1]
    lip_lit &= ~gorge
    lip_dark = np.zeros_like(gorge)
    lip_dark[:-1, :-1] = gorge[1:, 1:]
    lip_dark &= ~gorge & ~lip_lit
    scorch = (T.blur(gorge.astype(float), 3, wrap=False) > 0.05) & ~gorge & ~lip_lit & ~lip_dark
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[scorch, :3] = ramp[0]
    rgba[scorch, 3] = np.where((yy[scorch] + xx[scorch]).astype(int) % 2 == 0, 150, 90)
    rgba[lip_dark, :3] = ramp[1]
    rgba[lip_dark, 3] = 255
    rgba[lip_lit, :3] = ramp[4]
    rgba[lip_lit, 3] = 255
    rgba[gorge, :3] = rift_ramp[0]
    rgba[gorge, 3] = 255
    rgba[core, :3] = rift_ramp[3]
    rgba[hot, :3] = rift_ramp[5]
    halo_level = T.blur(core.astype(float), 3, wrap=False)
    halo = np.zeros((h, w, 4), dtype=np.uint8)
    for threshold, alpha, tone in ((0.04, 45, 2), (0.15, 80, 3), (0.35, 120, 4)):
        sel = halo_level > threshold
        halo[sel, :3] = rift_ramp[tone]
        halo[sel, 3] = alpha
    return rgba, halo


def crystal_shards(rng, ramp, w, h, count=3):
    """Éclats de cristal de Faille plantés dans le sol (faces claire/sombre, pointe brillante) + halo."""
    levels = np.zeros((h, w), dtype=int)
    mask = np.zeros((h, w), dtype=bool)
    base_y = h - 3.0
    for i in range(count):
        cx = w / 2 + (i - (count - 1) / 2) * w / (count + 1) + rng.uniform(-1.5, 1.5)
        height = rng.uniform(0.45, 0.95) * (h - 5)
        half = rng.uniform(2.0, 3.4)
        tilt = rng.uniform(-0.35, 0.35)
        for k in range(int(height * 2)):
            t = k / (height * 2)
            y = base_y - t * height
            x_mid = cx + tilt * t * height
            span = half * (1 - t ** 1.6)
            for xs in np.arange(-span, span + 0.01, 0.5):
                tone = 2 if xs < -0.3 else 1
                tone = 4 if (t > 0.8 or (xs < -span + 1.0 and t > 0.3)) else tone
                _plot(levels, mask, x_mid + xs, y, tone)
    rgba = to_rgba(levels, mask, ramp)
    halo_level = T.blur(mask.astype(float), 3, wrap=False)
    finish(rgba, ramp, shadow_dx=2)
    halo = np.zeros((h, w, 4), dtype=np.uint8)
    for threshold, alpha, tone in ((0.08, 30, 2), (0.25, 55, 3)):
        sel = (halo_level > threshold) & (rgba[:, :, 3] == 0)
        halo[sel, :3] = ramp[tone]
        halo[sel, 3] = alpha
    return rgba, halo


# ----------------------------------------------------------------- objets dessinés avec le squelette


def register_ramp(name, colors):
    """Rend une rampe de décor utilisable par render_frame (matériau nommé)."""
    from . import palette as P
    P.PALETTE[name] = ["#%02x%02x%02x" % tuple(c) for c in colors]


def render_parts(parts, w, h, anchor):
    from .rig import Creature, Anim
    from .render import render_frame
    creature = Creature(parts, [Anim("still", 1, 1, True, lambda i, t: {})])
    return render_frame(creature, creature.anims[0], 0, (w, h), anchor)


def ribcage(rng, material, w=56, h=30):
    """Carcasse d'une grande bête : colonne, côtes en arche, crâne cornu."""
    from .rig import Part
    from .geometry import Capsule, Ellipse, Arc
    parts = [Part("spine", Capsule(-15, 0, 18, 1, 2.2, 1.2), material, z=0, rim=False)]
    for i in range(5):
        x = -8 + i * 6.0
        r = 10.0 - i * 1.3 + rng.uniform(-0.6, 0.6)
        broken = rng.random() < 0.3
        a1 = 2 * math.pi - (0.9 if broken else 0.25)
        parts.append(Part(f"rib{i}", Arc(x, 1, r, 2.2, math.pi + 0.25, a1), material, z=1 + (i % 2), rim=False))
    parts += [
        Part("skull", Ellipse(-19, -2, 5.0, 4.0, 0.2), material, z=3, rim=False),
        Part("snout", Capsule(-23, 0, -27, 2, 2.6, 1.6), material, z=3, rim=False),
        Part("socket", Ellipse(-20, -2.6, 1.4, 1.1), "void_dark", z=4, mode="flat", level=0, rim=False),
        Part("horn", Arc(-15, -3, 5.0, 1.6, math.pi * 1.05, math.pi * 1.6), material, z=2, rim=False),
    ]
    rgba = render_parts(parts, w, h, (w * 0.62, h * 0.66))
    return cast_shadow(rgba, 2, alpha=80)


def skull(rng, material, w=16, h=13):
    from .rig import Part
    from .geometry import Capsule, Ellipse
    parts = [
        Part("cranium", Ellipse(0, -1, 4.6, 3.8), material, z=0, rim=False),
        Part("snout", Capsule(3, 1, 6, 2, 2.2, 1.4), material, z=1, rim=False),
        Part("socket", Ellipse(1.2, -1.2, 1.3, 1.1), "void_dark", z=2, mode="flat", level=0, rim=False),
        Part("socket2", Ellipse(-1.6, -1.0, 1.0, 1.0), "void_dark", z=2, mode="flat", level=0, rim=False),
    ]
    rgba = render_parts(parts, w, h, (w * 0.42, h * 0.55))
    return cast_shadow(rgba, 1, alpha=80)


def bones(rng, material, w=18, h=12, count=3):
    from .rig import Part
    from .geometry import Capsule, Circle
    parts = []
    for i in range(count):
        a = rng.uniform(-0.8, 0.8)
        length = rng.uniform(4.5, 7.0)
        cx, cy = rng.uniform(-3, 3), rng.uniform(-2, 2)
        dx, dy = math.cos(a) * length, math.sin(a) * length
        parts += [Part(f"b{i}", Capsule(cx - dx, cy - dy, cx + dx, cy + dy, 1.0), material, z=i, rim=False),
                  Part(f"k{i}a", Circle(cx - dx, cy - dy, 1.5), material, z=i, rim=False),
                  Part(f"k{i}b", Circle(cx + dx, cy + dy, 1.5), material, z=i, rim=False)]
    rgba = render_parts(parts, w, h, (w / 2, h / 2))
    return cast_shadow(rgba, 1, alpha=80)


def dead_stump(rng, bark, wood, w=26, h=26):
    """Souche morte : tronc fendu, dessus coupé clair, racines qui s'étalent."""
    from .rig import Part
    from .geometry import Capsule, Ellipse
    th = rng.uniform(7, 10)
    parts = [Part("trunk", Capsule(0, 0, 0, -th, 5.2, 4.6), bark, z=1, rim=False, pattern=("stripes", 2.5, 1.5708))]
    for i, (ex, ey) in enumerate(((-9, 3), (8, 4), (-5, 6), (10, -1))):
        parts.append(Part(f"root{i}", Capsule(0, 0, ex + rng.uniform(-1, 1), ey, 2.2, 0.8), bark, z=0, rim=False))
    parts += [Part("top", Ellipse(0, -th, 4.4, 2.2), wood, z=2, rim=False),
              Part("spike", Capsule(2, -th, 3.5, -th - 6, 1.6, 0.5), bark, z=3, rim=False)]
    rgba = render_parts(parts, w, h, (w / 2 - 1, h * 0.72))
    return cast_shadow(rgba, 4, alpha=80, rows=int(h * 0.5))


def roots(rng, bark, w=24, h=12):
    from .rig import Part
    from .geometry import Capsule
    parts = []
    x, y = -w / 2 + 3, rng.uniform(-1, 1)
    for i in range(4):
        nx, ny = x + rng.uniform(4, 6), np.clip(y + rng.uniform(-2.5, 2.5), -h / 2 + 2, h / 2 - 2)
        parts.append(Part(f"r{i}", Capsule(x, y, nx, ny, 1.6 - i * 0.25, 1.4 - i * 0.25), bark, z=i, rim=False))
        if rng.random() < 0.5:
            parts.append(Part(f"t{i}", Capsule(x, y, x + rng.uniform(-1, 2), y + rng.choice([-1, 1]) * rng.uniform(2, 4),
                                               0.9, 0.5), bark, z=i, rim=False))
        x, y = nx, ny
    rgba = render_parts(parts, w, h, (w / 2, h / 2))
    return cast_shadow(rgba, 1, alpha=80)


# --------------------------------------------------------------------------- bords d'arène et vide


def void_tile(rng, size, nebula, stars):
    """Vide de la Faille vu au-delà du bord : nébuleuse tramée très sombre et étoiles (périodique)."""
    n = size
    neb = T.fbm(n, n, 3, 5, rng)
    detail = T.fbm(n, n, 8, 3, rng)
    v = np.clip((neb - 0.42) * 2.3, 0, 1) * (0.55 + 0.45 * detail)
    level = np.clip(np.floor(v * len(nebula) + T.bayer(n, n) * 0.9), 0, len(nebula) - 1).astype(int)
    rgb = np.array(nebula, dtype=np.uint8)[level]
    for _ in range(int(n * n / 2600)):
        y, x = rng.integers(0, n, 2)
        tier = rng.choice([0, 1, 2], p=[0.62, 0.3, 0.08])
        rgb[y, x] = stars[tier]
        if tier == 2:
            for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
                rgb[(y + dy) % n, (x + dx) % n] = stars[0]
    return rgb


def cliff_strip(rng, ramp, length, lip=6, depth=92, fade=26, glow_ramp=None):
    """Bord sud : falaise d'orgues basaltiques qui plonge dans le vide (répétable en largeur).
    Les `lip` premières rangées recouvrent le bord du sol."""
    H = lip + depth + fade
    levels = np.zeros((H, length), dtype=int)
    mask = np.zeros((H, length), dtype=bool)
    widths = []
    while sum(widths) < length - 26:
        widths.append(int(rng.integers(11, 24)))
    widths.append(length - sum(widths))
    bay = T.bayer(H, length)
    x0 = 0
    for cw in widths:
        top = lip - 1 + int(rng.integers(-2, 3))
        bottom = lip + int(depth * rng.uniform(0.45, 1.0))
        joints = sorted(set(int(j) for j in rng.integers(top + 8, max(bottom, top + 9), int(rng.integers(1, 4)))))
        lit_w = max(2, int(cw * rng.uniform(0.22, 0.35)))
        tip = rng.uniform(0.25, 0.75) * cw
        slope = rng.uniform(0.5, 1.4)
        for x in range(x0, x0 + cw):
            k = x - x0
            if k == 0:
                face = 0
            elif k <= lit_w:
                face = 3
            elif k < cw - 3:
                face = 2
            else:
                face = 1
            cap = top + 3
            end = int(bottom - abs(k - tip) * slope)
            for y in range(max(top, 0), min(end + 1, H)):
                if y < cap:
                    tone = 4 if k <= cw * 0.6 else 3
                    if y == top:
                        tone += 1
                    if k == 0:
                        tone = 2
                elif y == cap:
                    tone = 1
                else:
                    tone = face
                    if y in joints:
                        tone = 0
                    elif y - 1 in joints and face > 0:
                        tone = face + 1
                    depth_frac = (y - cap) / max(end - cap, 1)
                    tone = tone - int(depth_frac > 0.55) - int(depth_frac > 0.82)
                    if y >= end - 1:
                        tone = 0
                levels[y, x] = max(tone, 0)
                mask[y, x] = True
        x0 += cw
    rgba = to_rgba(levels, mask, ramp)
    if glow_ramp is not None:
        # Lueur de la Faille qui monte du vide sous la falaise : trois bandes plates, très discrètes.
        start = lip + int(depth * 0.55)
        span = H - start
        for y in range(start, H):
            t = (y - start) / span
            alpha = 30 if t < 0.2 else (55 if t < 0.4 else (75 if t < 0.65 else (45 if t < 0.85 else 22)))
            row = rgba[y]
            empty = row[:, 3] == 0
            if t > 0.85:
                empty &= (np.arange(length) + y) % 2 == 0
            row[empty, :3] = glow_ramp[2]
            row[empty, 3] = alpha
    return rgba


def rim_strip(rng, ramp, length, lit, void_rgb, inset=8, outset=6):
    """Bord de plateau vu du dessus (orientation : intérieur en haut, vide en bas), répétable en longueur.
    lit : 0 (bord à l'ombre) … 1 (bord face à la lumière)."""
    H = inset + outset
    levels = np.zeros((H, length), dtype=int)
    mask = np.zeros((H, length), dtype=bool)
    alpha = np.zeros((H, length), dtype=np.uint8)
    jag = (T.fbm(1, length, (1, 32), 3, rng, wrap_y=False) - 0.5)[0] * 6
    bay = T.bayer(H, length)
    for x in range(length):
        edge = inset + int(round(jag[x]))
        for y in range(H):
            if y < edge - 3:
                # Assombrissement tramé près du bord (le sol descend vers le vide).
                t = (y - (edge - 9)) / 6.0
                if t > 0 and t + bay[y, x] * 0.6 > 0.5:
                    levels[y, x] = 0
                    mask[y, x] = True
                    alpha[y, x] = 110
            elif y < edge:
                levels[y, x] = int(round(2 + lit * 2)) if y == edge - 3 else int(round(1 + lit))
                mask[y, x] = True
                alpha[y, x] = 255
            elif y == edge:
                levels[y, x] = 0
                mask[y, x] = True
                alpha[y, x] = 255
    rgba = to_rgba(levels, mask, ramp)
    rgba[:, :, 3] = np.where(mask, alpha, 0)
    # Entre le bord déchiqueté et la limite de l'arène : on voit déjà le vide.
    for x in range(length):
        edge = inset + int(round(jag[x]))
        for y in range(edge + 1, inset):
            rgba[y, x, :3] = void_rgb
            rgba[y, x, 3] = 255
    return rgba
