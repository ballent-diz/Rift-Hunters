#!/usr/bin/env python3
"""Conditionne des matières peintes et les ajuste aux faces existantes du cimetière, sans dessin ajouté."""
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
OUT = ROOT / "draft3d/matter/graveyard"
SLOTS = ["masonry", "stone", "wood", "iron", "roof", "bark", "foliage", "bone"]


def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def retain(source, name):
    incoming = ROOT / "assets/concepts/incoming/material.graveyard"
    (incoming / "source").mkdir(parents=True, exist_ok=True)
    target = incoming / "source" / name
    if Path(source).resolve() != target.resolve():
        shutil.copyfile(source, target)
    return target


def main(material_source, ground_source, geometry_path, needles_source=None):
    raw = Image.open(retain(material_source, "materials.png")).convert("RGB")
    floor = Image.open(retain(ground_source, "ground.png")).convert("RGB")
    (OUT / "atlases").mkdir(parents=True, exist_ok=True)
    (OUT / "uv").mkdir(parents=True, exist_ok=True)
    panels = {}
    for index, slot in enumerate(SLOTS):
        x, y = index % 4, index // 4
        box = (round(x * raw.width / 4) + 2, round(y * raw.height / 2) + 2,
               round((x + 1) * raw.width / 4) - 2, round((y + 1) * raw.height / 2) - 2)
        panels[slot] = raw.crop(box).resize((160, 160), Image.Resampling.NEAREST).quantize(
            colors=6, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    # Les stèles reprennent le bloc calme déjà validé dans la Cour ; leur relief fournit les inscriptions.
    reference = Image.open(ROOT / "assets/concepts/incoming/material.painted_kit/source/templates.png").convert("RGB")
    box = (round(reference.width / 2) + 2, round(reference.height / 2) + 2,
           reference.width - 2, reference.height - 2)
    panels["stone"] = reference.crop(box).resize((160, 160), Image.Resampling.NEAREST).quantize(
        colors=6, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    needles = retain(needles_source, "needles.png") if needles_source else \
        ROOT / "assets/concepts/incoming/material.graveyard/source/needles.png"
    if needles.exists():
        panels["foliage"] = Image.open(needles).convert("RGB").resize((160, 160), Image.Resampling.NEAREST).quantize(
            colors=6, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    floor.resize((640, 640), Image.Resampling.NEAREST).quantize(colors=32, method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE).convert("RGB").save(OUT / "ground.png")
    geometry = json.loads(Path(geometry_path).read_text(encoding="utf-8"))
    report = {}
    for key, part in geometry.items():
        surfaces, patches = {}, []
        for index, surface in enumerate(part["surfaces"]):
            slot = surface["slot"]
            surfaces[str(index)] = {"slot": slot}
            if slot == "preserve":
                continue
            positions = np.array(surface["positions"])
            surfaces[str(index)]["uv"] = [[0, 0] for _ in positions]
            for indices, normal, area in islands(positions):
                vertices = [triangle * 3 + corner for triangle in indices for corner in range(3)]
                projected, axis = project(positions[vertices], normal)
                lo, hi = projected.min(axis=0), projected.max(axis=0)
                width, height = [max(2, math.ceil(float(s) * 40)) for s in hi - lo]
                panel = panels[slot]
                if slot in ["stone", "masonry"] and area < 0.08:
                    image = panels["stone"].crop((48, 48, 112, 112)).resize((width, height), Image.Resampling.NEAREST)
                elif slot == "masonry" and area < 2.0:
                    # Corniches et moulures restent des blocs calmes, pas une petite grille de joints.
                    image = panels["stone"].resize((width, height), Image.Resampling.NEAREST)
                elif slot in ["masonry", "roof", "foliage"]:
                    # Période physique stable pour les grands champs de pierre/ardoise/feuillage.
                    span = 4.0 if slot == "masonry" else 3.0
                    u = np.floor((lo[0] + np.arange(width) / 40) / span * 160).astype(int) % 160
                    v = np.floor((lo[1] + np.arange(height) / 40) / span * 160).astype(int) % 160
                    image = Image.fromarray(np.array(panel)[v[:, None], u[None, :]])
                elif slot == "wood" and min(hi - lo) < 0.25:
                    image = panel.crop((60, 0, 100, 160)).resize((width, height), Image.Resampling.NEAREST)
                else:
                    # L'usure de la stèle ou du bois suit les bords de l'îlot et garde un centre calme.
                    image = panel.resize((width, height), Image.Resampling.NEAREST)
                patches.append({"surface": str(index), "vertices": vertices, "projected": projected,
                                "lo": lo, "hi": hi, "image": image, "role": slot})
        if not patches:
            save(OUT / "uv" / f"{key}.json", {"surfaces": surfaces, "texels_per_m": 40})
            continue
        atlas = pack(patches, atlas_width=1024, max_height=4096)
        for patch in patches:
            x, y = patch["at"]
            width, height = patch["image"].size
            unit = (patch["projected"] - patch["lo"]) / np.maximum(patch["hi"] - patch["lo"], 1e-9)
            for vertex, point in zip(patch["vertices"], unit):
                surfaces[patch["surface"]]["uv"][vertex] = [
                    (x + 0.5 + point[0] * (width - 1)) / atlas.width,
                    (y + 0.5 + point[1] * (height - 1)) / atlas.height]
        atlas.save(OUT / "atlases" / f"{key}.png")
        save(OUT / "uv" / f"{key}.json", {"surfaces": surfaces, "texels_per_m": 40})
        report[key] = {"islands": len(patches), "atlas": atlas.size,
                       "roles": dict(Counter(p["role"] for p in patches))}
    save(OUT / "report.json", report)
    save(ROOT / "assets/concepts/incoming/material.graveyard/job.json", {
        "visual_id": "material.graveyard", "kind": "module_uv_templates_and_ground", "status": "wip",
        "generated_with": "imagegen", "sources": ["source/materials.png", "source/ground.png", "source/needles.png"],
        "stone_reference": "assets/concepts/incoming/material.painted_kit/source/templates.png#panel_3",
        "grid": [4, 2], "slots": SLOTS, "colors_per_panel": 6, "colors_atlas_max": 48,
        "ground_colors": 32, "texels_per_m": 40, "geometry_and_collisions": "unchanged"})
    print("GRAVEYARD_ATLASES", len(report))


if __name__ == "__main__":
    main(*sys.argv[1:5])
