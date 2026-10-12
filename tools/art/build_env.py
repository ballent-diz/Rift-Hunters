#!/usr/bin/env python3
"""EXPÉRIMENTAL, mis de côté : décor procédural des arènes (le jeu ne l'affiche pas ; un pack d'assets est prévu).
Les briques (vide, falaise, fissures de Faille) pourront compléter le pack.

Usage : python3 tools/art/build_env.py [id ...]     ex. python3 tools/art/build_env.py fractured_plain
Chaque module de tools/art/environments/ expose SPEC.
Sorties : assets/environments/<id>/ (sol, vide, bords, atlas, environment.json) et un aperçu dans assets/concepts/previews/.
Le manifeste d'assets n'est pas modifié (le validateur ne connaît pas encore les entrées de décor).
"""
import importlib
import json
import os
import pkgutil
import sys
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import environments  # noqa: E402
from pixelforge import terrain as T  # noqa: E402

PREVIEWS = os.path.join(REPO, "assets", "concepts", "previews")
SCALE = 0.5
LAYER_ORDER = ["patch", "rift", "detail", "rubble", "prop"]


def specs():
    out = {}
    for info in pkgutil.iter_modules(environments.__path__):
        module = importlib.import_module("environments." + info.name)
        if hasattr(module, "SPEC"):
            out[module.SPEC["id"]] = module.SPEC
    return out


def save(arr, rel):
    path = os.path.join(REPO, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    mode = "RGBA" if arr.shape[2] == 4 else "RGB"
    Image.fromarray(arr, mode).save(path, optimize=True)
    return "res://" + rel


def build(spec):
    env_id = spec["id"]
    base = f"assets/environments/{env_id}/"
    rng = np.random.default_rng(spec["seed"])
    ground = spec["ground"](rng)
    void = spec["void"](rng)
    edges = {}
    edge_images = {}
    for side, fn in spec["edges"].items():
        img, inset = fn(rng)
        edge_images[side] = img
        edges[side] = {"texture": save(img, base + f"edge_{side}.png"), "inset": int(inset),
                       "thickness": int(img.shape[0] if side in ("north", "south") else img.shape[1])}
    items = spec["decals"](rng)
    to_pack = [(name, img) for name, _, _, img, _ in items]
    to_pack += [(name + "@glow", halo) for name, _, _, _, halo in items if halo is not None]
    atlas, rects = T.pack_atlas(to_pack, width=1024)
    decal_list = []
    for name, layer, weight, img, halo in items:
        entry = {"name": name, "layer": layer, "weight": weight, "rect": rects[name]}
        if halo is not None:
            entry["glow"] = rects[name + "@glow"]
        decal_list.append(entry)
    entry = {
        "status": "wip",
        "generated_by": "tools/art/build_env.py",
        "scale": SCALE,
        "ground": save(ground, base + "ground.png"),
        "void": save(void, base + "void.png"),
        "atlas": save(atlas, base + "decals.png"),
        "edges": edges,
        "decals": decal_list,
        "density": spec["density"],
        "scatter": spec["scatter"],
        "clear_radius": spec["clear_radius"],
        "ambient": spec["ambient"],
        "wall_color": spec["wall_color"],
        "void_color": spec["void_color"],
    }
    preview(env_id, ground, void, edge_images, items, spec, rng)
    return entry


def preview(env_id, ground, void, edge_images, items, spec, rng):
    """Vue simulée à l'échelle 1:1 d'un écran 1080p (1 pixel d'art = 1 pixel), bord sud visible en bas,
    plus la planche des éléments agrandie ×2."""
    W, H = 1920, 1080
    cliff_y = 820
    scene = np.zeros((H, W, 3), dtype=np.uint8)
    scene[:] = np.tile(void, (H // void.shape[0] + 1, W // void.shape[1] + 1, 1))[:H, :W]
    tiled = np.tile(ground, (H // ground.shape[0] + 1, W // ground.shape[1] + 1, 1))[:cliff_y, :W]
    scene[:cliff_y] = tiled
    img = Image.fromarray(scene, "RGB").convert("RGBA")
    area_px = W * cliff_y
    world_area = area_px * SCALE * SCALE
    by_layer = {}
    for name, layer, weight, decal, halo in items:
        by_layer.setdefault(layer, []).append((weight, decal, halo))
    halos = []
    placements = []
    # Regroupement : les détails et les objets se rassemblent en bosquets et laissent des zones dégagées.
    cluster = T.fbm(H, W, (5, 9), 3, rng, wrap_y=False, wrap_x=False)
    for layer in LAYER_ORDER:
        if layer not in by_layer or layer == "rubble":
            continue
        count = int(spec["density"].get(layer, 0) * world_area / 1e6)
        weights = np.array([w for w, _, _ in by_layer[layer]], dtype=float)
        for _ in range(count):
            k = rng.choice(len(weights), p=weights / weights.sum())
            _, decal, halo = by_layer[layer][k]
            x, y = int(rng.uniform(0, W)), int(rng.uniform(0, cliff_y - 10))
            if layer in ("detail", "prop"):
                c = cluster[y, x]
                tries = 0
                while rng.random() > 0.15 + 0.85 * c * c and tries < 20:
                    x, y = int(rng.uniform(0, W)), int(rng.uniform(0, cliff_y - 10))
                    c = cluster[y, x]
                    tries += 1
            placements.append((LAYER_ORDER.index(layer), y, x, decal, halo))
            if layer == "prop" and "rubble" in by_layer:
                for _ in range(spec["scatter"]):
                    _, rub, _ = by_layer["rubble"][int(rng.integers(len(by_layer["rubble"])))]
                    placements.append((3, y + int(rng.integers(-6, 12)), x + int(rng.integers(-30, 30)), rub, None))
    placements.sort(key=lambda p: (p[0], p[1]))
    for _, y, x, decal, halo in placements:
        tile = Image.fromarray(decal, "RGBA")
        img.alpha_composite(tile, (max(0, x - tile.width // 2), max(0, y - tile.height // 2)))
        if halo is not None:
            halos.append((x - tile.width // 2, y - tile.height // 2, halo))
    south = edge_images["south"]
    strip = Image.fromarray(np.tile(south, (1, W // south.shape[1] + 1, 1))[:, :W], "RGBA")
    img.alpha_composite(strip, (0, cliff_y - 6))
    arr = np.array(img).astype(int)
    for x, y, halo in halos:
        h, w = halo.shape[:2]
        if x < 0 or y < 0 or y + h > H or x + w > W:
            continue
        a = halo[:, :, 3:4] / 255.0
        arr[y:y + h, x:x + w, :3] = np.clip(arr[y:y + h, x:x + w, :3] + halo[:, :, :3] * a, 0, 255)
    out = Image.fromarray(arr.astype(np.uint8), "RGBA")
    os.makedirs(PREVIEWS, exist_ok=True)
    out.save(os.path.join(PREVIEWS, f"environment_{env_id}.png"))
    # Planche des éléments (×2).
    cols, cell = 8, 160
    rows = (len(items) + cols - 1) // cols
    board = Image.new("RGBA", (cols * cell, rows * cell), (26, 28, 40, 255))
    draw = ImageDraw.Draw(board)
    for i, (name, layer, _, decal, _) in enumerate(items):
        tile = Image.fromarray(decal, "RGBA")
        f = max(1, min(2, (cell - 20) // max(tile.width, tile.height)))
        tile = tile.resize((tile.width * f, tile.height * f), Image.NEAREST)
        cx, cy = (i % cols) * cell, (i // cols) * cell
        board.alpha_composite(tile, (cx + (cell - tile.width) // 2, cy + (cell - 14 - tile.height) // 2))
        draw.text((cx + 4, cy + cell - 13), f"{name} ({layer})", fill=(200, 205, 225, 255))
    board.save(os.path.join(PREVIEWS, f"environment_{env_id}_decals.png"))


def main(ids):
    for env_id, spec in specs().items():
        if ids and env_id not in ids:
            continue
        entry = build(spec)
        path = os.path.join(REPO, "assets", "environments", env_id, "environment.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(entry, f, indent="\t", ensure_ascii=False)
            f.write("\n")
        print(f"généré : {os.path.relpath(path, REPO)}")


if __name__ == "__main__":
    main(sys.argv[1:])
