#!/usr/bin/env python3
"""Retient un master natif sans perte depuis les demi-régions redessinées hors dépôt.

python3 tools/art/package_reflection_wells.py --generated <dossier contenant plan.json>
Les bandes et régions intermédiaires restent hors Git ; seul le master assemblé est retenu.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

import map_regions
import map_seams

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/concepts/incoming/map.reflection_wells/source"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generated", type=Path, required=True)
    generated = parser.parse_args().generated.resolve()
    assert not generated.is_relative_to(ROOT), "Les intermédiaires restent hors Git."
    plan = json.loads((generated / "plan.json").read_text())
    provenance = json.loads((SOURCE / "regions_provenance.json").read_text())
    assert digest(SOURCE.parent / "composition.png") == provenance["composition_sha256"]
    working = generated / "master-build"
    map_regions.split(SOURCE.parent / "composition.png", (5016, 5016), working)
    prompt_path = SOURCE / "PROMPT_DETAIL_FIN.txt"
    prompt_path.write_text((generated / "PROMPT_DETAIL.txt").read_text())
    regions = []
    for old in provenance["regions"]:
        name = old["name"]
        parts = sorted([p for p in plan if p["region"] == name], key=lambda p: p["part"])
        assert len(parts) == 2
        world_w = parts[-1]["crop_in_region_world"][2]
        world_h = parts[0]["crop_in_region_world"][3]
        images = [Image.open(generated / p["name"] / "output.png").convert("RGB") for p in parts]
        density = min(im.height / world_h for im in images)
        assert density >= 0.75, f"Détail natif insuffisant : {name}"
        size = (round(world_w * density), round(world_h * density))
        canvas = np.zeros((size[1], size[0], 3), np.uint8)
        filled = np.zeros((size[1], size[0]), bool)
        history = []
        previous_right = 0
        for p, im in zip(parts, images):
            crop = p["crop_in_region_world"]
            aspect = (crop[2] - crop[0]) / (crop[3] - crop[1])
            assert abs(im.width / im.height / aspect - 1) < 0.02, f"Cadrage inattendu : {p['name']}"
            box = [round(v * density) for v in crop]
            dims = (box[2] - box[0], box[3] - box[1])
            map_seams.insert(canvas, filled, np.asarray(im.resize(dims, Image.Resampling.LANCZOS)),
                             box[0], 0, overlap_x=max(0, previous_right - box[0]))
            previous_right = box[2]
            directory = generated / p["name"]
            history.append({"name": p["name"], "crop_in_region_world": crop, "dimensions": list(im.size),
                            "generated_original_sha256": digest(directory / "output.png"),
                            "input_sha256": digest(directory / "input.png"),
                            "reference_sha256": digest(directory / "reference_scale.png")})
        assert filled.all()
        retained = Image.fromarray(canvas)
        target = working / "regions" / f"{name}.png"
        retained.save(target)
        regions.append({"name": name, "assembled_region_sha256": digest(target), "dimensions": list(size),
                        "generated_density": density,
                        "prompt": prompt_path.name, "parts": history})
        print(name, "assemblée hors Git", size, f"{density:.3f} pixels générés/unité", flush=True)
    layout = json.loads((working / "regions.json").read_text())
    canvas = np.zeros((3762, 3762, 3), np.uint8)
    filled = np.zeros((3762, 3762), bool)
    for region in layout["regions"]:
        crop = region["crop"]
        box = [round(v * 0.75) for v in crop]
        dims = (box[2] - box[0], box[3] - box[1])
        image = Image.open(working / "regions" / f"{region['name']}.png").convert("RGB")
        image, percent = map_regions.match_sharpness(image.resize(dims, Image.Resampling.LANCZOS))
        previous = layout["regions"]
        column = int(region["name"].split("_")[1])
        row = int(region["name"].split("_")[0][1:])
        overlap_x = round(previous[row * 4 + column - 1]["crop"][2] * 0.75) - box[0] if column else 0
        overlap_y = round(previous[(row - 1) * 4 + column]["crop"][3] * 0.75) - box[1] if row else 0
        map_seams.insert(canvas, filled, np.asarray(image), box[0], box[1], overlap_x, overlap_y)
        region["native_sharpen_percent"] = percent
    assert filled.all()
    master = Image.fromarray(canvas)
    master.save(working / "map_detailed.png")
    target = SOURCE / "map_detailed.webp"
    master.save(target, lossless=True, method=6)
    assert Image.open(target).convert("RGB").tobytes() == master.tobytes(), "Perte de pixels dans le master"
    provenance.update(method="Seize régions assemblées depuis deux demi-régions redessinées chacune, "
                      "avec 128 unités de recouvrement. Master natif assemblé retenu en WebP sans perte ; "
                      "bandes et régions intermédiaires hors Git. Plan et échelle des objets figés.",
                      generated_date="2026-11-03", generated_parts=32, regions=regions,
                      retained_source=target.name, retained_sha256=digest(target),
                      retained_dimensions=list(master.size), retained_density=0.75,
                      pixels_lossless_verified=True,
                      seam_method="Chemin de différence minimale, raccord adouci sur un pixel natif")
    (SOURCE / "regions_provenance.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
