#!/usr/bin/env python3
"""Contrôle de qualité d'une carte dessinée : même finesse et même échelle de détail que les cartes de référence.

  python3 tools/art/check_map_quality.py environment.mist_ford
  python3 tools/art/check_map_quality.py environment.firefly_woods --composition <plan_validé.png> [--json rapport.json]
  python3 tools/art/check_map_quality.py --images a.webp b.webp c.webp --world 5016x3344   # avant le manifeste
  python3 tools/art/check_map_quality.py --calibrate      # recalcule la référence (Ruines + Hautes Terres)
  python3 tools/art/check_map_quality.py --all-final      # cartes « final » utilisées par une arène (tools/run_tests.sh)

La qualité est définie PAR UNITÉ DU MONDE : une carte peut avoir n'importe quelle taille, mais chaque unité doit avoir
la même densité de pixels et le même détail que les Ruines des Cascades et les Hautes Terres d'Orage.
Mesures (docs/maps/QUALITE_DES_CARTES.md) :
  1. densité : pixels de l'image par unité du monde (cible 2,25 ; un agrandissement d'image basse résolution passe ce
     test, d'où les mesures suivantes) ;
  2. par secteur de 800 × 800 unités, au zoom du jeu :
     - part lisse : proportion de pixels sans texture (un agrandissement laisse de grands aplats) ;
     - détails fins : nombre de petits détails (≈ 1 unité : brins, joints, cailloux) par 100 × 100 unités ;
     - détails moyens : nombre de détails d'environ 2 unités (pavés, touffes, feuilles) par 100 × 100 unités ;
     trop peu = flou ou détail trop gros ; trop = détail trop fin (bruit, échelle trop petite) ;
  3. dérive du plan (avec --composition) : la carte détaillée, floutée, doit se superposer à la composition validée
     (corrélation des formes ; une recomposition fait échouer ce test).
Code de sortie 1 si un critère échoue. Nécessite numpy, Pillow et scipy.
"""
import argparse
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "asset_manifest.json"
REFERENCE = Path(__file__).with_name("map_quality_reference.json")
REFERENCE_MAPS = ["environment.cascade_ruins", "environment.storm_highlands"]
DENSITY = 2.25
DENSITY_TOLERANCE = 0.03
SECTOR = 800.0
PATCH = 256
PATCHES_PER_SECTOR = 8
# Bandes acceptées autour des médianes de référence (part des secteurs qui doivent y être).
GLOBAL_TOLERANCE = 0.15
SECTOR_SHARE = 0.85
DRIFT_MIN_CORRELATION = 0.85
Image.MAX_IMAGE_PIXELS = None


def res_path(path):
    return ROOT / path.removeprefix("res://")


def entry_images(env_id):
    entry = json.loads(MANIFEST.read_text(encoding="utf-8"))["entries"][env_id]
    paths = entry.get("map_tiles") or [entry["map"]]
    return [res_path(p) for p in paths], float(entry["arena_size"])


def open_tiles(paths):
    tiles = [Image.open(p) for p in paths]
    width = sum(t.size[0] for t in tiles)
    return tiles, width, tiles[0].size[1]


def world_image(tiles, world):
    """La carte au zoom de référence (2,25 pixels par unité), en niveaux de gris : ce que le jeu affiche."""
    w, h = round(world[0] * DENSITY), round(world[1] * DENSITY)
    out = Image.new("L", (w, h))
    step = w / len(tiles)
    for i, tile in enumerate(tiles):
        x0, x1 = round(i * step), round((i + 1) * step)
        out.paste(tile.convert("L").resize((x1 - x0, h), Image.Resampling.LANCZOS), (x0, 0))
    return np.asarray(out).astype(np.float32) / 255.0


def patch_metrics(p):
    local = np.sqrt(np.maximum(ndimage.uniform_filter(p * p, 5) - ndimage.uniform_filter(p, 5) ** 2, 0.0))
    area = p.size / DENSITY / DENSITY / 10000.0
    counts = []
    for sigma in (2.0, 5.0):
        lap = -ndimage.gaussian_laplace(p, sigma) * sigma * sigma
        peaks = (lap == ndimage.maximum_filter(lap, size=int(3 * sigma))) & (lap > 0.02)
        counts.append(float(peaks.sum()) / area)
    return float((local < 0.015).mean()), counts[0], counts[1]


def sector_metrics(image, seed=7):
    """Médianes par secteur : [(x, y, part lisse, détails fins, détails moyens)] (x, y en unités, coin du secteur)."""
    rng = np.random.default_rng(seed)
    cell = int(SECTOR * DENSITY)
    out = []
    for y0 in range(0, image.shape[0] - PATCH + 1, cell):
        for x0 in range(0, image.shape[1] - PATCH + 1, cell):
            block = image[y0:y0 + cell, x0:x0 + cell]
            if block.shape[0] < PATCH or block.shape[1] < PATCH:
                continue
            values = []
            for _ in range(PATCHES_PER_SECTOR):
                y = rng.integers(0, block.shape[0] - PATCH + 1)
                x = rng.integers(0, block.shape[1] - PATCH + 1)
                p = block[y:y + PATCH, x:x + PATCH]
                if p.std() >= 0.03:
                    values.append(patch_metrics(p))
            if values:
                med = np.median(np.array(values), axis=0)
                out.append((x0 / DENSITY, y0 / DENSITY, float(med[0]), float(med[1]), float(med[2])))
    return out


def plan_correlation(image, composition_path):
    """Corrélation des formes (flou de 40 unités) entre la carte et la composition validée."""
    comp = Image.open(composition_path).convert("L")
    small = (comp.size[0], round(comp.size[0] * image.shape[0] / image.shape[1]))
    a = np.asarray(Image.fromarray((image * 255).astype(np.uint8)).resize(small, Image.Resampling.BOX)).astype(float)
    b = np.asarray(comp.resize(small, Image.Resampling.BOX)).astype(float)
    sigma = 40.0 * small[0] / (image.shape[1] / DENSITY)
    a, b = ndimage.gaussian_filter(a, sigma), ndimage.gaussian_filter(b, sigma)
    a, b = a - a.mean(), b - b.mean()
    return float((a * b).sum() / np.sqrt((a * a).sum() * (b * b).sum()))


def measure(paths, world_width, world_height=None):
    tiles, width_px, height_px = open_tiles(paths)
    world = (world_width, world_height or world_width * height_px / width_px)
    density = width_px / world[0]
    image = world_image(tiles, world)
    return {"world": [round(world[0]), round(world[1])], "density": density, "image": image,
            "sectors": sector_metrics(image)}


def calibrate():
    sectors = []
    for env_id in REFERENCE_MAPS:
        paths, size = entry_images(env_id)
        sectors += measure(paths, size)["sectors"]
        print(f"{env_id} : mesuré")
    values = np.array([s[2:] for s in sectors])
    ref = {"maps": REFERENCE_MAPS, "density": DENSITY, "sectors": len(sectors)}
    for i, key in enumerate(["smooth", "fine", "medium"]):
        ref[key] = {"median": float(np.median(values[:, i])), "p05": float(np.percentile(values[:, i], 5)),
                    "p95": float(np.percentile(values[:, i], 95))}
    REFERENCE.write_text(json.dumps(ref, indent="\t") + "\n", encoding="utf-8")
    print(json.dumps(ref, indent="\t"))


def bands(ref):
    """Bandes acceptées : globale (médiane ± 15 %) et par secteur (p05 - 15 % à p95 + 15 %)."""
    out = {}
    for key in ("smooth", "fine", "medium"):
        r = ref[key]
        out[key] = {"global": (r["median"] * (1 - GLOBAL_TOLERANCE), r["median"] * (1 + GLOBAL_TOLERANCE)),
                    "sector": (r["p05"] * (1 - GLOBAL_TOLERANCE), r["p95"] * (1 + GLOBAL_TOLERANCE))}
    # Part lisse : seule la borne haute compte (une carte plus texturée n'est pas plus floue).
    out["smooth"]["global"] = (0.0, ref["smooth"]["median"] + 0.08)
    out["smooth"]["sector"] = (0.0, ref["smooth"]["p95"] + 0.1)
    return out


def check(paths, world_width, world_height, composition):
    ref = json.loads(REFERENCE.read_text(encoding="utf-8"))
    limits = bands(ref)
    result = measure(paths, world_width, world_height)
    report = {"world": result["world"], "checks": [], "sectors_out": []}

    def add(name, value, low, high, unit=""):
        ok = low <= value <= high
        report["checks"].append({"name": name, "value": round(value, 3), "min": round(low, 3), "max": round(high, 3),
                                 "ok": ok})
        print(f"  {'OK  ' if ok else 'ÉCHEC'} {name} : {value:.3f}{unit} (attendu {low:.3f} à {high:.3f})")

    print(f"Monde {result['world'][0]} × {result['world'][1]} unités, {len(result['sectors'])} secteurs")
    add("densité (pixels par unité)", result["density"], DENSITY * (1 - DENSITY_TOLERANCE),
        DENSITY * (1 + DENSITY_TOLERANCE))
    values = np.array([s[2:] for s in result["sectors"]])
    names = {"smooth": "part lisse", "fine": "détails fins / 100×100 u", "medium": "détails moyens / 100×100 u"}
    for i, key in enumerate(["smooth", "fine", "medium"]):
        add(names[key] + " (médiane)", float(np.median(values[:, i])), *limits[key]["global"])
    inside = np.ones(len(values), dtype=bool)
    for i, key in enumerate(["smooth", "fine", "medium"]):
        low, high = limits[key]["sector"]
        inside &= (values[:, i] >= low) & (values[:, i] <= high)
    add("secteurs conformes (part)", float(inside.mean()), SECTOR_SHARE, 1.0)
    for s, ok in zip(result["sectors"], inside):
        if not ok:
            report["sectors_out"].append({"x": round(s[0]), "y": round(s[1]), "smooth": round(s[2], 3),
                                          "fine": round(s[3]), "medium": round(s[4])})
    if report["sectors_out"]:
        print("  secteurs hors norme (coin haut gauche en unités depuis le coin de la carte ; lisse / fins / moyens) :")
        for s in report["sectors_out"][:20]:
            print(f"    ({s['x']}, {s['y']}) : {s['smooth']:.2f} / {s['fine']} / {s['medium']}")
    if composition:
        add("fidélité au plan validé (corrélation)", plan_correlation(result["image"], composition),
            DRIFT_MIN_CORRELATION, 1.0)
    report["ok"] = all(c["ok"] for c in report["checks"])
    print("VERDICT :", "conforme" if report["ok"] else "NON CONFORME")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("environment", nargs="?")
    parser.add_argument("--images", nargs="+", help="tuiles côte à côte, de gauche à droite (avant le manifeste)")
    parser.add_argument("--world", help="taille du monde, ex. 5016x3344 (avec --images)")
    parser.add_argument("--composition", help="composition validée par le propriétaire (contrôle de dérive du plan)")
    parser.add_argument("--json", help="écrit le rapport dans ce fichier (fiche de livraison)")
    parser.add_argument("--calibrate", action="store_true")
    parser.add_argument("--all-final", action="store_true", help="contrôle chaque carte « final » du manifeste")
    args = parser.parse_args()
    if args.calibrate:
        calibrate()
        return 0
    if args.all_final:
        entries = json.loads(MANIFEST.read_text(encoding="utf-8"))["entries"]
        # Seulement les décors réellement utilisés par une arène (une ancienne entrée remplacée n'est pas livrée).
        used = set()
        for tres in (ROOT / "data" / "arenas").glob("*.tres"):
            match = re.search(r'^environment_id = &"([^"]+)"', tres.read_text(encoding="utf-8"), re.M)
            if match:
                used.add(match.group(1))
        failed = []
        for env_id, e in entries.items():
            if env_id in used and e.get("kind") == "map" and e.get("status") == "final":
                print(f"== {env_id}")
                paths, w = entry_images(env_id)
                if not check(paths, w, None, None)["ok"]:
                    failed.append(env_id)
        if failed:
            print("cartes non conformes :", ", ".join(failed))
        return 1 if failed else 0
    if args.images:
        if not args.world:
            parser.error("--world est obligatoire avec --images")
        w, h = (float(v) for v in args.world.lower().split("x"))
        paths, height = [Path(p) for p in args.images], h
    elif args.environment:
        paths, w = entry_images(args.environment)
        height = None
    else:
        parser.error("indiquer une entrée de carte ou --images")
    report = check(paths, w, height, args.composition)
    if args.json:
        Path(args.json).write_text(json.dumps(report, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
