"""Motifs de matière, calculés dans le repère local de la pièce (ils suivent l'animation).
Chaque motif renvoie un décalage de ton (positif = plus clair)."""
import numpy as np


def _hash2(ix, iy):
    v = np.sin(ix * 127.1 + iy * 311.7) * 43758.5453
    return v - np.floor(v)


def scales(lx, ly, size=3.0):
    """Écailles en quinconce : reflet sur le haut de chaque écaille, ombre en bas."""
    row = np.floor(ly / size)
    offset = (row % 2) * size * 0.5
    cx = (np.floor((lx + offset) / size) + 0.5) * size - offset
    cy = (row + 0.5) * size
    dy = (ly - cy) / size
    dist = np.hypot((lx - cx) / size, dy)
    return np.where(dist > 0.48, -1.0, np.where(dy < -0.15, 0.6, 0.0))


def plates(lx, ly, size=6.0, depth=1.6):
    """Plaques fissurées (Voronoï) : fissures sombres entre les plaques, plaques légèrement bombées."""
    cx, cy = np.floor(lx / size), np.floor(ly / size)
    best = np.full(lx.shape, 1e9)
    second = np.full(lx.shape, 1e9)
    for ox in (-1, 0, 1):
        for oy in (-1, 0, 1):
            gx, gy = cx + ox, cy + oy
            px = (gx + 0.2 + 0.6 * _hash2(gx, gy)) * size
            py = (gy + 0.2 + 0.6 * _hash2(gy + 7.0, gx + 3.0)) * size
            dist = np.hypot(lx - px, ly - py)
            second = np.where(dist < best, best, np.minimum(second, dist))
            best = np.minimum(best, dist)
    crack = (second - best) < 0.7
    # Fissures discontinues : une partie des bordures reste fermée (aspect naturel, pas de « mur de briques »).
    keep = _hash2(np.floor(lx / 2.0), np.floor(ly / 2.0)) > 0.35
    return np.where(crack & keep, -depth, 0.2)


def speckle(lx, ly, amount=0.18):
    v = _hash2(np.round(lx), np.round(ly))
    return np.where(v > 1.0 - amount, 1.0, np.where(v < amount * 0.6, -1.0, 0.0))


def stripes(lx, ly, spacing=3.0, angle=0.6):
    u = lx * np.cos(angle) + ly * np.sin(angle)
    return np.where((u % spacing) < 1.0, -1.0, 0.0)


def facets(lx, ly, lit, count=5.0):
    """Facettes de cristal : tons plats par facette selon l'orientation, aspect taillé."""
    angle = np.arctan2(ly, lx)
    band = np.floor((angle + np.pi) / (2 * np.pi) * count)
    return (band % 3 - 1.0) * 0.8 + np.sign(lit) * 0.4


def apply(pattern, lx, ly, lit):
    kind = pattern[0]
    args = pattern[1:]
    if kind == "scales":
        return scales(lx, ly, *args)
    if kind == "plates":
        return plates(lx, ly, *args)
    if kind == "speckle":
        return speckle(lx, ly, *args)
    if kind == "stripes":
        return stripes(lx, ly, *args)
    if kind == "facets":
        return facets(lx, ly, lit, *args)
    return 0.0
