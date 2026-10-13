#!/usr/bin/env python3
"""Arène dessinée d'un seul tenant (map générée) : copie la map, calcule les zones praticables (couleurs + retouches
de la recette), en déduit une carte de distance et écrit l'entrée « environment.<id> » du manifeste.

Usage : python3 tools/art/build_map.py fractured_plain_map
Recette : tools/art/maps/<id>.py (SPEC). Nécessite numpy, Pillow et scipy.
Sorties : assets/environments/<id>/map.png (sauf si la recette fournit une image agrandie, « display »), field.png (distance signée au bord infranchissable, FIELD_STEP unités
par niveau, 128 = bord, > 128 praticable) et un aperçu des zones dans assets/concepts/previews/.
"""
import importlib
import json
import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
MANIFEST = os.path.join(REPO, "assets", "asset_manifest.json")
PREVIEWS = os.path.join(REPO, "assets", "concepts", "previews")
# Unités du monde par niveau de gris : assez grossier pour que la pente reste lisible au fond des forêts.
FIELD_STEP = 5.0


def hue_sat_light(rgb):
    a = rgb.astype(float) / 255.0
    mx, mn = a.max(2), a.min(2)
    light = (mx + mn) / 2
    d = mx - mn
    sat = np.where(light < 0.5, d / np.maximum(mx + mn, 1e-6), d / np.maximum(2 - mx - mn, 1e-6))
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    safe = np.where(d > 1e-6, d, 1)
    hue = np.where(mx == r, ((g - b) / safe) % 6, np.where(mx == g, (b - r) / safe + 2, (r - g) / safe + 4)) * 60
    return hue, sat, light


def walkable_mask(spec, src):
    """Praticable = sol clair (herbe, terre) d'après les couleurs, retouché par les formes de la recette."""
    res = spec["field_size"]
    small = np.array(src.resize((res, res), Image.BOX).convert("RGB"))
    hue, sat, light = hue_sat_light(small)
    lo, hi = spec["walk_hue"]
    walk = (hue > lo) & (hue < hi) & (light > spec["walk_light"][0]) & (light < spec["walk_light"][1]) & (sat > spec["walk_sat"])
    walk = np.array(Image.fromarray((walk * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(spec.get("median", 5)))) > 128
    # Retouches (coordonnées en pixels de la map d'origine) : zones rendues praticables ou bloquées.
    k = res / src.width
    for kind, shapes in (("walk", spec.get("walk_shapes", [])), ("block", spec.get("block_shapes", []))):
        layer = Image.new("L", (res, res), 0)
        draw = ImageDraw.Draw(layer)
        for shape in shapes:
            if shape[0] == "ellipse":
                _, x0, y0, x1, y1 = shape
                draw.ellipse([x0 * k, y0 * k, x1 * k, y1 * k], fill=255)
            else:
                draw.polygon([(x * k, y * k) for x, y in shape[1:]], fill=255)
        painted = np.array(layer) > 128
        walk = walk | painted if kind == "walk" else walk & ~painted
    # Petites taches bloquées (fleurs, touffes) supprimées ; seule la grande zone praticable connexe est gardée
    # (pas d'îlot inaccessible où un ennemi pourrait apparaître).
    blocked, count = ndimage.label(~walk)
    sizes = ndimage.sum(np.ones_like(blocked), blocked, range(1, count + 1))
    for i, size in enumerate(sizes, start=1):
        if size < spec["min_obstacle_px"]:
            walk[blocked == i] = True
    labels, count = ndimage.label(walk)
    if count:
        sizes = ndimage.sum(np.ones_like(labels), labels, range(1, count + 1))
        walk = labels == (1 + int(np.argmax(sizes)))
    return walk


def build(spec):
    env_id = spec["id"]
    base = f"assets/environments/{env_id}/"
    src = Image.open(os.path.join(REPO, spec["source"])).convert("RGB")
    world = spec["arena_size"]
    walk = walkable_mask(spec, src)
    res = walk.shape[0]
    unit = world / res  # unités du monde par pixel de la carte de distance
    inside = ndimage.distance_transform_edt(walk) * unit
    outside = ndimage.distance_transform_edt(~walk) * unit
    signed = np.where(walk, inside, -outside)
    field = np.clip(np.round(signed / FIELD_STEP) + 128, 0, 255).astype(np.uint8)
    # Départ du joueur : point dégagé (≥ start_clearance du bord bloqué) le plus proche du centre, en unités du monde.
    yy, xx = np.mgrid[0:res, 0:res]
    score = np.where(signed >= spec.get("start_clearance", 90.0), -np.hypot(yy - res / 2, xx - res / 2), -np.inf)
    sy, sx = np.unravel_index(int(score.argmax()), score.shape)
    start = [round((sx + 0.5) * unit - world / 2), round((sy + 0.5) * unit - world / 2)]
    os.makedirs(os.path.join(REPO, base), exist_ok=True)
    # Image affichée : la version agrandie fournie par la recette (déjà dans le dossier du décor), sinon la source.
    if spec.get("display"):
        map_rel = spec["display"]
        display = Image.open(os.path.join(REPO, map_rel))
    else:
        map_rel = base + "map.png"
        display = src
        src.save(os.path.join(REPO, map_rel), optimize=True)
    Image.fromarray(field, "L").save(os.path.join(REPO, base, "field.png"))
    overlay = src.convert("RGBA")
    red = Image.new("RGBA", src.size, (255, 0, 0, 110))
    mask = Image.fromarray(((~walk) * 255).astype(np.uint8)).resize(src.size, Image.NEAREST)
    overlay = Image.composite(Image.alpha_composite(overlay, red), overlay, mask)
    os.makedirs(PREVIEWS, exist_ok=True)
    overlay.save(os.path.join(PREVIEWS, f"environment_{env_id}_zones.png"))
    print(f"profondeur max : {outside.max():.0f} (portée {127 * FIELD_STEP:.0f})")
    print(f"praticable : {walk.mean() * 100:.0f} % ; départ : {start} (dégagé sur {signed[sy, sx]:.0f})")
    return {
        "status": "wip",
        "generated_by": "tools/art/build_map.py",
        "source": spec["source"],
        "kind": "map",
        "scale": world / display.width,
        "filter": "linear" if spec.get("display") else "nearest",
        "map": "res://" + map_rel,
        "field": "res://" + base + "field.png",
        "field_unit": unit,
        "field_step": FIELD_STEP,
        "arena_size": world,
        "start": start,
        "ambient": spec["ambient"],
        "outside_tint": spec.get("outside_tint", "#00000000"),
        "decals": [],
    }


def main(ids):
    with open(MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)
    for env_id in ids:
        spec = importlib.import_module("maps." + env_id).SPEC
        manifest["entries"]["environment." + env_id] = build(spec)
        print("généré : environment." + env_id)
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent="\t", ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    main(sys.argv[1:])
