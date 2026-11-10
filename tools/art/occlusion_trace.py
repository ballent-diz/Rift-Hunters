#!/usr/bin/env python3
"""Première passe de détourage pour l'éditeur de masquage (docs/maps/MASQUAGE_PAR_LE_DECOR.md).

On donne, pour chaque obstacle, un contour GROSSIER tracé à la main autour de sa partie visible (pixels de la carte
entière, tuiles côte à côte) et sa ligne de pied. L'outil affine le contour par la couleur : le sol est appris sur
une couronne de pixels juste autour du contour, et l'herbe est rognée sur une bande étroite le long du bord du contour
(l'intérieur est toujours gardé : tracer le contour au plus près, l'outil corrige les débords de quelques pixels). Les collisions ne servent à rien ici : elles ne donnent pas la silhouette.

Le résultat s'écrit au format de l'éditeur (occlusion.json + masks/) ; l'éditeur le recharge, et
  godot --headless --path . res://tools/art/occlusion_editor.tscn -- --arena=<arène> --save
recalcule depth.png. Tout se corrige ensuite à la main dans l'éditeur.

Usage : python3 tools/art/occlusion_trace.py <fichier de contours .json> [--preview <dossier>]

Fichier de contours :
{
  "environment": "environment.storm_highlands",
  "elements": [
    {"id": "pillar_01", "category": "pillar", "outline": [[x, y], ...], "foot": [[x1, y1], [x2, y2]],
     "mode": "refine" | "exact", "tolerance": 1.0, "grow": 10, "shift": [dx, dy],
     "clip_x": [x0, x1]}
  ]
}
« exact » garde le contour tel quel (déjà précis) ; « refine » (défaut) l'affine par la couleur.
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

Image.MAX_IMAGE_PIXELS = None
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TARGET_CELL_UNITS = 2.0
RING = 28
## Bande du bord du contour où l'herbe est rognée (pixels de la carte) ; l'intérieur est toujours gardé.
EDGE = 16
## Marge ajoutée autour du contour avant rognage (pixels de la carte).
GROW = 10


def res_path(path):
    return os.path.join(ROOT, path.replace("res://", ""))


class MapImage:
    def __init__(self, entry):
        tiles = entry.get("map_tiles") or [entry["map"]]
        self.paths = [res_path(p) for p in tiles]
        self.tw, self.th = Image.open(self.paths[0]).size
        self.size = (self.tw * len(self.paths), self.th)
        self._cache = {}

    def _tile(self, i):
        if i not in self._cache:
            self._cache[i] = Image.open(self.paths[i]).convert("RGB")
        return self._cache[i]

    def crop(self, x0, y0, x1, y1):
        out = Image.new("RGB", (x1 - x0, y1 - y0))
        for i in range(len(self.paths)):
            a, b = max(x0, i * self.tw), min(x1, (i + 1) * self.tw)
            if a < b:
                out.paste(self._tile(i).crop((a - i * self.tw, y0, b - i * self.tw, y1)), (a - x0, 0))
        return out


def to_lab(rgb):
    """Couleurs RVB (0-255) → Lab approché (distances proches de la perception)."""
    c = rgb.astype(np.float32) / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]], np.float32)
    xyz = c @ m.T / np.array([0.9505, 1.0, 1.089], np.float32)
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16.0 / 116.0)
    return np.stack([116.0 * f[..., 1] - 16.0, 500.0 * (f[..., 0] - f[..., 1]), 200.0 * (f[..., 1] - f[..., 2])], -1)


def kmeans(points, k, steps=12, seed=3):
    rng = np.random.default_rng(seed)
    centers = points[rng.choice(len(points), size=min(k, len(points)), replace=False)]
    for _ in range(steps):
        d = ((points[:, None, :] - centers[None, :, :]) ** 2).sum(-1)
        near = d.argmin(1)
        for j in range(len(centers)):
            sel = points[near == j]
            if len(sel):
                centers[j] = sel.mean(0)
    return centers


def refine(image, inside, tolerance):
    """Pixels du contour qui ne ressemblent pas au sol appris sur la couronne extérieure."""
    lab = to_lab(np.asarray(image))
    ring = ndimage.binary_dilation(inside, iterations=RING) & ~ndimage.binary_dilation(inside, iterations=4)
    ground = lab[ring]
    if len(ground) < 50:
        return inside
    if len(ground) > 6000:
        ground = ground[np.random.default_rng(1).choice(len(ground), 6000, replace=False)]
    centers = kmeans(ground, 6)
    # Rayon de chaque teinte du sol : 90e centile des distances de la couronne à leur centre le plus proche.
    d_ring = np.sqrt(((ground[:, None, :] - centers[None]) ** 2).sum(-1))
    near = d_ring.argmin(1)
    radius = np.array([np.percentile(d_ring[near == j, j], 90) if (near == j).any() else 10.0
                       for j in range(len(centers))])
    pix = lab[inside]
    d = np.sqrt(((pix[:, None, :] - centers[None]) ** 2).sum(-1))
    score = (d / (radius[None] * tolerance + 1e-3)).min(1)
    groundish = np.zeros(inside.shape, bool)
    groundish[inside] = score <= 1.0
    # Le contour fait foi : seule une bande étroite le long du bord est rognée là où l'on voit du sol.
    edge = inside & ~ndimage.binary_erosion(inside, iterations=EDGE)
    keep = inside & ~(groundish & edge)
    keep = ndimage.binary_opening(keep, iterations=2)
    keep = ndimage.binary_fill_holes(keep)
    return keep


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("spec")
    parser.add_argument("--preview", default="")
    args = parser.parse_args()
    spec = json.load(open(args.spec))
    env_id = spec["environment"]
    manifest = json.load(open(os.path.join(ROOT, "assets/asset_manifest.json")))
    entry = manifest["entries"][env_id]
    image = MapImage(entry)
    W, H = image.size
    directory = os.path.join(os.path.dirname(res_path(entry["map"])), "occlusion")
    doc_path = os.path.join(directory, "occlusion.json")
    if os.path.exists(doc_path):
        doc = json.load(open(doc_path))
        if tuple(doc["map_size"]) != (W, H):
            sys.exit("taille de carte changée : données existantes incompatibles")
    else:
        arena_size = float(entry.get("arena_size", W))
        cell = max(1, int(math.floor(TARGET_CELL_UNITS * W / arena_size + 0.5)))
        doc = {"version": 1, "environment": env_id, "map_size": [W, H], "cell": cell,
               "grid": [math.ceil(W / cell), math.ceil(H / cell)], "depth": "depth.png",
               "depth_rect": [0, 0, 1, 1], "elements": []}
    cell = doc["cell"]
    os.makedirs(os.path.join(directory, "masks"), exist_ok=True)
    open(os.path.join(directory, "masks", ".gdignore"), "a").close()
    by_id = {e["id"]: e for e in doc["elements"]}
    for item in spec["elements"]:
        dx, dy = item.get("shift", spec.get("shift", [0, 0]))
        outline = [(p[0] + dx, p[1] + dy) for p in item["outline"]]
        xs = [p[0] for p in outline]
        ys = [p[1] for p in outline]
        x0 = max(0, int(min(xs)) - RING - 8)
        y0 = max(0, int(min(ys)) - RING - 8)
        x1 = min(W, int(max(xs)) + RING + 8)
        y1 = min(H, int(max(ys)) + RING + 8)
        # Aligné sur la grille de masquage.
        x0, y0 = x0 // cell * cell, y0 // cell * cell
        x1, y1 = min(W, -(-x1 // cell) * cell), min(H, -(-y1 // cell) * cell)
        crop = image.crop(x0, y0, x1, y1)
        poly = Image.new("L", crop.size, 0)
        ImageDraw.Draw(poly).polygon([(x - x0, y - y0) for x, y in outline], fill=255)
        inside = np.asarray(poly) > 0
        if "clip_x" in item:
            # Bande verticale [x0, x1) : un même contour découpé en éléments aux lignes de pied différentes.
            cols = np.arange(x0, x1)
            inside = inside & ((cols >= item["clip_x"][0]) & (cols < item["clip_x"][1]))[None, :]
        if item.get("mode", "refine") == "exact":
            keep = inside
        else:
            # Marge autour du contour à main levée, rognée ensuite là où l'on voit du sol.
            grown = ndimage.binary_dilation(inside, iterations=int(item.get("grow", GROW)))
            keep = refine(crop, grown, float(item.get("tolerance", 1.0)))
            if "clip_x" in item:
                keep &= ((cols >= item["clip_x"][0]) & (cols < item["clip_x"][1]))[None, :]
        gw, gh = (x1 - x0) // cell, (y1 - y0) // cell
        cover = keep[: gh * cell, : gw * cell].reshape(gh, cell, gw, cell).mean((1, 3))
        cells = cover >= 0.5
        if not cells.any():
            print("vide :", item["id"])
            continue
        ys_, xs_ = np.nonzero(cells)
        a, b, c, d = xs_.min(), ys_.min(), xs_.max() + 1, ys_.max() + 1
        cells = cells[b:d, a:c]
        alpha = (cells * 255).astype(np.uint8)
        mask = np.stack([np.full_like(alpha, 255), alpha], -1)
        Image.fromarray(mask, "LA").save(os.path.join(directory, "masks", item["id"] + ".png"))
        foot = item["foot"]
        element = {
            "id": item["id"], "category": item.get("category", ""),
            "rect": [int(x0 // cell + a), int(y0 // cell + b), int(c - a), int(d - b)],
            "mask": "masks/%s.png" % item["id"], "hidden": False,
            "depth": [[round(foot[0][0] / cell, 2), round(foot[0][1] / cell, 2)],
                      [round(foot[1][0] / cell, 2), round(foot[1][1] / cell, 2)]],
        }
        by_id[item["id"]] = element
        if args.preview:
            os.makedirs(args.preview, exist_ok=True)
            view = crop.copy()
            full = np.zeros(inside.shape, bool)
            full[: gh * cell, : gw * cell] = np.repeat(np.repeat(cover >= 0.5, cell, 0), cell, 1)
            edge = full & ~ndimage.binary_erosion(full, iterations=2)
            arr = np.asarray(view).copy()
            arr[full] = (arr[full] * 0.6 + np.array([0, 255, 255]) * 0.4).astype(np.uint8)
            arr[edge] = (0, 255, 255)
            fy = [foot[0][1] - y0, foot[1][1] - y0]
            out = Image.fromarray(arr)
            ImageDraw.Draw(out).line([(foot[0][0] - x0, fy[0]), (foot[1][0] - x0, fy[1])], fill=(255, 128, 0), width=3)
            out.save(os.path.join(args.preview, item["id"] + ".jpg"), quality=85)
    doc["elements"] = sorted(by_id.values(), key=lambda e: e["id"])
    with open(doc_path, "w") as f:
        json.dump(doc, f, indent="\t", ensure_ascii=False)
        f.write("\n")
    print("%d éléments dans %s" % (len(doc["elements"]), os.path.relpath(doc_path, ROOT)))


if __name__ == "__main__":
    main()
