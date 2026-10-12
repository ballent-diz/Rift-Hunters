"""Extraction d'éléments depuis des tilesets de packs d'assets (grille de tuiles) : découpe, isolement de l'objet
principal, assemblage « 9-slice » de zones de sol (bords et coins arrondis)."""
import numpy as np
from PIL import Image

TILE = 16


def load(path):
    return np.array(Image.open(path).convert("RGBA"))


def tiles(img, tx, ty, tw=1, th=1, tile=TILE):
    """Découpe un rectangle de tuiles (coordonnées en tuiles)."""
    return img[ty * tile:(ty + th) * tile, tx * tile:(tx + tw) * tile].copy()


def _components(alpha):
    h, w = alpha.shape
    labels = np.zeros((h, w), dtype=int)
    count = 0
    for y in range(h):
        for x in range(w):
            if alpha[y, x] and labels[y, x] == 0:
                count += 1
                labels[y, x] = count
                stack = [(y, x)]
                while stack:
                    cy, cx = stack.pop()
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and alpha[ny, nx] and labels[ny, nx] == 0:
                                labels[ny, nx] = count
                                stack.append((ny, nx))
    return labels, count


def isolate(crop):
    """Garde l'objet principal du rectangle : la plus grande zone opaque, plus les petites zones qui ne touchent
    pas le bord (morceaux détachés du même objet). Les voisins qui débordent dans le rectangle sont retirés."""
    alpha = crop[:, :, 3] > 0
    labels, count = _components(alpha)
    if count == 0:
        return crop
    sizes = [(labels == i).sum() for i in range(1, count + 1)]
    main = 1 + int(np.argmax(sizes))
    keep = labels == main
    h, w = alpha.shape
    for i in range(1, count + 1):
        if i == main:
            continue
        part = labels == i
        ys, xs = np.nonzero(part)
        if ys.min() > 0 and xs.min() > 0 and ys.max() < h - 1 and xs.max() < w - 1:
            keep |= part
    out = crop.copy()
    out[~keep] = 0
    ys, xs = np.nonzero(keep)
    return out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def nine_slice(img, origin, w, h, rng, center_variants=(), variant_chance=0.0, tile=TILE):
    """Zone de w x h tuiles (w, h >= 2) assemblée depuis un bloc 3 x 3 (coins, bords, centre) dont le coin
    haut-gauche est `origin` (en tuiles). Le centre peut varier (tuiles décorées)."""
    ox, oy = origin
    out = np.zeros((h * tile, w * tile, 4), dtype=np.uint8)
    for j in range(h):
        for i in range(w):
            cx = 0 if i == 0 else (2 if i == w - 1 else 1)
            cy = 0 if j == 0 else (2 if j == h - 1 else 1)
            src = (ox + cx, oy + cy)
            if cx == 1 and cy == 1 and center_variants and rng.random() < variant_chance:
                src = center_variants[int(rng.integers(len(center_variants)))]
            out[j * tile:(j + 1) * tile, i * tile:(i + 1) * tile] = tiles(img, *src)
    return out


def strip(img, start, middle, end, count):
    """Bande d'une tuile d'épaisseur : début, `count` milieux, fin (tuiles données en coordonnées)."""
    parts = [tiles(img, *start)] + [tiles(img, *middle) for _ in range(count)] + [tiles(img, *end)]
    horizontal = start[1] == end[1]
    return np.concatenate(parts, axis=1 if horizontal else 0)


def tile_fill(img, size_tiles, plain, variants, variant_chance, rng, tile=TILE):
    """Grande texture périodique remplie d'une tuile de base et de variantes au hasard."""
    n = size_tiles
    out = np.zeros((n * tile, n * tile, 4), dtype=np.uint8)
    base = tiles(img, *plain)
    choices = [tiles(img, *v) for v in variants]
    for j in range(n):
        for i in range(n):
            t = choices[int(rng.integers(len(choices)))] if choices and rng.random() < variant_chance else base
            out[j * tile:(j + 1) * tile, i * tile:(i + 1) * tile] = t
    return out


def recolor(img, mapping):
    """Remplace des couleurs exactes (RGB) : ex. herbe d'un autre ton pour coller au sol de l'arène."""
    out = img.copy()
    for src, dst in mapping.items():
        sel = np.all(out[:, :, :3] == np.array(src, dtype=np.uint8), axis=2)
        out[sel, :3] = dst
    return out


def fill_circles(w, h, inset=6.0):
    """Cercles de collision couvrant un rectangle arrondi (w x h pixels, centré sur l'origine) :
    une rangée de cercles le long du grand axe. Retourne [[dx, dy, r], ...]."""
    iw, ih = w - 2 * inset, h - 2 * inset
    r = min(iw, ih) / 2.0
    long_axis = iw >= ih
    length = max(iw, ih) - 2 * r
    count = max(1, int(np.ceil(length / max(r, 1.0))) + 1)
    out = []
    for k in range(count):
        t = -length / 2 + (length * k / (count - 1) if count > 1 else length / 2)
        out.append([round(t, 1), 0.0, round(r, 1)] if long_axis else [0.0, round(t, 1), round(r, 1)])
    return out
