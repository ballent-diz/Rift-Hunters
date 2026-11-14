#!/usr/bin/env python3
"""Palette d'un chapitre pour le rendu pixel 3D (docs/art/RENDU_PIXEL_3D.md).

Tire une première palette d'une ou plusieurs captures du décor en aplats (rendu pixel sans palette :
`--pixel-palette=0`), par regroupement des couleurs (k-moyennes en OKLab), puis écrit la ressource éditable
`draft3d/render/palettes/chapter_<n>.tres` (DraftPixelPalette). Les couleurs se retouchent ensuite à la main dans
l'inspecteur de Godot ; relancer l'outil écrase le fichier.

    python3 tools/art/build_pixel_palette.py 1 capture1.png [capture2.png ...] [--colors=32] [--outline=0e0a17]
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "draft3d/render/palettes"
# Bandeaux du haut et du bas (interface) écartés des captures.
HUD_TOP = 0.11
HUD_BOTTOM = 0.08


def to_linear(c: np.ndarray) -> np.ndarray:
    return np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)


def to_srgb(c: np.ndarray) -> np.ndarray:
    c = np.clip(c, 0.0, 1.0)
    return np.where(c > 0.0031308, 1.055 * c ** (1 / 2.4) - 0.055, c * 12.92)


M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
               [0.2119034982, 0.6806995451, 0.1073969566],
               [0.0883024619, 0.2817188376, 0.6299787005]])
M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
               [1.9779984951, -2.4285922050, 0.4505937099],
               [0.0259040371, 0.7827717662, -0.8086757660]])


def oklab(rgb: np.ndarray) -> np.ndarray:
    return np.cbrt(to_linear(rgb) @ M1.T) @ M2.T


def from_oklab(lab: np.ndarray) -> np.ndarray:
    return to_srgb((lab @ np.linalg.inv(M2).T) ** 3 @ np.linalg.inv(M1).T)


def kmeans(points: np.ndarray, k: int, rounds: int = 30, seed: int = 1) -> np.ndarray:
    rng = np.random.default_rng(seed)
    # Départ k-means++ : couleurs rares mais distinctes gardées (lanternes, bannières).
    centers = [points[rng.integers(len(points))]]
    for _ in range(1, k):
        d = np.min(((points[:, None, :] - np.array(centers)[None]) ** 2).sum(-1), axis=1)
        centers.append(points[rng.choice(len(points), p=d / d.sum())])
    centers = np.array(centers)
    for _ in range(rounds):
        label = ((points[:, None, :] - centers[None]) ** 2).sum(-1).argmin(1)
        for i in range(k):
            members = points[label == i]
            if len(members):
                centers[i] = members.mean(0)
    return centers


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if len(args) < 2:
        sys.exit(__doc__)
    chapter = int(args[0])
    count = int(opts.get("colors", "32"))
    outline = opts.get("outline", "0e0a17")
    pixels = []
    for name in args[1:]:
        image = np.asarray(Image.open(name).convert("RGB"), dtype=np.float64) / 255.0
        h = image.shape[0]
        pixels.append(image[int(h * HUD_TOP): int(h * (1 - HUD_BOTTOM))].reshape(-1, 3))
    data = np.concatenate(pixels)
    rng = np.random.default_rng(7)
    sample = oklab(data[rng.choice(len(data), size=min(len(data), 60000), replace=False)])
    # Teintes d'accent (feuillage, bannières, lueurs) : peu de pixels, mais elles doivent survivre. Les couleurs les
    # plus éloignées d'un premier regroupement reçoivent leurs propres places.
    accents = max(count // 4, 1)
    base = kmeans(sample, count - accents)
    distance = np.min(((sample[:, None, :] - base[None]) ** 2).sum(-1), axis=1)
    outliers = sample[distance >= np.quantile(distance, 0.97)]
    centers = np.concatenate([base, kmeans(outliers, accents, seed=2)])
    centers = centers[np.argsort(centers[:, 0])]
    colors = (from_oklab(centers) * 255.0).round().clip(0, 255).astype(int)
    values = ", ".join("%.4f, %.4f, %.4f, 1" % tuple(c / 255.0) for c in colors)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / ("chapter_%d.tres" % chapter)
    r, g, b = (int(outline[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    path.write_text(
        '[gd_resource type="Resource" script_class="DraftPixelPalette" load_steps=2 format=3]\n\n'
        '[ext_resource type="Script" path="res://draft3d/render/pixel_palette.gd" id="1"]\n\n'
        "[resource]\nscript = ExtResource(\"1\")\n"
        "colors = PackedColorArray(%s)\n" % values
        + "outline = Color(%.4f, %.4f, %.4f, 1)\n" % (r, g, b),
        encoding="utf-8")
    print("%s : %d couleurs" % (path.relative_to(ROOT), len(colors)))


if __name__ == "__main__":
    main()
