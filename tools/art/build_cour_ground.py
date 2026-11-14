#!/usr/bin/env python3
"""Conditionne le sol peint de la Cour : 640 texels / 16 m, palette existante, bords périodiques."""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

from build_cour_matter import periodic_edges, retain_source, write_json

ROOT = Path(__file__).resolve().parents[2]
COUR = ROOT / "draft3d/matter/cour"


def main(source_path):
    palette = [tuple(bytes.fromhex(c[1:])) for c in json.loads((COUR / "palette.json").read_text())["colors"]]
    indexed = Image.new("P", (1, 1))
    indexed.putpalette([v for rgb in palette for v in rgb] + list(palette[-1]) * (256 - len(palette)))
    image = Image.open(source_path).convert("RGB").resize((640, 640), Image.Resampling.NEAREST)
    image = periodic_edges(image, width=12).quantize(palette=indexed, dither=Image.Dither.NONE).convert("RGB")
    pixels = np.asarray(image)
    assert np.array_equal(pixels[0], pixels[-1]) and np.array_equal(pixels[:, 0], pixels[:, -1])
    image.save(COUR / "terrain.png")
    source = ROOT / "assets/concepts/incoming/material.cour_veilleurs"
    retain_source(source_path, source / "source/terrain.png")
    job_path = source / "job.json"
    job = json.loads(job_path.read_text(encoding="utf-8"))
    if "source/terrain.png" not in job["source"]:
        job["source"].append("source/terrain.png")
    job["ground"] = {"source": "source/terrain.png", "output": "res://draft3d/matter/cour/terrain.png",
                     "size": [640, 640], "world_span_m": 16, "texel_m": 0.025,
                     "composition": "mousse basse, humus sombre et pierre ; herbe haute en maillages séparés",
                     "vegetation_mask": "res://draft3d/matter/cour/grass_regions.json",
                     "uv": "phase continue dans le repère du niveau", "collision": "KayKit inchangée"}
    write_json(job_path, job)
    print("Sol continu : 640 x 640, palette commune, 16 m par répétition, bords raccordables.")


if __name__ == "__main__":
    main(sys.argv[1])
