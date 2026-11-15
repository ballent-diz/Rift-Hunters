#!/usr/bin/env python3
"""Conditionne le sol peint retenu : nearest, palette limitée et métadonnées de matière."""
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def main(source_path):
    source = Path(source_path)
    incoming = ROOT / "assets/concepts/incoming/material.cour_ground"
    output = ROOT / "draft3d/matter/painted_kit/ground"
    (incoming / "source").mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    retained = incoming / "source/ground.png"
    if source.resolve() != retained.resolve():
        shutil.copyfile(source, retained)
    image = Image.open(retained).convert("RGB").resize((640, 640), Image.Resampling.NEAREST)
    # Les dalles occupent peu de pixels : une palette globale efface toutes leurs nuances.
    # Réserver huit tons aux pixels froids de pierre, vingt-quatre au reste, sans recolorer le dessin.
    pixels = np.array(image)
    stone = pixels[:, :, 2].astype(int) > pixels[:, :, 1].astype(int) + 3
    assert stone.any() and not stone.all()
    for mask, count in [(stone, 8), (~stone, 24)]:
        strip = Image.fromarray(pixels[mask].reshape(1, -1, 3))
        quantized = strip.quantize(colors=count, method=Image.Quantize.MEDIANCUT,
                                   dither=Image.Dither.NONE).convert("RGB")
        pixels[mask] = np.array(quantized).reshape(-1, 3)
    Image.fromarray(pixels).save(output / "terrain.png")
    job = {"visual_id": "material.cour_ground", "kind": "tileable_albedo", "status": "wip",
           "source": "source/ground.png", "generated_with": "imagegen", "native_size": [640, 640],
           "colors": 32, "tile_metres": 16, "texels_per_m": 40, "collision": "unchanged",
           "conditioning": "nearest resize, median-cut 24 vegetation + 8 stone tones, no dithering"}
    (incoming / "job.json").write_text(json.dumps(job, indent=2) + "\n", encoding="utf-8")
    print(output / "terrain.png")


if __name__ == "__main__":
    main(sys.argv[1])
