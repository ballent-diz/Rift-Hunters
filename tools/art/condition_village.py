#!/usr/bin/env python3
"""Conditionne l'atlas peint du village et ses UV à l'échelle physique des miniatures agrandies."""
import json
import math
import shutil
import sys
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image
from condition_painted_kit import islands, pack, project

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "draft3d/matter/village"
SLOTS = ["plaster", "wood", "roof", "cloth", "bark", "foliage", "straw", "water"]


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def limited(image, size=(160, 160), colors=6):
    return image.convert("RGB").resize(size, Image.Resampling.NEAREST).quantize(
        colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")


def main(source_path, geometry_path):
    incoming = ROOT / "assets/concepts/incoming/material.village"
    (incoming / "source").mkdir(parents=True, exist_ok=True)
    source = incoming / "source/materials.png"
    if Path(source_path).resolve() != source.resolve():
        shutil.copyfile(source_path, source)
    raw = Image.open(source).convert("RGB")
    (OUT / "atlases").mkdir(parents=True, exist_ok=True)
    (OUT / "uv").mkdir(parents=True, exist_ok=True)
    panels = {}
    for index, slot in enumerate(SLOTS):
        x, y = index % 4, index // 4
        box = (round(x * raw.width / 4) + 2, round(y * raw.height / 2) + 2,
               round((x + 1) * raw.width / 4) - 2, round((y + 1) * raw.height / 2) - 2)
        panels[slot] = limited(raw.crop(box))
    reference = Image.open(ROOT / "assets/concepts/incoming/material.painted_kit/source/templates.png")
    panels["stone"] = limited(reference.crop((reference.width // 2 + 2, reference.height // 2 + 2,
                                              reference.width - 2, reference.height - 2)))
    panels["iron"] = limited(Image.open(ROOT / "draft3d/matter/cour/textures/iron.png"))
    panels["ground"] = limited(Image.open(ROOT / "draft3d/matter/painted_kit/ground/terrain.png"), (640, 640))
    panels["soil"] = panels["ground"]
    panels["canvas"] = panels["plaster"]
    panels["wood"].resize((48, 48), Image.Resampling.NEAREST).save(OUT / "bridge.png")
    water_box = (round(raw.width * 3 / 4) + 2, round(raw.height / 2) + 2, raw.width - 2, raw.height - 2)
    limited(raw.crop(water_box), (320, 320)).save(OUT / "water.png")
    geometry = json.loads(Path(geometry_path).read_text(encoding="utf-8"))
    report = {}
    for key, part in geometry.items():
        plans, patches = {}, []
        for index, surface in enumerate(part["surfaces"]):
            slot = surface["slot"]
            points = np.array(surface["positions"])
            plans[str(index)] = {"slot": slot, "uv": [[0, 0] for _ in points]}
            for indices, normal, area in islands(points):
                vertices = [t * 3 + c for t in indices for c in range(3)]
                projected, axis = project(points[vertices], normal)
                lo, hi = projected.min(axis=0), projected.max(axis=0)
                width, height = [max(2, math.ceil(float(v) * 40)) for v in hi - lo]
                panel = panels[slot]
                if slot in ["roof", "foliage", "ground", "soil", "straw"]:
                    span = 16.0 if slot in ["ground", "soil"] else 3.0
                    u = np.floor((lo[0] + np.arange(width) / 40) / span * panel.width).astype(int) % panel.width
                    v = np.floor((lo[1] + np.arange(height) / 40) / span * panel.height).astype(int) % panel.height
                    image = Image.fromarray(np.array(panel)[v[:, None], u[None, :]])
                elif area < 0.08:
                    image = panel.crop((48, 48, 112, 112)).resize((width, height), Image.Resampling.NEAREST)
                elif slot in ["wood", "bark"] and min(hi - lo) < 0.25:
                    image = panel.crop((60, 0, 100, 160)).resize((width, height), Image.Resampling.NEAREST)
                else:
                    image = panel.resize((width, height), Image.Resampling.NEAREST)
                patches.append({"surface": str(index), "vertices": vertices, "projected": projected,
                                "lo": lo, "hi": hi, "image": image, "role": slot})
        atlas = pack(patches, atlas_width=1024, max_height=4096)
        for patch in patches:
            x, y = patch["at"]
            width, height = patch["image"].size
            unit = (patch["projected"] - patch["lo"]) / np.maximum(patch["hi"] - patch["lo"], 1e-9)
            for vertex, point in zip(patch["vertices"], unit):
                plans[patch["surface"]]["uv"][vertex] = [
                    (x + 0.5 + point[0] * (width - 1)) / atlas.width,
                    (y + 0.5 + point[1] * (height - 1)) / atlas.height]
        if atlas.getcolors(maxcolors=48) is None:
            atlas = limited(atlas, atlas.size, colors=48)
        atlas.save(OUT / "atlases" / f"{key}.png")
        save(OUT / "uv" / f"{key}.json", {"surfaces": plans, "texels_per_m": 40})
        report[key] = {"atlas": atlas.size, "islands": len(patches),
                       "roles": dict(Counter(p["role"] for p in patches))}
    save(OUT / "report.json", report)
    save(incoming / "job.json", {"visual_id": "material.village", "kind": "module_uv_templates",
         "status": "wip", "generated_with": "imagegen", "source": "source/materials.png", "grid": [4, 2],
         "slots": SLOTS, "max_atlas_colors": 48, "texels_per_m": 40,
         "references": ["material.painted_kit/source/templates.png#panel_3", "painted_kit/ground/terrain.png",
                        "cour/textures/iron.png"], "geometry_and_collisions": "unchanged"})
    print("VILLAGE_ATLASES", len(report))


if __name__ == "__main__":
    main(*sys.argv[1:3])
