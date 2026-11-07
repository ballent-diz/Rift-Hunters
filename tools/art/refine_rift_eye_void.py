#!/usr/bin/env python3
"""Réinsère le vrai redessin des volutes, avec protection des sols et des objets.

Le masque est un masque de retouche artistique, jamais une collision de jeu.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

import map_seams
from build_rift_eye import BASE, NATIVE, SOURCE, digest, write


def refine(work, gamma, sharpness):
    assert 0.5 <= gamma <= 1 and 0 <= sharpness <= 120
    assert not work.resolve().is_relative_to(BASE.resolve().parents[3])
    before_path = work / "master_before.webp"
    if not before_path.exists():
        before_path.write_bytes((SOURCE / "map_detailed.webp").read_bytes())
    before = Image.open(before_path).convert("RGB")
    specs = json.loads((work / "outputs.json").read_text(encoding="utf-8"))
    layout = json.loads((work / "regions.json").read_text(encoding="utf-8"))
    assert len(specs) == len(layout["regions"]) == 16
    canvas = np.zeros((NATIVE[1], NATIVE[0], 3), np.uint8)
    filled = np.zeros(canvas.shape[:2], bool)
    history = []
    for index, region in enumerate(layout["regions"]):
        spec = next(s for s in specs if s["name"] == region["name"])
        path = work / "regions" / (region["name"] + "_generated.png")
        image = Image.open(path).convert("RGB")
        span = spec["world_square"][2] - spec["world_square"][0]
        assert image.width == image.height and image.width / span >= .75
        box = [round(v * .75) for v in region["crop"]]
        crop = (0, 0, spec["actual_fraction"][0] * image.width, spec["actual_fraction"][1] * image.height)
        part = image.crop(crop).resize((box[2] - box[0], box[3] - box[1]), Image.Resampling.LANCZOS)
        row, col = divmod(index, 4)
        ox = round(layout["regions"][index - 1]["crop"][2] * .75) - box[0] if col else 0
        oy = round(layout["regions"][index - 4]["crop"][3] * .75) - box[1] if row else 0
        map_seams.insert(canvas, filled, np.asarray(part), box[0], box[1], ox, oy)
        history.append({"name": region["name"], "crop_world": region["crop"],
                        "generated_sha256": digest(path), "size": list(image.size),
                        "generated_density": image.width / span, "prompt": spec["prompt"]})
    assert filled.all()
    painted = Image.fromarray(canvas)
    if sharpness:
        painted = painted.filter(ImageFilter.UnsharpMask(radius=1, percent=sharpness, threshold=2))
    table = [round((value / 255) ** gamma * 255) for value in range(256)]
    painted = painted.point(table * 3)
    plan = json.loads((BASE / "plan.json").read_text(encoding="utf-8"))
    floor = Image.new("L", NATIVE)
    draw = ImageDraw.Draw(floor)
    for record in plan["zones"] + [plan["platform"]]:
        points = [(round(x / 100 * NATIVE[0]), round(y / 100 * NATIVE[1]))
                  for x, y in record["polygon_pct"]]
        draw.polygon(points, fill=255)
    for passage in plan["passages"]:
        points = [(round(x / 100 * NATIVE[0]), round(y / 100 * NATIVE[1]))
                  for x, y in passage["axis_pct"]]
        draw.line(points, fill=255, width=round(300 * .75))
    floor_mask = np.asarray(floor) > 0
    original = np.asarray(before)
    # Les matières solides existantes possèdent une composante verte plus forte que le plasma violet.
    channels = original.astype(np.float32)
    solid = channels[:, :, 1] > np.maximum(channels[:, :, 0], channels[:, :, 2]) * .6
    solid &= channels.max(axis=2) > 15
    protected = ndimage.maximum_filter(floor_mask | solid, size=15) > 0
    distance = ndimage.distance_transform_edt(~protected)
    alpha = np.clip(distance / 12, 0, 1).astype(np.float32)
    result = np.round(original * (1 - alpha[:, :, None])
                      + np.asarray(painted) * alpha[:, :, None]).astype(np.uint8)
    assert np.array_equal(result[protected], original[protected])
    assert np.array_equal(result[floor_mask], original[floor_mask])
    target = SOURCE / "map_detailed.webp"
    Image.fromarray(result).save(target, lossless=True, exact=True, method=4)
    write(SOURCE / "void_detail_refinement.json", {"date": "2026-11-07",
          "before_master_sha256": digest(before_path), "master_sha256": digest(target),
          "regions": history, "mode": "Seize redessins de vraie matière du plasma, réinsertion au vide seulement.",
          "gamma_void": gamma, "unsharp_percent_void": sharpness, "unsharp_radius_native": 1,
          "mask_recipe": "Polygones des sols et axes de passages protégés, plus matières solides G>max(R,B)×0,6 et V>15 ; dilatation15px, raccord de distance12px.",
          "protected_share": round(float(protected.mean()), 5),
          "all_floor_polygon_pixels_identical": True, "all_protected_pixels_identical": True,
          "new_noise_generated_by_code": False, "thresholds_changed": False,
          "collision_mask_created": False, "runtime_integrated": False})
    provenance_path = SOURCE / "regions_provenance.json"
    provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
    provenance["after_props_master_sha256"] = digest(before_path)
    provenance["master_sha256"] = digest(target)
    provenance["void_refinement"] = "void_detail_refinement.json"
    write(provenance_path, provenance)
    Image.fromarray(result).resize((1536, 1536), Image.Resampling.LANCZOS).save(
        work / "refined_preview.webp", quality=94, method=6)
    print("VOID_REFINEMENT_OK", gamma, sharpness, "protected", round(float(protected.mean()), 4), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--gamma", type=float, default=.85)
    parser.add_argument("--sharpness", type=int, default=80)
    args = parser.parse_args()
    refine(args.work, args.gamma, args.sharpness)
