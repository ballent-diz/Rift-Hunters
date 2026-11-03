#!/usr/bin/env python3
"""Reconstruit les tuiles des Cœur des marais depuis le master natif retenu, sans toucher au runtime.

python3 tools/art/finish_marsh_heart.py --work /tmp/rift-coeur-marais
Dépendances : numpy, Pillow, scipy.
Les sources WebP sont sans perte ; les tuiles de présentation sont encodées en qualité 98 par défaut.
Les intermédiaires restent hors Git ; la présentation suit le redessin des régions.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

import check_map_quality as quality
import sharpness_map as sharpness

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/concepts/incoming/map.marsh_heart/source"
COMPOSITION = SOURCE.parent / "composition.png"
Image.MAX_IMAGE_PIXELS = None


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def analyse(image, out):
    gray = image.convert("L")
    scores, step = sharpness.cell_scores(gray, 2.25)
    reference = float(np.nanpercentile(scores, sharpness.REFERENCE_PERCENTILE))
    blurry = (scores < reference * sharpness.BLUR_RATIO) & ~np.isnan(scores)
    sharpness.save_outputs("environment.marsh_heart", gray, 2.25, scores, step, reference, blurry, out)
    valid = int((~np.isnan(scores)).sum())
    report = {"blurry_cells": int(blurry.sum()), "valid_cells": valid,
              "blurry_share": float(blurry.sum()) / max(valid, 1)}
    (out / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print("Netteté relative :", report, flush=True)
    return blurry, step, report



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--quality", type=int, default=98)
    args = parser.parse_args()
    assert 1 <= args.quality <= 100
    work = args.work.resolve()
    assert not work.is_relative_to(ROOT), "Les intermédiaires restent hors dépôt."
    work.mkdir(parents=True, exist_ok=True)
    provenance = json.loads((SOURCE / "regions_provenance.json").read_text())
    assert digest(COMPOSITION) == provenance["composition_sha256"], "Le plan validé a changé."
    path = SOURCE / provenance["retained_source"]
    assert digest(path) == provenance["retained_sha256"], "Le master retenu a changé."
    full = Image.open(path).convert("RGB")
    assert full.size == (2508, 3762), "Dimensions natives inattendues."
    full = full.resize((7524, 11286), Image.Resampling.LANCZOS)
    folder = ROOT / "assets/environments/marsh_heart"
    folder.mkdir(parents=True, exist_ok=True)
    paths = [folder / name for name in ("map.webp", "map_1.webp")]

    def encode(i):
        tile = full.crop((i * 3762, 0, (i + 1) * 3762, 11286))
        tile.save(paths[i], quality=args.quality, method=6)
        return paths[i].stat().st_size

    with ThreadPoolExecutor(max_workers=2) as executor:
        weights = list(executor.map(encode, range(2)))
    preview = ROOT / "docs/previews/marsh-heart"
    decoded = Image.new("RGB", full.size)
    for i, path in enumerate(paths):
        decoded.paste(Image.open(path).convert("RGB"), (i * 3762, 0))
    _, _, after = analyse(decoded, work / "sharpness-after")
    report = quality.check(paths, 3344, 5016, COMPOSITION)
    (preview / "qualite.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    recipe = {"world": [3344, 5016], "native_density": 0.75, "presentation_density": 2.25,
              "presentation": "Lanczos ×3 après redessin des régions ; aucune texture procédurale",
              "tile_encoding": {"format": "WebP", "quality": args.quality, "method": 6, "lossless": False},
              "tile_bytes": weights, "relative_sharpness_diagnostic": after,
              "tiles_sha256": {p.name: digest(p) for p in paths}}
    (SOURCE / "detail_recipe.json").write_text(json.dumps(recipe, ensure_ascii=False, indent=2) + "\n")
    assert report["ok"], "La carte reste NON CONFORME."


if __name__ == "__main__":
    main()
