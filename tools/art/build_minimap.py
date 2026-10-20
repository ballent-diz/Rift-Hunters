#!/usr/bin/env python3
"""Fond de la mini-carte d'une arène dessinée : la carte réduite, le décor infranchissable assombri.

  python3 tools/art/build_minimap.py environment.cascade_ruins   # une carte
  python3 tools/art/build_minimap.py all                         # toutes les cartes dessinées

Écrit assets/environments/<décor>/minimap.webp (côté le plus long : 1024 px) et la clé « minimap » de l'entrée du
manifeste. À relancer quand l'image de la carte ou ses collisions (field.png) changent.
Nécessite numpy et Pillow.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "asset_manifest.json"
LONG_SIDE = 1024
# Décor infranchissable : assombri et légèrement bleui, pour que les chemins ressortent.
BLOCKED_SHADE = 0.42
BLOCKED_TINT = np.array([10.0, 14.0, 30.0])
Image.MAX_IMAGE_PIXELS = None


def res_path(path):
    return ROOT / path.removeprefix("res://")


def build(env_id, entry):
    paths = entry.get("map_tiles") or [entry["map"]]
    tiles = [Image.open(res_path(p)).convert("RGB") for p in paths]
    tile_w, tile_h = tiles[0].size
    ratio = len(tiles) * tile_w / tile_h
    size = (LONG_SIDE, max(1, round(LONG_SIDE / ratio))) if ratio >= 1 else (max(1, round(LONG_SIDE * ratio)), LONG_SIDE)
    out = Image.new("RGB", size)
    step = size[0] / len(tiles)
    for i, tile in enumerate(tiles):
        x0, x1 = round(i * step), round((i + 1) * step)
        out.paste(tile.resize((x1 - x0, size[1]), Image.Resampling.LANCZOS), (x0, 0))
    field = Image.open(res_path(entry["field"])).convert("L").resize(size, Image.Resampling.BILINEAR)
    walk = np.asarray(field.filter(ImageFilter.GaussianBlur(0.6))).astype(float)
    blocked = np.clip((128.0 - walk) / 6.0 + 0.5, 0.0, 1.0)[..., None]
    pixels = np.asarray(out).astype(float)
    shaded = pixels * BLOCKED_SHADE + BLOCKED_TINT
    pixels = pixels * (1.0 - blocked) + shaded * blocked
    folder = res_path(entry["field"]).parent
    target = folder / "minimap.webp"
    Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).save(target, quality=88, method=6)
    entry["minimap"] = "res://" + str(target.relative_to(ROOT)).replace("\\", "/")
    print(f"{env_id} : {target.relative_to(ROOT)} ({size[0]} x {size[1]})")


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries = manifest["entries"]
    ids = [k for k, e in entries.items() if e.get("kind") == "map"] if sys.argv[1] == "all" else [sys.argv[1]]
    for env_id in ids:
        if env_id not in entries or entries[env_id].get("kind") != "map":
            sys.exit(f"{env_id} : entrée de carte dessinée introuvable")
        build(env_id, entries[env_id])
    MANIFEST.write_text(json.dumps(manifest, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
