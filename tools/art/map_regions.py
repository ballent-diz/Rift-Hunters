#!/usr/bin/env python3
"""Passe de détail d'une carte dessinée, par régions : la recette qui a produit les Ruines et les Hautes Terres.

  python3 tools/art/map_regions.py scale-reference --world 5016x3344 --out ref_composition.png   # avant la composition
  python3 tools/art/map_regions.py split <composition.png> --world 5016x3344 --out <dossier>
  (générer chaque région : <dossier>/regions/rY_X_input.png -> <dossier>/regions/rY_X.png, prompt PROMPT_REGION.txt,
   référence de finesse et d'échelle reference_scale.png jointe à CHAQUE génération)
  python3 tools/art/map_regions.py assemble <dossier> --out assets/environments/<décor>/map
  python3 tools/art/map_regions.py compare --images <tuiles> --world WxH --composition <plan> --out echelle.png

Principe (docs/maps/QUALITE_DES_CARTES.md) : la composition validée par le propriétaire (plan figé) est découpée en
régions dont cœur et marges de recouvrement tiennent dans 1672 × 1672 unités. Chaque région est redessinée par le
générateur avec du VRAI détail, à 0,75 pixel par unité au moins (1254 pixels pour 1672 unités, comme les Hautes
Terres). L'assemblage fond les recouvrements, agrandit ×3 (2,25 pixels par unité, densité du jeu) et découpe en
tuiles verticales de même taille (map.webp, map_1.webp...). Le nombre de régions dépend seulement de la surface :
une carte 3:2 de 5016 × 3344 unités en compte 12, une carte 1:1 de 5016 × 5016 en compte 16.
Contrôle ensuite : python3 tools/art/check_map_quality.py --images <tuiles> --world WxH --composition <plan>.
Nécessite numpy, Pillow et scipy.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
# Vrai détail généré, en pixels par unité du monde (Ruines et Hautes Terres : 1254 pixels pour 1672 unités).
DETAIL_DENSITY = 0.75
# Densité affichée en jeu (tuiles livrées).
GAME_DENSITY = 2.25
REGION = 1672.0
# Sortie minimale d'un générateur (Hautes Terres : 1254 pixels par région). Cœur + marges d'une région tiennent dans
# REGION unités : une sortie de 1254 pixels garde alors au moins 0,75 pixel par unité.
MIN_OUTPUT = 1254
# Netteté native visée (petits détails pour 10 000 pixels, régions natives des Ruines et Hautes Terres : 379 à 395).
NATIVE_FINE = 380.0
SHARPEN_STEPS = (0, 20, 40, 60, 80, 100, 120)
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
LOCK the layout: camera, terrain outlines, path widths, water edges, cliff lines, the OUTER footprint of every forest,
rock or ruin mass, the position and footprint of every landmark (bridge, stairs, building, gate, hollow tree, altar
base) and road endpoints: overlaid on image1 your result must match it shape for shape. Do NOT narrow or widen any
road, ford or clearing, and put NOTHING on open walkable ground: it stays empty and flat, with ONLY fine surface
texture (short grass strokes, earth grain, small paving joints and cracks).
SCALE IS SET HERE: inside those locked footprints, redraw every individual object at image2's size. One oversized tree
becomes a cluster of several normal-size trees filling the same footprint; one giant rock becomes several rocks and
fine cliff blocks; one huge paving slab becomes many small cobbles; a landmark keeps its footprint but is rebuilt with
smaller, more numerous components (stones, planks, tiles, branches).
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
    core_max = REGION - 2 * MARGIN
    nx, ny = math.ceil(world[0] / core_max), math.ceil(world[1] / core_max)
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
    (out / "PROMPT_REGION.txt").write_text(PROMPT.format(min_side=MIN_OUTPUT), encoding="utf-8")
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


def scale_reference(world, width_px, out):
    """Référence d'échelle pour l'étape de COMPOSITION : les Ruines au même nombre d'unités par pixel que la future
    composition (largeur `width_px` pour `world[0]` unités). Arbres, rochers, ponts et chemins de la composition doivent
    y avoir la même taille que dans cet extrait."""
    ref = Image.open(SCALE_REFERENCE).convert("RGB")
    units_per_px = world[0] / width_px
    scale = ref.size[0] / 5016.0 * units_per_px
    small = ref.resize((round(ref.size[0] / scale), round(ref.size[1] / scale)), Image.Resampling.LANCZOS)
    w = min(small.size[0], round(width_px * 0.5))
    small.crop((0, 0, w, small.size[1])).save(out)
    print(f"référence d'échelle de composition : {out} ({w} × {small.size[1]} pixels, {units_per_px:.2f} unités/pixel)")


def compare(tiles, world, composition, out, points):
    """Contrôle visuel d'échelle : extraits de 560 × 420 unités, au même zoom (1 pixel par unité), de la carte livrée,
    de sa composition et des Ruines. Arbres, rochers, pavés et blocs doivent avoir la même taille que dans les Ruines."""
    span = (560, 420)

    def extract(paths, size, x, y):
        # Tuiles recollées côte à côte : un extrait peut chevaucher deux tuiles.
        imgs = [Image.open(p).convert("RGB") for p in paths]
        full = Image.new("RGB", (sum(i.size[0] for i in imgs), imgs[0].size[1]))
        offset = 0
        for img in imgs:
            full.paste(img, (offset, 0))
            offset += img.size[0]
        s = full.size[0] / size[0]
        box = (round(x * s), round(y * s), round((x + span[0]) * s), round((y + span[1]) * s))
        return full.crop(box).resize(span, Image.Resampling.LANCZOS)

    ruins = [ROOT / f"assets/environments/cascade_ruins/{n}" for n in ("map.webp", "map_1.webp", "map_2.webp")]
    rows = []
    for x, y in points:
        rows.append([extract(tiles, world, x, y), extract([composition], world, x, y) if composition else None,
                     extract(ruins, (5016, 1672), 1700, 1000)])
    sheet = Image.new("RGB", (3 * (span[0] + 10), len(rows) * (span[1] + 10)), (20, 20, 30))
    for r, row in enumerate(rows):
        for c, img in enumerate(row):
            if img:
                sheet.paste(img, (c * (span[0] + 10), r * (span[1] + 10)))
    sheet.save(out)
    print(f"comparaison : {out} (colonnes : carte livrée, composition, Ruines ; 1 pixel = 1 unité)")


def _fine_details(img):
    """Petits détails (≈ 1 pixel) pour 10 000 pixels, à la résolution native d'une région."""
    a = np.asarray(img.convert("L")).astype(np.float32) / 255.0
    lap = -ndimage.gaussian_laplace(a, 1.0)
    peaks = (lap == ndimage.maximum_filter(lap, size=3)) & (lap > 0.02)
    return float(peaks.sum()) / a.size * 1e4


def match_sharpness(img):
    """Netteté native calibrée : les régions natives des Ruines et des Hautes Terres ont 379 à 395 petits détails pour
    10 000 pixels. Une région plus douce (fréquent selon le générateur) reçoit le plus petit renforcement de netteté
    (masque flou, rayon 1 pixel) qui l'amène à NATIVE_FINE, plafonné à 120 % ; une région déjà nette n'est pas
    touchée. Renvoie l'image et le renforcement appliqué (%)."""
    for percent in SHARPEN_STEPS:
        out = img if percent == 0 else img.filter(ImageFilter.UnsharpMask(radius=1.0, percent=percent, threshold=2))
        if _fine_details(out) >= NATIVE_FINE or percent == SHARPEN_STEPS[-1]:
            return out, percent
    return img, 0


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
        img, percent = match_sharpness(Image.open(path).convert("RGB"))
        if percent:
            print(f"{path.name} : netteté renforcée de {percent} %")
        if max(img.size) < MIN_OUTPUT:
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
    # Tuiles verticales d'environ 1672 unités de large (3762 pixels), comme les Ruines et les Hautes Terres.
    tiles = max(1, math.ceil(world[0] / REGION))
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
    rel = [("res://" + p.resolve().relative_to(ROOT).as_posix()) if p.resolve().is_relative_to(ROOT) else str(p)
           for p in paths]
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
    r = sub.add_parser("scale-reference")
    r.add_argument("--world", required=True, help="taille du monde en unités, ex. 5016x3344")
    r.add_argument("--width", type=int, default=1536, help="largeur en pixels de la composition à générer")
    r.add_argument("--out", required=True)
    c = sub.add_parser("compare")
    c.add_argument("--images", nargs="+", required=True, help="tuiles de la carte, de gauche à droite")
    c.add_argument("--world", required=True)
    c.add_argument("--composition")
    c.add_argument("--at", nargs="+", default=[], help="coins haut gauche des extraits en unités, ex. 1200,800")
    c.add_argument("--out", required=True)
    a = sub.add_parser("assemble")
    a.add_argument("folder")
    a.add_argument("--out", required=True, help="préfixe des tuiles, ex. assets/environments/mist_ford/map")
    args = parser.parse_args()
    if args.command == "split":
        world = tuple(int(v) for v in args.world.lower().split("x"))
        split(Path(args.composition), world, Path(args.out))
    elif args.command == "compare":
        world = tuple(int(v) for v in args.world.lower().split("x"))
        points = [tuple(float(v) for v in p.split(",")) for p in args.at] or \
            [(world[0] * 0.2, world[1] * 0.3), (world[0] * 0.45, world[1] * 0.45), (world[0] * 0.7, world[1] * 0.6)]
        compare([Path(p) for p in args.images], world, args.composition, Path(args.out), points)
    elif args.command == "scale-reference":
        world = tuple(int(v) for v in args.world.lower().split("x"))
        scale_reference(world, args.width, Path(args.out))
    else:
        assemble(Path(args.folder), Path(args.out))


if __name__ == "__main__":
    main()
