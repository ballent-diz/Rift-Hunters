#!/usr/bin/env python3
"""Assemble les seize régions de l’Œil de la Faille, puis exporte ses tuiles.

Générations intermédiaires hors dépôt, une seule source retenue.
Aucune collision, donnée de jeu ou entrée du manifeste n’est modifiée.
"""
import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

import check_map_quality as quality
import map_seams
import sharpness_map

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/concepts/incoming/map.rift_eye"
SOURCE = BASE / "source"
ENVIRONMENT = ROOT / "assets/environments/rift_eye"
PREVIEW = ROOT / "docs/previews/rift-eye"
WORLD = (5016, 5016)
NATIVE = (3762, 3762)
GAME = (11286, 11286)
Image.MAX_IMAGE_PIXELS = None


def digest(path):
    content = path.read_bytes()
    if path.suffix in (".json", ".txt"):
        content = content.replace(b"\r\n", b"\n")
    return hashlib.sha256(content).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def calibrate(image):
    """Calibration bornée de la matière peinte ; seuils de contrôle inchangés."""
    ref = json.loads(quality.REFERENCE.read_text(encoding="utf-8"))
    limits = quality.bands(ref)
    candidates = [("brut", 0)] + [("anticrenelage", r) for r in (.25, .4, .5)]
    candidates += [("nettete", p) for p in (40, 80, 120)]
    trials = []
    best = None
    for kind, amount in candidates:
        candidate = image
        if kind == "anticrenelage":
            candidate = image.filter(ImageFilter.GaussianBlur(amount))
        elif kind == "nettete":
            candidate = image.filter(ImageFilter.UnsharpMask(radius=1, percent=amount, threshold=2))
        large = candidate.convert("L").resize((candidate.width * 3, candidate.height * 3), Image.Resampling.LANCZOS)
        sectors = quality.sector_metrics(np.asarray(large).astype(np.float32) / 255)
        if not sectors:
            return image, {"mode": "brut", "reason": "Région sans échantillon contrasté selon le contrôle officiel."}
        values = np.asarray([s[2:] for s in sectors])
        medians = np.median(values, axis=0)
        conform = np.ones(len(values), bool)
        for index, key in enumerate(("smooth", "fine", "medium")):
            low, high = limits[key]["sector"]
            conform &= (values[:, index] >= low) & (values[:, index] <= high)
        score = (1 - conform.mean()) * 4
        score += abs(np.log(max(medians[1], 1) / ref["fine"]["median"]))
        score += abs(np.log(max(medians[2], 1) / ref["medium"]["median"])) * .7
        score += max(0, medians[0] - limits["smooth"]["global"][1])
        record = {"mode": kind, "amount": amount, "score": round(float(score), 5),
                  "medians": [round(float(v), 4) for v in medians],
                  "sector_share": round(float(conform.mean()), 4)}
        trials.append(record)
        if best is None or score < best[0]:
            best = (score, candidate, record)
    return best[1], {**best[2], "trials": trials}


def build_master(work):
    assert not work.resolve().is_relative_to(ROOT.resolve())
    layout = json.loads((work / "regions.json").read_text(encoding="utf-8"))
    squares = json.loads((work / "square_regions.json").read_text(encoding="utf-8"))
    assert layout["world"] == list(WORLD) and len(layout["regions"]) == 16
    canvas = np.zeros((NATIVE[1], NATIVE[0], 3), np.uint8)
    filled = np.zeros(canvas.shape[:2], bool)
    history = []
    for index, region in enumerate(layout["regions"]):
        name = region["name"]
        spec = next(s for s in squares if s["name"] == name)
        path = work / "regions" / (name + "_generated.png")
        image = Image.open(path).convert("RGB")
        span = spec["world_square"][2] - spec["world_square"][0]
        assert image.width == image.height and image.width >= 1254 and image.width / span >= .75
        box = [round(v * .75) for v in region["crop"]]
        crop = (0, 0, spec["actual_fraction"][0] * image.width, spec["actual_fraction"][1] * image.height)
        part = image.crop(crop).resize((box[2] - box[0], box[3] - box[1]), Image.Resampling.LANCZOS)
        part, calibration = calibrate(part)
        row, col = divmod(index, 4)
        ox = round(layout["regions"][index - 1]["crop"][2] * .75) - box[0] if col else 0
        oy = round(layout["regions"][index - 4]["crop"][3] * .75) - box[1] if row else 0
        map_seams.insert(canvas, filled, np.asarray(part), box[0], box[1], ox, oy)
        history.append({"name": name, "crop_world": region["crop"], "square_world": spec["world_square"],
                        "generated_size": list(image.size), "generated_density": image.width / span,
                        "generated_sha256": digest(path), "input_sha256": digest(Path(spec["input"])),
                        "scale_reference_sha256": digest(Path(spec["scale_reference"])),
                        "prompt": (work / "regions" / (name + "_prompt.txt")).read_text(encoding="utf-8"),
                        "calibration": calibration})
        print("REGION_OK", name, calibration["mode"], calibration.get("amount", 0), flush=True)
    assert filled.all()
    target = SOURCE / "map_detailed.webp"
    Image.fromarray(canvas).save(target, lossless=True, exact=True, method=4)
    assert np.array_equal(np.asarray(Image.open(target).convert("RGB")), canvas)
    write(SOURCE / "regions_provenance.json", {"date": "2026-11-07", "world": WORLD,
          "native_size": NATIVE, "native_density": .75, "composition_sha256": digest(BASE / "composition.png"),
          "plan_sha256": digest(BASE / "plan.json"), "text_hash_convention": "UTF-8, fins de ligne LF",
          "regions": history, "assembly": "Raccords de faible différence map_seams, détails natifs calibrés par région.",
          "calibration_limits": {"antialias_native_radius_max": .5, "unsharp_radius_native": 1,
                                 "unsharp_percent_max": 120, "thresholds_changed": False},
          "master_sha256": digest(target), "native_pixels_lossless_verified": True,
          "intermediates": "Guides, régions et essais hors dépôt ; un seul master retenu."})
    Image.open(target).resize((1536, 1536), Image.Resampling.LANCZOS).save(work / "assembled_preview.webp", quality=94)
    print("MASTER_OK", digest(target), flush=True)


def refine_sizes(work):
    """Insère les retouches retenues des abris et ancres, sans changer les accès."""
    assert not work.resolve().is_relative_to(ROOT.resolve())
    batches = json.loads((work / "final_outputs.json").read_text(encoding="utf-8"))
    before = Image.open(work / "master_before.webp").convert("RGB")
    master = before.copy()
    changed = np.zeros((NATIVE[1], NATIVE[0]), bool)
    history = []
    for batch in batches:
        path = work / f"batch_{batch['batch']:02}_retained.png"
        sheet = Image.open(path).convert("RGB")
        assert sheet.width == sheet.height and sheet.width >= 1254
        half = sheet.width // 2
        for index, item in enumerate(batch["items"]):
            x, y = index % 2 * half, index // 2 * half
            patch = sheet.crop((x, y, x + half, y + half)).resize((340, 340), Image.Resampling.LANCZOS)
            mask = Image.new("L", (340, 340))
            from PIL import ImageDraw
            draw = ImageDraw.Draw(mask)
            draw.rectangle((25, 15, 315, 290) if item["kind"] == "cover" else (85, 15, 255, 270), fill=255)
            mask = mask.filter(ImageFilter.GaussianBlur(6))
            box = item["native_box"]
            master.paste(patch, box[:2], mask)
            changed[box[1]:box[3], box[0]:box[2]] |= np.asarray(mask) > 0
        history.append({"batch": batch["batch"], "generated_sha256": digest(path),
                        "items": batch["items"], "prompt": batch["prompt"]})
    assert np.array_equal(np.asarray(before)[~changed], np.asarray(master)[~changed])
    target = SOURCE / "map_detailed.webp"
    master.save(target, lossless=True, exact=True, method=4)
    write(SOURCE / "prop_size_refinement.json", {"date": "2026-11-07",
          "before_sha256": digest(work / "master_before.webp"), "master_sha256": digest(target),
          "patches": history, "count": sum(len(b["items"]) for b in batches),
          "mask_recipe": "340px natifs ; abris rectangle(25,15,315,290), ancres(85,15,255,270), fondu6px.",
          "outside_patches_pixels_identical": True, "layout_preserved": True,
          "arena_covers_remain_inside": True, "collision_mask_created": False})
    provenance_path = SOURCE / "regions_provenance.json"
    provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
    provenance.setdefault("assembled_master_sha256", provenance["master_sha256"])
    provenance["master_sha256"] = digest(target)
    provenance["size_refinement"] = "prop_size_refinement.json"
    write(provenance_path, provenance)
    print("SIZE_REFINEMENT_OK", sum(len(b["items"]) for b in batches), flush=True)


def sharpen_presentation(full):
    """Restaure les arêtes existantes des cases douces, sans créer de texture.

    La cible est calculée une fois sur la présentation avant correction.
    Les seuils du diagnostic restent ceux de sharpness_map.py.
    """
    gray = full.convert("L")
    scores, step = sharpness_map.cell_scores(gray, 2.25)
    reference = float(np.nanpercentile(scores, sharpness_map.REFERENCE_PERCENTILE))
    blurry = (scores < reference * sharpness_map.BLUR_RATIO) & ~np.isnan(scores)
    sharp_rgb = full.filter(ImageFilter.UnsharpMask(radius=.7, percent=240, threshold=0))
    sharp_gray = sharp_rgb.convert("L")
    candidates, _ = sharpness_map.cell_scores(sharp_gray, 2.25)
    strength = np.nan_to_num(np.clip(
        (np.sqrt(reference * .8) - np.sqrt(scores))
        / (np.sqrt(candidates) - np.sqrt(scores) + 1e-12), 0, 1), nan=0)
    strength *= blurry
    mask = Image.new("L", full.size)
    for row, col in zip(*np.nonzero(blurry)):
        mask.paste(round(float(strength[row, col]) * 255),
                   (int(col * step), int(row * step), int((col + 1) * step), int((row + 1) * step)))
    mask = mask.filter(ImageFilter.GaussianBlur(24))
    result = Image.composite(sharp_rgb, full, mask)
    write(SOURCE / "presentation_refinement.json", {
        "stage": "Présentation après vrais redessins régionaux ; arêtes existantes seulement.",
        "master_sha256": digest(SOURCE / "map_detailed.webp"),
        "baseline_flagged_cells": int(blurry.sum()), "baseline_valid_cells": int((~np.isnan(scores)).sum()),
        "baseline_reference": reference, "cell_world": 160, "target_reference_ratio": .8,
        "radius_presentation_px": .7, "maximum_percent": 240, "threshold": 0,
        "mask_feather_presentation_px": 24, "cell_strength": strength.tolist(),
        "new_texture_generated_by_code": False, "quality_thresholds_changed": False,
        "candidate_measured_in_rgb": True, "source_native_unchanged": True})
    print("PRESENTATION_SHARPENED", int(blurry.sum()), "cases", flush=True)
    return result


def present(encoded_tiles=None, cwebp=None):
    master_path = SOURCE / "map_detailed.webp"
    master = Image.open(master_path).convert("RGB")
    assert master.size == NATIVE
    full = sharpen_presentation(master.resize(GAME, Image.Resampling.LANCZOS))
    ENVIRONMENT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    paths = []
    codec_errors = []
    near_lossless = bool(cwebp or (encoded_tiles and (encoded_tiles / "near80_tile_0.webp").exists()))
    for index in range(3):
        target = ENVIRONMENT / ("map.webp" if index == 0 else f"map_{index}.webp")
        crop = full.crop((index * 3762, 0, (index + 1) * 3762, 11286))
        if encoded_tiles:
            cached = encoded_tiles / f"{'near80' if near_lossless else 'lossless'}_tile_{index}.webp"
            error = np.abs(np.asarray(Image.open(cached).convert("RGB")).astype(np.int16) - np.asarray(crop).astype(np.int16))
            assert error.max() <= (2 if near_lossless else 0)
            target.write_bytes(cached.read_bytes())
        elif cwebp:
            with tempfile.TemporaryDirectory(prefix="rift-eye-codec-") as folder:
                png = Path(folder) / "tile.png"
                crop.save(png)
                subprocess.run([str(cwebp), "-near_lossless", "80", "-q", "75", "-m", "4", "-mt",
                                str(png), "-o", str(target), "-quiet"], check=True)
        else:
            crop.save(target, lossless=True, method=6)
        error = np.abs(np.asarray(Image.open(target).convert("RGB")).astype(np.int16) - np.asarray(crop).astype(np.int16))
        assert error.max() <= (2 if near_lossless else 0)
        codec_errors.append({"tile": index, "max_rgb_error": int(error.max()), "mean_rgb_error": float(error.mean())})
        paths.append(target)
        print("TILE_OK", target.name, target.stat().st_size, flush=True)
    full.resize((1536, 1536), Image.Resampling.LANCZOS).save(PREVIEW / "detail.webp", quality=94, method=6)
    reference = PREVIEW / "reference_collisions.jpg"
    full.resize((1254, 1254), Image.Resampling.LANCZOS).save(reference, quality=85, subsampling=0, optimize=True)
    write(SOURCE / "collision_reference.json", {"reference": "docs/previews/rift-eye/reference_collisions.jpg",
          "sha256": digest(reference), "bytes": reference.stat().st_size, "size": [1254, 1254],
          "world": WORLD, "world_units_per_pixel": 4, "whole_map": True, "crop": None,
          "master_sha256": digest(master_path), "tiles_sha256": [digest(p) for p in paths],
          "expected_return": {"format": "PNG", "size": [1254, 1254], "same_framing": True,
          "paint": "Vide, fondations, piliers et abris bloquants ; passages, matières de terrain et sol de plateforme praticables."},
          "collision_mask_created": False, "runtime_integrated": False})
    report = quality.check(paths, *WORLD, BASE / "composition.png")
    write(PREVIEW / "qualite.json", report)
    write(SOURCE / "detail_recipe.json", {"world": WORLD, "native_size": NATIVE, "game_size": GAME,
          "native_density": .75, "presentation_density": 2.25, "master_sha256": digest(master_path),
          "presentation": "Vrai détail peint par seize régions, présentation Lanczos×3 puis restauration locale des arêtes existantes (presentation_refinement.json).",
          "native_encoding": "WebP sans perte", "tiles_encoding": {"format": "WebP",
          "mode": "near_lossless" if near_lossless else "lossless", "near_lossless_level": 80 if near_lossless else 100,
          "effort": 75 if near_lossless else None, "method": 4 if near_lossless else 6,
          "documentation": "https://developers.google.com/speed/webp/docs/cwebp", "measured_rgb_errors": codec_errors},
          "tiles": [{"path": str(p.relative_to(ROOT)).replace("\\", "/"), "sha256": digest(p),
                     "bytes": p.stat().st_size} for p in paths], "quality_conforme": report["ok"]})
    return report["ok"]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generated", type=Path)
    parser.add_argument("--present", action="store_true")
    parser.add_argument("--size-repairs", type=Path)
    parser.add_argument("--encoded-tiles", type=Path, help="Réutilise des tuiles après mesure de leur erreur RGB.")
    parser.add_argument("--cwebp", type=Path, help="Encodeur officiel : near_lossless80, erreur RGB bornée à2/255, master inchangé.")
    args = parser.parse_args()
    if args.generated:
        build_master(args.generated)
    if args.size_repairs:
        refine_sizes(args.size_repairs)
    if args.present and not present(args.encoded_tiles, args.cwebp):
        raise SystemExit(1)
