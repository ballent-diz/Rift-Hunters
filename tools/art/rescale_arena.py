#!/usr/bin/env python3
"""Met une carte dessinée à l'échelle du personnage : réduit (ou agrandit) son monde d'un facteur, sans régénérer
d'image.

  python3 tools/art/rescale_arena.py firefly_woods 0.8

Quand le décor d'une carte est dessiné trop gros par rapport au Chasseur (pavés, rochers, socles), réduire la taille
du monde ramène tout à la bonne proportion. L'outil met à jour, d'un seul coup :
  - les tuiles de la carte (rééchantillonnées pour rester à 2,25 pixels par unité) ;
  - le manifeste (arena_size, start, field_step : field.png garde ses pixels, chaque niveau vaut moins d'unités) ;
  - data/arenas/<id>.tres : taille, centres et barrières des zones, finale, clairières, autel et arrivées, gués,
    courants, lits de crue, failles (les rayons de gameplay, eux, ne changent pas).
Les collisions peintes (collision.png) restent valables : elles s'étendent sur l'arène, quelle que soit sa taille.
Relancer ensuite tools/art/build_minimap.py et check_map_quality.py.
Nécessite Pillow.
"""
import json
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "asset_manifest.json"
# Champs de position à l'échelle (vecteurs et rectangles en unités du monde).
FIELDS = ("size", "anchor", "exit_walls", "finale_center", "finale_walls", "finale_radii", "firefly_glades",
          "altar_point", "altar_spawn_points", "slow_zones", "currents", "flood_lanes", "rift_points")
Image.MAX_IMAGE_PIXELS = None


def res_path(path):
    return ROOT / path.removeprefix("res://")


def scale_numbers(text, factor):
    return re.sub(r"-?\d+(?:\.\d+)?", lambda m: _fmt(float(m.group(0)) * factor), text)


def _fmt(value):
    return str(int(round(value))) if abs(value - round(value)) < 1e-6 or abs(value) >= 10 else f"{value:.2f}"


def rescale_tres(arena_id, factor):
    path = ROOT / "data" / "arenas" / f"{arena_id}.tres"
    lines = path.read_text(encoding="utf-8").split("\n")
    env_id = ""
    for i, line in enumerate(lines):
        key = line.split(" = ", 1)[0]
        if key in FIELDS and " = " in line:
            value = line.split(" = ", 1)[1]
            # Seuls les nombres dans Vector2(...) / Rect2(...) changent (pas les noms de type).
            value = re.sub(r"(Vector2|Rect2)\(([^)]*)\)", lambda m: f"{m.group(1)}({scale_numbers(m.group(2), factor)})",
                           value)
            lines[i] = f"{key} = {value}"
        if key == "environment_id":
            env_id = line.split('&"', 1)[1].rstrip('"')
    path.write_text("\n".join(lines), encoding="utf-8")
    return env_id


def rescale_environment(env_id, factor):
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entry = manifest["entries"][env_id]
    paths = entry.get("map_tiles") or [entry["map"]]
    for p in paths:
        tile = Image.open(res_path(p))
        size = (round(tile.size[0] * factor), round(tile.size[1] * factor))
        tile.convert("RGB").resize(size, Image.Resampling.LANCZOS).save(res_path(p), lossless=True, method=4)
        print(f"{p} : {size[0]} x {size[1]}")
    entry["arena_size"] = round(float(entry["arena_size"]) * factor)
    entry["start"] = [round(float(v) * factor) for v in entry.get("start", [0, 0])]
    entry["field_step"] = round(float(entry.get("field_step", 1.0)) * factor, 4)
    MANIFEST.write_text(json.dumps(manifest, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{env_id} : arena_size {entry['arena_size']}, field_step {entry['field_step']}")


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    arena_id, factor = sys.argv[1], float(sys.argv[2])
    env_id = rescale_tres(arena_id, factor)
    rescale_environment(env_id, factor)


if __name__ == "__main__":
    main()
