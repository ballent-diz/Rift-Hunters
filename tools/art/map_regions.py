#!/usr/bin/env python3
"""Passe de détail d'une carte dessinée, par régions : la recette qui a produit les Ruines et les Hautes Terres.

  python3 tools/art/map_regions.py split <composition.png> --world 5016x3344 --out <dossier>
  (générer chaque région : <dossier>/regions/rY_X_input.png -> <dossier>/regions/rY_X.png, prompt PROMPT_REGION.txt,
   référence de finesse et d'échelle reference_scale.png jointe à CHAQUE génération)
  python3 tools/art/map_regions.py assemble <dossier> --out assets/environments/<décor>/map

Principe (docs/maps/QUALITE_DES_CARTES.md) : la composition validée par le propriétaire (plan figé) est découpée en
régions de 1672 × 1672 unités au plus, plus une marge de recouvrement. Chaque région est redessinée par le
générateur avec du VRAI détail, à 0,75 pixel par unité au moins (1254 pixels pour 1672 unités, comme les Hautes
Terres). L'assemblage fond les recouvrements, agrandit ×3 (2,25 pixels par unité, densité du jeu) et découpe en
tuiles verticales de même taille (map.webp, map_1.webp...). Le nombre de régions dépend seulement de la surface :
une carte 3:2 de 5016 × 3344 unités en compte 6, une carte 1:1 de 5016 × 5016 en compte 9.
Contrôle ensuite : python3 tools/art/check_map_quality.py --images <tuiles> --world WxH --composition <plan>.
Nécessite numpy et Pillow.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
# Vrai détail généré, en pixels par unité du monde (Ruines et Hautes Terres : 1254 pixels pour 1672 unités).
DETAIL_DENSITY = 0.75
# Densité affichée en jeu (tuiles livrées).
GAME_DENSITY = 2.25
REGION = 1672.0
MARGIN = 160.0
# Côté de l'image envoyée au générateur (et minimum attendu en retour).
INPUT_SIDE = 1536
MAX_TILE_PX = 16384
# Référence de finesse et d'échelle : un extrait des Ruines (vrai détail à 0,75 pixel par unité) au même zoom.
SCALE_REFERENCE = ROOT / "assets/concepts/incoming/map.three_rifts/source/map_detailed.png"
Image.MAX_IMAGE_PIXELS = None

PROMPT = """Image1 is a low-resolution crop of ONE REGION of a continuous Rift Hunters game map whose layout has been
APPROVED and FROZEN by the owner. Repaint this exact region at high definition with genuinely NEW FINE MATERIAL DETAIL,
not interpolated blurry pixels. Image2 is the strict art-quality AND SCALE reference: an extract of the Waterfall Ruins
map at the SAME ZOOM as image1. Every paving stone, grass tuft, pebble, leaf cluster, plank and masonry block in your
output must have the SAME SIZE ON SCREEN as in image2 (paving stones about 1/40 of the image width, never larger;
the hero character of the game would be about 1/30 of the image width tall). If image1 shows coarse oversized paving
or blobs, subdivide them into many small stones of image2's size; never enlarge details.
LOCK exact composition, camera, terrain outlines, path widths, water edges, cliff lines, landmark footprints and road
endpoints: overlaid on image1 your result must match it shape for shape. Do NOT add, remove or move any tree, rock,
wall, building, fence, bridge, stair or monument; do NOT narrow or widen any road, ford or clearing. Open ground stays
empty and flat: add ONLY flat fine surface texture (short grass strokes, earth grain, small paving joints and cracks).
Rebuild existing stone with many fine crisp weathered masonry blocks, foliage with tiny distinct leaf clusters and
branches, timber with fine grain and joinery, water with fine ripples and foam.
Preserve the exact silhouettes and color distribution along all four edges: this region overlaps its neighbours.
Same overhead game camera, top-left light, palette of image1. Match image2's fine graphic fantasy game finish:
precise dark accents, rich natural colors. NOT smooth plastic or cartoon forms, NOT blurry, NOT an upscale, NOT
photorealistic, NOT coarse pixels. Output full-bleed, same aspect ratio as image1, maximum resolution (at least
{min_side} pixels on the long side). No text, characters, UI, watermark, frame or border.
"""


def split(composition, world, out):
    out.mkdir(parents=True, exist_ok=True)
    (out / "regions").mkdir(exist_ok=True)
    comp = Image.open(composition).convert("RGB")
    base = comp.resize((round(world[0] * DETAIL_DENSITY), round(world[1] * DETAIL_DENSITY)), Image.Resampling.LANCZOS)
    nx, ny = math.ceil(world[0] / REGION), math.ceil(world[1] / REGION)
    core = (world[0] / nx, world[1] / ny)
    regions = []
    for y in range(ny):
        for x in range(nx):
            c = (x * core[0], y * core[1], (x + 1) * core[0], (y + 1) * core[1])
            r = (max(0.0, c[0] - MARGIN), max(0.0, c[1] - MARGIN), min(world[0], c[2] + MARGIN),
                 min(world[1], c[3] + MARGIN))
            box = tuple(round(v * DETAIL_DENSITY) for v in r)
            crop = base.crop(box)
            scale = INPUT_SIDE / max(crop.size)
            crop = crop.resize((round(crop.size[0] * scale), round(crop.size[1] * scale)), Image.Resampling.LANCZOS)
            name = f"r{y}_{x}"
            crop.save(out / "regions" / f"{name}_input.png")
            regions.append({"name": name, "core": [round(v, 1) for v in c], "crop": [round(v, 1) for v in r],
                            "input_size": list(crop.size)})
    _scale_reference(out, regions[0])
    min_side = math.ceil(REGION + 2 * MARGIN) * DETAIL_DENSITY
    (out / "PROMPT_REGION.txt").write_text(PROMPT.format(min_side=round(min_side)), encoding="utf-8")
    plan = {"composition": str(composition), "world": list(world), "detail_density": DETAIL_DENSITY,
            "game_density": GAME_DENSITY, "grid": [nx, ny], "regions": regions}
    (out / "regions.json").write_text(json.dumps(plan, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{nx * ny} régions ({nx} × {ny}) de {core[0]:.0f} × {core[1]:.0f} unités + marge {MARGIN:.0f} : {out}")
    print("Générer chaque regions/<nom>_input.png en joignant reference_scale.png et PROMPT_REGION.txt ;")
    print("enregistrer le résultat sous regions/<nom>.png, puis lancer « assemble ».")


def _scale_reference(out, region):
    """Extrait des Ruines au même zoom que les régions (même nombre d'unités par pixel)."""
    ref = Image.open(SCALE_REFERENCE).convert("RGB")
    ref_density = ref.size[0] / 5016.0
    w_units = region["crop"][2] - region["crop"][0]
    h_units = region["crop"][3] - region["crop"][1]
    w, h = round(w_units * ref_density), round(h_units * ref_density)
    w, h = min(w, ref.size[0]), min(h, ref.size[1])
    crop = ref.crop((0, 0, w, h))
    scale = INPUT_SIDE / max(region["crop"][2] - region["crop"][0], region["crop"][3] - region["crop"][1]) \
        / ref_density
    crop = crop.resize((round(w * scale), round(h * scale)), Image.Resampling.LANCZOS)
    crop.save(out / "reference_scale.png")


def _weights(size, crop, core):
    """Poids de fondu : 1 au cœur de la région, décroissant vers 0 dans la marge (sauf au bord de la carte)."""
    w, h = size
    xs = np.linspace(crop[0], crop[2], w)
    ys = np.linspace(crop[1], crop[3], h)

    def ramp(v, lo_core, hi_core, lo_crop, hi_crop):
        left = np.ones_like(v) if lo_core <= lo_crop + 1e-6 else np.clip((v - lo_crop) / max(lo_core - lo_crop, 1e-6), 0, 1)
        right = np.ones_like(v) if hi_core >= hi_crop - 1e-6 else np.clip((hi_crop - v) / max(hi_crop - hi_core, 1e-6), 0, 1)
        return np.minimum(left, right) + 1e-4

    return ramp(ys, core[1], core[3], crop[1], crop[3])[:, None] * ramp(xs, core[0], core[2], crop[0], crop[2])[None, :]


def assemble(folder, out_prefix):
    plan = json.loads((folder / "regions.json").read_text(encoding="utf-8"))
    world = plan["world"]
    size = (round(world[0] * DETAIL_DENSITY), round(world[1] * DETAIL_DENSITY))
    acc = np.zeros((size[1], size[0], 3), np.float64)
    total = np.zeros((size[1], size[0], 1), np.float64)
    missing = []
    for region in plan["regions"]:
        path = folder / "regions" / f"{region['name']}.png"
        if not path.exists():
            missing.append(path.name)
            continue
        crop = region["crop"]
        box = [round(v * DETAIL_DENSITY) for v in crop]
        dims = (box[2] - box[0], box[3] - box[1])
        img = Image.open(path).convert("RGB")
        if max(img.size) < max(region["input_size"]) * 0.8:
            print(f"attention : {path.name} fait {img.size}, trop petit pour le détail visé")
        pixels = np.asarray(img.resize(dims, Image.Resampling.LANCZOS)).astype(np.float64)
        weight = _weights(dims, crop, region["core"])[..., None]
        acc[box[1]:box[3], box[0]:box[2]] += pixels * weight
        total[box[1]:box[3], box[0]:box[2]] += weight
    if missing:
        sys.exit("régions manquantes : " + ", ".join(missing))
    detailed = Image.fromarray(np.clip(acc / np.maximum(total, 1e-9), 0, 255).astype(np.uint8))
    detailed.save(folder / "map_detailed.png")
    game = (round(world[0] * GAME_DENSITY), round(world[1] * GAME_DENSITY))
    tiles = max(1, math.ceil(game[0] / min(MAX_TILE_PX, round(REGION * GAME_DENSITY * 3))))
    if game[1] > MAX_TILE_PX:
        sys.exit(f"carte trop haute pour une tuile ({game[1]} pixels > {MAX_TILE_PX})")
    tile_w = game[0] // tiles
    full = detailed.resize((tile_w * tiles, game[1]), Image.Resampling.LANCZOS)
    paths = []
    out_prefix.parent.mkdir(parents=True, exist_ok=True)
    for i in range(tiles):
        path = Path(f"{out_prefix}.webp" if i == 0 else f"{out_prefix}_{i}.webp")
        full.crop((i * tile_w, 0, (i + 1) * tile_w, game[1])).save(path, lossless=True, method=4)
        paths.append(path)
    rel = ["res://" + str(p.resolve().relative_to(ROOT)).replace("\\", "/") for p in paths]
    print(f"carte détaillée : {folder / 'map_detailed.png'} ({size[0]} × {size[1]})")
    print("tuiles du jeu :", ", ".join(str(p) for p in paths), f"({tile_w} × {game[1]} chacune)")
    print("manifeste :", json.dumps({"map": rel[0], "map_tiles": rel if len(rel) > 1 else [], "arena_size": world[0]}))
    print(f"contrôle : python3 tools/art/check_map_quality.py --images {' '.join(str(p) for p in paths)} "
          f"--world {world[0]}x{world[1]} --composition {plan['composition']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    s = sub.add_parser("split")
    s.add_argument("composition")
    s.add_argument("--world", required=True, help="taille du monde en unités, ex. 5016x3344")
    s.add_argument("--out", required=True)
    a = sub.add_parser("assemble")
    a.add_argument("folder")
    a.add_argument("--out", required=True, help="préfixe des tuiles, ex. assets/environments/mist_ford/map")
    args = parser.parse_args()
    if args.command == "split":
        world = tuple(int(v) for v in args.world.lower().split("x"))
        split(Path(args.composition), world, Path(args.out))
    else:
        assemble(Path(args.folder), Path(args.out))


if __name__ == "__main__":
    main()
