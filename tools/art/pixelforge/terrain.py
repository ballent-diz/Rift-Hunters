"""Outils de décor : bruits périodiques (textures qui se répètent sans raccord), cellules de Voronoï,
éclairage d'une carte de hauteur (lumière haut-gauche, comme les créatures) et nettoyage pixel art."""
import numpy as np

# Vecteur vers la lumière (x droite, y bas, z haut) : haut-gauche et au-dessus.
LIGHT3 = np.array([-0.5, -0.62, 0.6])
LIGHT3 = LIGHT3 / np.linalg.norm(LIGHT3)

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.47


def _axis(n, cells, wrap):
    pos = (np.arange(n) + 0.5) * cells / n
    i0 = np.floor(pos).astype(int)
    f = pos - i0
    f = f * f * f * (f * (f * 6 - 15) + 10)
    i1 = (i0 + 1) % cells if wrap else np.minimum(i0 + 1, cells)
    return i0 % (cells if wrap else cells + 1), i1, f


def value_noise(h, w, cells_y, cells_x, rng, wrap_y=True, wrap_x=True):
    """Bruit de valeur lissé dans [0, 1], périodique sur les axes demandés."""
    grid = rng.random((cells_y + (0 if wrap_y else 1), cells_x + (0 if wrap_x else 1)))
    y0, y1, fy = _axis(h, cells_y, wrap_y)
    x0, x1, fx = _axis(w, cells_x, wrap_x)
    fy = fy[:, None]
    fx = fx[None, :]
    a = grid[y0][:, x0] * (1 - fx) + grid[y0][:, x1] * fx
    b = grid[y1][:, x0] * (1 - fx) + grid[y1][:, x1] * fx
    return a * (1 - fy) + b * fy


def fbm(h, w, cells, octaves, rng, gain=0.5, wrap_y=True, wrap_x=True):
    """Somme de bruits (détails de plus en plus fins), normalisée dans [0, 1]."""
    total = np.zeros((h, w))
    amp, norm = 1.0, 0.0
    cy = cx = cells
    if isinstance(cells, tuple):
        cy, cx = cells
    for _ in range(octaves):
        total += value_noise(h, w, max(1, int(cy)), max(1, int(cx)), rng, wrap_y, wrap_x) * amp
        norm += amp
        amp *= gain
        cy, cx = cy * 2, cx * 2
    total /= norm
    lo, hi = total.min(), total.max()
    return (total - lo) / max(hi - lo, 1e-6)


def worley(h, w, cells_y, cells_x, rng, jitter=0.85, wrap=True, warp=None):
    """Cellules de Voronoï sur grille perturbée. Retourne (F1, F2, identifiant de cellule) en pixels.
    warp : (dy, dx) en pixels, déformation du domaine (bords de cellules sinueux au lieu de droits)."""
    off = rng.random((cells_y, cells_x, 2)) * jitter + (1 - jitter) / 2
    sy, sx = h / cells_y, w / cells_x
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    yy += 0.5
    xx += 0.5
    if warp is not None:
        yy = yy + warp[0]
        xx = xx + warp[1]
    if wrap:
        yy %= h
        xx %= w
    y = yy / sy
    x = xx / sx
    iy = np.floor(y).astype(int)
    ix = np.floor(x).astype(int)
    fy = y - iy
    fx = x - ix
    f1 = np.full((h, w), np.inf)
    f2 = np.full((h, w), np.inf)
    ident = np.zeros((h, w), dtype=int)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ny, nx = iy + dy, ix + dx
            if wrap:
                ny, nx = ny % cells_y, nx % cells_x
                valid = np.ones((h, w), dtype=bool)
            else:
                valid = (ny >= 0) & (ny < cells_y) & (nx >= 0) & (nx < cells_x)
                ny, nx = np.clip(ny, 0, cells_y - 1), np.clip(nx, 0, cells_x - 1)
            p = off[ny, nx]
            d = np.hypot((dy + p[..., 0] - fy) * sy, (dx + p[..., 1] - fx) * sx)
            d = np.where(valid, d, np.inf)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            f1 = np.where(closer, d, f1)
            ident = np.where(closer, ny * cells_x + nx, ident)
    return f1, f2, ident


def warp_field(h, w, cells, amount, rng, wrap_y=True, wrap_x=True):
    """Déformation douce (dy, dx) en pixels pour worley(warp=...)."""
    dy = (fbm(h, w, cells, 3, rng, wrap_y=wrap_y, wrap_x=wrap_x) - 0.5) * 2 * amount
    dx = (fbm(h, w, cells, 3, rng, wrap_y=wrap_y, wrap_x=wrap_x) - 0.5) * 2 * amount
    return dy, dx


def gradient(hmap, wrap=True):
    if wrap:
        gx = (np.roll(hmap, -1, 1) - np.roll(hmap, 1, 1)) * 0.5
        gy = (np.roll(hmap, -1, 0) - np.roll(hmap, 1, 0)) * 0.5
        return gx, gy
    gy, gx = np.gradient(hmap)
    return gx, gy


def lambert(hmap, strength=1.0, wrap=True):
    """Éclairage d'une carte de hauteur, relatif au sol plat : > 0 éclairé, < 0 ombré."""
    gx, gy = gradient(hmap, wrap)
    nx, ny, nz = -gx * strength, -gy * strength, np.ones_like(hmap)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    return (nx * LIGHT3[0] + ny * LIGHT3[1] + nz * LIGHT3[2]) / norm - LIGHT3[2]


def blur(a, radius=2, wrap=True):
    """Flou boîte séparable (occlusion ambiante, halos)."""
    out = a.astype(float)
    for axis in (0, 1):
        acc = np.zeros_like(out)
        for k in range(-radius, radius + 1):
            if wrap:
                acc += np.roll(out, k, axis)
            else:
                acc += _shift_clamp(out, k, axis)
        out = acc / (2 * radius + 1)
    return out


def _shift_clamp(a, k, axis):
    if k == 0:
        return a
    pad = [(0, 0), (0, 0)]
    pad[axis] = (max(k, 0), max(-k, 0))
    padded = np.pad(a, pad, mode="edge")
    sl = [slice(None), slice(None)]
    n = a.shape[axis]
    start = max(-k, 0)
    sl[axis] = slice(start, start + n)
    return padded[tuple(sl)]


def despeckle(levels, wrap=True, passes=1):
    """Supprime les pixels isolés (ton différent de ses 4 voisins), défaut typique du pixel art généré."""
    out = levels.copy()
    for _ in range(passes):
        if wrap:
            n = [np.roll(out, 1, 0), np.roll(out, -1, 0), np.roll(out, 1, 1), np.roll(out, -1, 1)]
        else:
            n = [_shift_clamp(out, 1, 0), _shift_clamp(out, -1, 0), _shift_clamp(out, 1, 1), _shift_clamp(out, -1, 1)]
        stack = np.stack(n)
        isolated = np.all(stack != out, axis=0)
        med = np.median(stack, axis=0).round().astype(out.dtype)
        out = np.where(isolated, med, out)
    return out


def bayer(h, w):
    return np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]


def colorize(levels, materials, ramps):
    """levels : ton par pixel ; materials : indice de rampe par pixel ; ramps : liste de rampes RGB."""
    h, w = levels.shape
    out = np.zeros((h, w, 3), dtype=np.uint8)
    for i, rmp in enumerate(ramps):
        sel = materials == i
        if sel.any():
            colors = np.array(rmp, dtype=np.uint8)
            out[sel] = colors[np.clip(levels[sel], 0, len(rmp) - 1)]
    return out


def stamp_disc(field, cy, cx, radius, value, mode="max", wrap=True):
    """Dôme de hauteur (caillou) ajouté dans un champ, avec répétition aux bords si wrap."""
    h, w = field.shape
    r = int(np.ceil(radius)) + 1
    ys = np.arange(int(cy) - r, int(cy) + r + 1)
    xs = np.arange(int(cx) - r, int(cx) + r + 1)
    dy = (ys + 0.5 - cy)[:, None]
    dx = (xs + 0.5 - cx)[None, :]
    d = np.sqrt(dy * dy + dx * dx) / max(radius, 0.1)
    dome = np.where(d < 1.0, np.sqrt(np.clip(1.0 - d * d, 0, 1)) * value, 0.0)
    if wrap:
        ys, xs = ys % h, xs % w
    else:
        keep_y = (ys >= 0) & (ys < h)
        keep_x = (xs >= 0) & (xs < w)
        dome = dome[keep_y][:, keep_x]
        ys, xs = ys[keep_y], xs[keep_x]
    block = field[np.ix_(ys, xs)]
    field[np.ix_(ys, xs)] = np.maximum(block, dome) if mode == "max" else block + dome
    return dome > 0, ys, xs


def stamp_ellipse(field, cy, cx, ry, rx, rot, value, flat=3.0, wrap=True):
    """Caillou à sommet plat (plateau + bord raide) : éclairé, il donne un liseré clair en haut-gauche et
    une arête sombre en bas-droite, comme un caillou dessiné à la main. Retourne (masque, ys, xs)."""
    h, w = field.shape
    r = int(np.ceil(max(rx, ry))) + 1
    ys = np.arange(int(cy) - r, int(cy) + r + 1)
    xs = np.arange(int(cx) - r, int(cx) + r + 1)
    dy = (ys + 0.5 - cy)[:, None]
    dx = (xs + 0.5 - cx)[None, :]
    c, s = np.cos(rot), np.sin(rot)
    u = (dx * c + dy * s) / max(rx, 0.3)
    v = (-dx * s + dy * c) / max(ry, 0.3)
    d = np.sqrt(u * u + v * v)
    dome = np.where(d < 1.0, np.clip((1.0 - d) * flat, 0, 1) ** 0.6 * value, 0.0)
    if wrap:
        ys, xs = ys % h, xs % w
    else:
        keep_y = (ys >= 0) & (ys < h)
        keep_x = (xs >= 0) & (xs < w)
        dome = dome[keep_y][:, keep_x]
        ys, xs = ys[keep_y], xs[keep_x]
    block = field[np.ix_(ys, xs)]
    field[np.ix_(ys, xs)] = np.maximum(block, block * 0 + dome + np.where(dome > 0, block, 0) * 0.3)
    return dome > 0, ys, xs


def drop_shadow(rgba, dx=2, dy=2, alpha=95, color=(8, 6, 16)):
    """Ombre portée vers le bas-droite (lumière haut-gauche), sous les pixels opaques."""
    a = rgba[:, :, 3] > 0
    h, w = a.shape
    sh = np.zeros_like(a)
    sh[dy:, dx:] = a[:h - dy, :w - dx]
    sh &= ~a
    rgba[sh, :3] = color
    rgba[sh, 3] = alpha
    return rgba


def outline(rgba, color, lit_color=None, only_outer=True):
    """Contour d'1 pixel autour des pixels opaques (couleur claire possible côté haut-gauche)."""
    a = rgba[:, :, 3] >= 200
    h, w = a.shape
    ring = np.zeros_like(a)
    lit = np.zeros_like(a)
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        sh = np.zeros_like(a)
        ys = slice(max(dy, 0), h + min(dy, 0))
        yd = slice(max(-dy, 0), h + min(-dy, 0))
        xs = slice(max(dx, 0), w + min(dx, 0))
        xd = slice(max(-dx, 0), w + min(-dx, 0))
        sh[ys, xs] = a[yd, xd]
        ring |= sh
        if dy > 0 or dx > 0:
            lit |= sh
    ring &= ~a
    if only_outer:
        ring &= rgba[:, :, 3] == 0
    rgba[ring, :3] = color
    rgba[ring, 3] = 255
    if lit_color is not None:
        sel = ring & lit
        rgba[sel, :3] = lit_color
    return rgba


def pack_atlas(items, width=1024, pad=2):
    """Range des images RGBA sur des étagères. items : [(nom, tableau)]. Retourne (atlas, {nom: [x, y, w, h]})."""
    order = sorted(items, key=lambda it: -it[1].shape[0])
    x = y = shelf = 0
    rects = {}
    for name, img in order:
        h, w = img.shape[:2]
        if x + w + pad > width:
            x, y, shelf = 0, y + shelf + pad, 0
        rects[name] = [x, y, w, h]
        x += w + pad
        shelf = max(shelf, h)
    height = y + shelf + pad
    height = int(2 ** np.ceil(np.log2(max(height, 16))))
    atlas = np.zeros((height, width, 4), dtype=np.uint8)
    lookup = dict(items)
    for name, (x, y, w, h) in rects.items():
        atlas[y:y + h, x:x + w] = lookup[name]
    return atlas, rects
