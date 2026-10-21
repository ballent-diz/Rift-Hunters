#!/usr/bin/env python3
"""Carte de netteté d'une carte dessinée : repère les zones floues, où qu'elles soient.

  python3 tools/art/sharpness_map.py environment.cascade_ruins --out <dossier>   # carte de chaleur + liste des zones
  python3 tools/art/sharpness_map.py --all-final [--check]                       # toutes les cartes (run_tests.sh)

check_map_quality.py compare une carte aux cartes de référence par grands secteurs (médianes) : une carte nette en
moyenne mais floue par endroits passe. Ici, la carte est découpée en cases de CELL unités et chaque case est comparée
aux cases les plus nettes de LA MÊME carte :
  netteté = part de l'énergie dans les plus hautes fréquences (détails de 1 à 2 pixels) par rapport aux formes de 4 à 8
  pixels (spectre de la case). Un flou (agrandissement, région peinte plus lisse) coupe les hautes fréquences quel
  que soit le contenu : le rapport s'effondre. Les aplats voulus (eau calme, ciel) sont ignorés.
Une case est floue sous BLUR_RATIO fois la netteté de référence de la carte (80e centile). --check : code de sortie 1
si plus de MAX_BLURRY_SHARE des cases d'une carte sont floues.
Sorties (--out) : <id>_sharpness.png (carte réduite, cases floues en rouge, nettes en vert) et <id>_blurry.json
(cases floues en unités du monde, pour une correction ciblée). Nécessite numpy, Pillow et scipy.
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "asset_manifest.json"
DENSITY = 2.25
CELL = 160.0
MIN_CONTRAST = 0.035
BLUR_RATIO = 0.6
REFERENCE_PERCENTILE = 80
MAX_BLURRY_SHARE = 0.05
Image.MAX_IMAGE_PIXELS = None


def res_path(path):
    return ROOT / path.removeprefix("res://")


def load_map(env_id):
    entry = json.loads(MANIFEST.read_text(encoding="utf-8"))["entries"][env_id]
    tiles = [Image.open(res_path(p)).convert("L") for p in entry.get("map_tiles") or [entry["map"]]]
    width = sum(t.size[0] for t in tiles)
    image = Image.new("L", (width, tiles[0].size[1]))
    x = 0
    for t in tiles:
        image.paste(t, (x, 0))
        x += t.size[0]
    return image, width / float(entry["arena_size"])


def high_frequency_share(p):
    """Énergie au-dessus de 0,25 cycle par pixel (détails de 1 à 2 pixels) / énergie entre 0,06 et 0,12 (formes de
    4 à 8 pixels). Un flou coupe les hautes fréquences quel que soit le contenu : la part s'effondre."""
    spectrum = np.abs(np.fft.fft2((p - p.mean()) * np.outer(np.hanning(p.shape[0]), np.hanning(p.shape[1])))) ** 2
    radius = np.hypot(np.fft.fftfreq(p.shape[0])[:, None], np.fft.fftfreq(p.shape[1])[None, :])
    return float(spectrum[radius > 0.25].sum() / max(spectrum[(radius > 0.06) & (radius < 0.12)].sum(), 1e-9))


def cell_scores(image, density):
    """Grille (lignes, colonnes) de netteté ; NaN pour une case sans contraste (aplat voulu)."""
    a = np.asarray(image).astype(np.float32) / 255.0
    step = int(round(CELL * density))
    rows, cols = a.shape[0] // step, a.shape[1] // step
    scores = np.full((rows, cols), np.nan, dtype=np.float32)
    for r in range(rows):
        for c in range(cols):
            p = a[r * step:(r + 1) * step, c * step:(c + 1) * step]
            if float(ndimage.gaussian_filter(p, 3.0).std()) < MIN_CONTRAST:
                continue
            scores[r, c] = high_frequency_share(p)
    return scores, step


def analyse(env_id):
    image, density = load_map(env_id)
    scores, step = cell_scores(image, density)
    valid = scores[~np.isnan(scores)]
    reference = float(np.percentile(valid, REFERENCE_PERCENTILE))
    blurry = (scores < reference * BLUR_RATIO) & ~np.isnan(scores)
    return image, density, scores, step, reference, blurry


def save_outputs(env_id, image, density, scores, step, reference, blurry, out):
    out.mkdir(parents=True, exist_ok=True)
    name = env_id.removeprefix("environment.")
    small = 1600 / image.size[0]
    view = image.convert("RGB").resize((1600, round(image.size[1] * small)), Image.Resampling.BOX)
    overlay = Image.new("RGBA", view.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for r in range(scores.shape[0]):
        for c in range(scores.shape[1]):
            if np.isnan(scores[r, c]):
                continue
            ratio = min(scores[r, c] / reference, 1.0)
            color = (220, 40, 40, 120) if blurry[r, c] else (40, 200, 60, int(60 * ratio))
            box = [c * step * small, r * step * small, (c + 1) * step * small - 1, (r + 1) * step * small - 1]
            draw.rectangle(box, fill=color)
    Image.alpha_composite(view.convert("RGBA"), overlay).convert("RGB").save(out / f"{name}_sharpness.png")
    world_w = image.size[0] / density
    world_h = image.size[1] / density
    cells = [{"x": round(c * CELL - world_w / 2), "y": round(r * CELL - world_h / 2), "size": CELL,
              "score": round(float(scores[r, c] / reference), 3)}
             for r, c in zip(*np.nonzero(blurry))]
    (out / f"{name}_blurry.json").write_text(json.dumps(cells, indent=1), encoding="utf-8")


def final_maps():
    entries = json.loads(MANIFEST.read_text(encoding="utf-8"))["entries"]
    used = set()
    for tres in (ROOT / "data" / "arenas").glob("*.tres"):
        for line in tres.read_text(encoding="utf-8").splitlines():
            if line.startswith("environment_id"):
                used.add(line.split('&"', 1)[1].rstrip('"'))
    return sorted(k for k in used if entries.get(k, {}).get("status") == "final")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("env_id", nargs="?")
    parser.add_argument("--all-final", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    ids = final_maps() if args.all_final else [args.env_id]
    failed = False
    for env_id in ids:
        image, density, scores, step, reference, blurry = analyse(env_id)
        valid = int((~np.isnan(scores)).sum())
        share = float(blurry.sum()) / max(valid, 1)
        ok = share <= MAX_BLURRY_SHARE
        failed |= not ok
        print(f"{'OK  ' if ok else 'FLOU'} {env_id} : {int(blurry.sum())} cases floues sur {valid} ({share:.1%})")
        if args.out:
            save_outputs(env_id, image, density, scores, step, reference, blurry, args.out)
    if args.check and failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
