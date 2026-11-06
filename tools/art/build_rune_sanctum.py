#!/usr/bin/env python3
"""Assemble les douze régions peintes du Sanctuaire des runes et reconstruit les tuiles.

--generated : dossier de dessins et registre hors dépôt, vers master natif sans perte.
--present : reconstruit les tuiles du master retenu et vérifie leur qualité.
Aucun manifeste, masque de collisions ou niveau n’est modifié.
"""
import argparse

from concurrent.futures import ThreadPoolExecutor

import hashlib

import json

from pathlib import Path

import numpy as np

from PIL import Image, ImageFilter

from scipy import ndimage

import check_map_quality as quality

import map_regions

import map_seams

import sharpness_map

from build_storm_lake import calibrate

ROOT = Path(__file__).resolve().parents[2]

BASE = ROOT / "assets/concepts/incoming/map.rune_sanctum"

SOURCE = BASE / "source"

PREVIEW = ROOT / "docs/previews/rune-sanctum"

ENVIRONMENT = ROOT / "assets/environments/rune_sanctum"

WORLD = (3344, 5016)

NATIVE = (2508, 3762)

GAME = (7524, 11286)

Image.MAX_IMAGE_PIXELS = None

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")

def build_master(generated):
    assert not generated.is_relative_to(ROOT)
    layout = json.loads((generated / "regions.json").read_text())
    squares = json.loads((generated / "squares.json").read_text())
    outputs = json.loads((generated / "outputs.json").read_text())
    assert len(outputs) == 12 and len({r["name"] for r in outputs}) == 12
    assert layout["world"] == list(WORLD)
    canvas = np.zeros((NATIVE[1], NATIVE[0], 3), np.uint8)
    filled = np.zeros(canvas.shape[:2], bool)
    history = []
    for index, region in enumerate(layout["regions"]):
        name = region["name"]
        spec = next(s for s in squares if s["name"] == name)
        record = next(r for r in outputs if r["name"] == name)
        path = generated / "regions" / (name + ".png")
        image = Image.open(path).convert("RGB")
        assert image.width == image.height and image.width / 1574 >= .75
        crop, square = region["crop"], spec["square_world"]
        box = [round(v * .75) for v in crop]
        source_box = [(crop[j] - square[j % 2]) / 1574 * image.width for j in range(4)]
        part = image.crop(source_box).resize((box[2] - box[0], box[3] - box[1]), Image.Resampling.LANCZOS)
        part, sharpening = calibrate(part)
        row, column = divmod(index, 3)
        ox = round(layout["regions"][index - 1]["crop"][2] * .75) - box[0] if column else 0
        oy = round(layout["regions"][index - 3]["crop"][3] * .75) - box[1] if row else 0
        map_seams.insert(canvas, filled, np.asarray(part), box[0], box[1], ox, oy)
        history.append({"name": name, "crop_world": crop, "square_world": square,
                        "generated_sha256": digest(path), "generated_dimensions": list(image.size),
                        "generated_density": image.width / 1574,
                        "input_sha256": digest(generated / "regions" / (name + "_input.png")),
                        "scale_reference_sha256": digest(generated / "reference_scale.png"),
                        "prompt": record["prompt"], "local_instructions": record.get("local_instructions"),
                        "initial_generation_sha256": record.get("initial_generation_sha256"),
                        "correction_prompt": record.get("correction_prompt"),
                        "sharpness": sharpening})
        print(name, sharpening, flush=True)
    assert filled.all()
    master = Image.fromarray(canvas)
    target = SOURCE / "map_detailed.webp"
    master.save(target, lossless=True, exact=True, method=6)
    assert np.array_equal(np.asarray(Image.open(target).convert("RGB")), canvas)
    write(SOURCE / "regions_provenance.json", {
        "date": "2026-11-06", "world": WORLD, "composition_sha256": digest(BASE / "composition.png"),
        "plan_sha256": digest(BASE / "plan.json"), "native_density": .75, "native_size": NATIVE,
        "retained_sha256": digest(target), "regions": history, "pixels_lossless_verified": True,
        "method": "Douze régions carrées peintes de1574u ; marges extraites, calibration native et raccord de faible différence.",
        "retained_source": "map_detailed.webp",
        "intermediates": "Guides, régions et retouches hors dépôt ; seul le master retenu est versionné."})
    master.resize((1024, 1536), Image.Resampling.LANCZOS).save(
        generated / "assembled-preview.webp", quality=94, method=6)
    print("MASTER_NATIF_OK", digest(target), flush=True)

def repair_soft_cells(image, model, work):
    """Correction locale prévue par QUALITE_DES_CARTES, sur le détail déjà peint."""
    import deblur_map
    import onnxruntime

    scores, step = sharpness_map.cell_scores(image.convert("L"), 2.25)
    reference = float(np.nanpercentile(scores, sharpness_map.REFERENCE_PERCENTILE))
    blurry = (scores < reference * sharpness_map.BLUR_RATIO) & ~np.isnan(scores)
    sharpness_map.save_outputs("environment.rune_sanctum", image.convert("L"), 2.25,
                              scores, step, reference, blurry, work / "sharpness-before-repair")
    initial = int(blurry.sum())
    if not initial:
        record = {"initial_cells": 0, "remaining_cells_frozen_reference": 0,
                  "valid_cells": int((~np.isnan(scores)).sum())}
        write(SOURCE / "sharpness_repair.json", record)
        return image, record
    assert model is not None and model.is_file(), "Fournir --model <realesr_general_x4v3_0.2.onnx>."
    options = onnxruntime.SessionOptions()
    options.intra_op_num_threads = 2
    session = onnxruntime.InferenceSession(str(model), options, providers=["CPUExecutionProvider"])
    weights = np.zeros((image.height, image.width), np.float32)
    for row, col in zip(*np.nonzero(blurry)):
        weights[row * step:(row + 1) * step, col * step:(col + 1) * step] = 1
    weights = np.clip(ndimage.gaussian_filter(weights, deblur_map.FEATHER), 0, 1)
    original = np.asarray(image)
    result = original.copy()
    inner = deblur_map.BLOCK - 2 * deblur_map.OVERLAP
    blocks = [(y, x) for y in range(0, image.height, inner) for x in range(0, image.width, inner)
              if weights[y:y + inner, x:x + inner].max() > .01]
    for index, (y, x) in enumerate(blocks):
        x0, y0 = max(0, x - deblur_map.OVERLAP), max(0, y - deblur_map.OVERLAP)
        x1 = min(image.width, x + inner + deblur_map.OVERLAP)
        y1 = min(image.height, y + inner + deblur_map.OVERLAP)
        sharp = deblur_map.sharpen_block(session, original[y0:y1, x0:x1].astype(np.uint8))
        ys = slice(y - y0, y - y0 + min(inner, image.height - y))
        xs = slice(x - x0, x - x0 + min(inner, image.width - x))
        alpha = weights[y:y + inner, x:x + inner, None]
        # Le réseau peut réinterpréter les joints du dallage. Borner son résidu
        # conserve les formes et les couleurs peintes au lieu de remplacer les pavés.
        old = original[y:y + inner, x:x + inner].astype(np.float32)
        delta = np.clip(sharp[ys, xs] - old, -6.0, 6.0)
        result[y:y + inner, x:x + inner] = np.clip(old + delta * alpha + .5, 0, 255)
        if index % 25 == 0:
            print(f"Correction locale : bloc {index + 1}/{len(blocks)}", flush=True)
    corrected = Image.fromarray(result)
    after, _ = sharpness_map.cell_scores(corrected.convert("L"), 2.25)
    remaining = (after < reference * sharpness_map.BLUR_RATIO) & ~np.isnan(after)
    record = {"method": "Real-ESRGAN x4v3, débruitage0,2 ; résidu RVB limité à6/255 pour préserver les joints et couleurs du dallage ; cases douces seulement.",
              "max_rgb_delta_before_encoding": 6,
              "unbounded_result_rejected": "Les captures révélaient des plages de pavés réinterprétés ; ce traitement n’est pas retenu.",
              "model": model.name, "model_sha256": digest(model), "initial_cells": initial,
              "initial_reference": reference, "remaining_cells_frozen_reference": int(remaining.sum()),
              "valid_cells": int((~np.isnan(scores)).sum()),
              "selected_cells_row_col": np.argwhere(blurry).tolist(), "blocks": len(blocks)}
    write(SOURCE / "sharpness_repair.json", record)
    return corrected, record

def present(work, encoding_quality, model, antialias_radius):
    provenance = json.loads((SOURCE / "regions_provenance.json").read_text())
    retained = SOURCE / "map_detailed.webp"
    assert digest(retained) == provenance["retained_sha256"]
    assert digest(BASE / "composition.png") == provenance["composition_sha256"]
    native = Image.open(retained).convert("RGB")
    assert native.size == NATIVE
    # Anticrénelage optionnel si le dessin dépasse la bande de finesse, sans modifier le master retenu.
    # Le master peint reste sans perte et les seuils du contrôle restent inchangés.
    filtered = native.filter(ImageFilter.GaussianBlur(antialias_radius)) if antialias_radius else native
    full = filtered.resize(GAME, Image.Resampling.LANCZOS)
    full, repair = repair_soft_cells(full, model, work)
    ENVIRONMENT.mkdir(parents=True, exist_ok=True)
    paths = [ENVIRONMENT / name for name in ("map.webp", "map_1.webp")]

    def encode(index):
        full.crop((index * 3762, 0, (index + 1) * 3762, 11286)).save(
            paths[index], quality=encoding_quality, method=6)
        print("TUILE", paths[index].name, paths[index].stat().st_size, flush=True)

    with ThreadPoolExecutor(max_workers=2) as executor:
        list(executor.map(encode, range(2)))
    decoded = Image.new("RGB", GAME)
    for index, path in enumerate(paths):
        decoded.paste(Image.open(path).convert("RGB"), (index * 3762, 0))
    scores, step = sharpness_map.cell_scores(decoded.convert("L"), 2.25)
    reference = float(np.nanpercentile(scores, sharpness_map.REFERENCE_PERCENTILE))
    blurry = (scores < reference * sharpness_map.BLUR_RATIO) & ~np.isnan(scores)
    if "initial_reference" in repair:
        frozen = (scores < repair["initial_reference"] * sharpness_map.BLUR_RATIO) & ~np.isnan(scores)
        repair["remaining_cells_frozen_reference_after_encoding"] = int(frozen.sum())
    sharpness_map.save_outputs("environment.rune_sanctum", decoded.convert("L"), 2.25,
                              scores, step, reference, blurry, work / "sharpness")
    report = quality.check(paths, *WORLD, BASE / "composition.png")
    write(PREVIEW / "qualite.json", report)
    write(SOURCE / "detail_recipe.json", {
        "world": WORLD, "native_size": NATIVE, "game_size": GAME,
        "native_density": .75, "presentation_density": 2.25,
        "retained_master_sha256": digest(retained), "regions_provenance": "regions_provenance.json",
        "native_antialias_radius_pixels": antialias_radius,
        "presentation": f"Détail peint par régions, anticrénelage natif{antialias_radius}px, Lanczos ×3 et correction locale des cases douces seulement.",
        "encoding": {"format": "WebP", "quality": encoding_quality, "method": 6},
        "tile_bytes": [p.stat().st_size for p in paths],
        "tiles_sha256": {p.name: digest(p) for p in paths}, "sharpness_repair": repair})
    decoded.resize((1024, 1536), Image.Resampling.LANCZOS).save(PREVIEW / "detail.webp", quality=92, method=6)
    print("QUALITE", report, flush=True)
    assert report["ok"], "Carte NON CONFORME : corriger avant livraison."

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generated", type=Path)
    parser.add_argument("--present", action="store_true")
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--quality", type=int, default=98)
    parser.add_argument("--model", type=Path)
    parser.add_argument("--antialias", type=float, default=0.0)
    args = parser.parse_args()
    work = args.work.resolve()
    assert not work.is_relative_to(ROOT), "Les intermédiaires restent hors dépôt."
    assert 1 <= args.quality <= 100 and 0 <= args.antialias <= 0.6
    work.mkdir(parents=True, exist_ok=True)
    plan = json.loads((BASE / "plan.json").read_text())
    assert plan["owner_approved"] and plan["identity_approved"] and plan["plan_locked"]
    if args.generated:
        build_master(args.generated.resolve())
    if args.present:
        present(work, args.quality, args.model, args.antialias)
    assert args.generated or args.present


if __name__ == "__main__":
    main()
