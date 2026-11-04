#!/usr/bin/env python3
"""Assemble les régions peintes de la carte 17 et reconstruit ses tuiles, hors runtime.

Les essais restent hors dépôt ; seul le master natif sans perte est retenu.
Construction : --generated <dossier des 32 demi-régions> --work <dossier hors dépôt>.
Reconstruction depuis le master retenu : --rebuild --work <dossier hors dépôt>.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

import check_map_quality as quality
import map_regions
import map_seams
import sharpness_map
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/concepts/incoming/map.brazier_pass"
SOURCE = BASE / "source"
PREVIEW = ROOT / "docs/previews/brazier-pass"
WORLD = (5016, 5016)
Image.MAX_IMAGE_PIXELS = None


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def calibrate(image):
    """Plus petit masque flou de rayon 1 px atteignant les bandes de référence, plafond 120 %."""
    reference = json.loads(quality.REFERENCE.read_text())
    limits = quality.bands(reference)
    candidates = []
    for percent in map_regions.SHARPEN_STEPS:
        candidate = image if not percent else image.filter(
            ImageFilter.UnsharpMask(radius=1, percent=percent, threshold=2))
        game = candidate.resize((candidate.width * 3, candidate.height * 3), Image.Resampling.LANCZOS)
        sectors = quality.sector_metrics(np.asarray(game.convert("L")).astype(np.float32) / 255)
        values = np.median([s[2:] for s in sectors], axis=0)
        targets = [limits[k]["global"] for k in ("smooth", "fine", "medium")]
        # Viser près des médianes natives laisse une marge au raccord et à l'encodage WebP.
        # Les seuils du contrôle final restent strictement ceux du dépôt.
        for i, key in enumerate(("fine", "medium"), 1):
            targets[i] = (reference[key]["median"] * .95, targets[i][1])
        # La part lisse n'a qu'un plafond ; davantage de matière n'est pas pénalisé ici.
        loss = max(0, values[0] - targets[0][1])
        for value, (low, high) in zip(values[1:], targets[1:]):
            loss += max(0, low - value, value - high) / low
        record = {"percent": percent, "median_smooth_fine_medium": values.tolist(),
                  "regional_reference_bands_met": bool(loss == 0)}
        candidates.append((loss, candidate, record))
        if loss == 0:
            return candidate, record
    _, candidate, record = min(candidates, key=lambda item: item[0])
    return candidate, record


def build_master(generated, work):
    assert not generated.is_relative_to(ROOT), "Les intermédiaires restent hors dépôt."
    parts = json.loads((generated / "plan.json").read_text())
    assert len(parts) == 32 and len({p["region"] for p in parts}) == 16
    layout_dir = work / "layout"
    map_regions.split(BASE / "composition.png", WORLD, layout_dir)
    layout = json.loads((layout_dir / "regions.json").read_text())
    canvas = np.zeros((3762, 3762, 3), np.uint8)
    filled = np.zeros(canvas.shape[:2], bool)
    history = []
    for index, region in enumerate(layout["regions"]):
        name = region["name"]
        selected = sorted([p for p in parts if p["region"] == name], key=lambda p: p["part"])
        crop = region["crop"]
        box = [round(v * .75) for v in crop]
        width, height = box[2] - box[0], box[3] - box[1]
        pixels = np.zeros((height, width, 3), np.uint8)
        occupied = np.zeros(pixels.shape[:2], bool)
        previous_right = 0
        provenance = []
        for part in selected:
            folder = generated / part["name"]
            image = Image.open(folder / "output.png").convert("RGB")
            rect = part["crop_in_region_world"]
            span = (rect[2] - rect[0], rect[3] - rect[1])
            density = min(image.width / span[0], image.height / span[1])
            assert density >= .75, f"Résolution native insuffisante : {part['name']}"
            assert abs(image.width / image.height / (span[0] / span[1]) - 1) < .02
            left, right = round(rect[0] * .75), min(width, round(rect[2] * .75))
            if part["part"] == 1:
                right = width
            data = np.asarray(image.resize((right - left, height), Image.Resampling.LANCZOS))
            map_seams.insert(pixels, occupied, data, left, 0, max(0, previous_right - left))
            previous_right = right
            metadata = json.loads((folder / "generation.json").read_text())
            prompts = ["PROMPT_DETAIL.txt"]
            if metadata.get("material_reference"):
                prompts.append("PROMPT_REFERENCE_MATIERE.txt")
            if metadata.get("cliff_correction"):
                prompts.append("PROMPT_FALAISES.txt")
            prompts = metadata.get("prompts", prompts)
            provenance.append({"name": part["name"], "global_crop_world": part["global_crop_world"],
                               "dimensions": list(image.size), "generated_density": density,
                               "original_sha256": digest(folder / "output.png"),
                               "input_sha256": digest(folder / "input.png"),
                               "scale_reference_sha256": digest(folder / "reference_scale.png"),
                               "prompts": prompts,
                               "scale_correction_chain": metadata.get("scale_correction_chain"),
                               "before_cliff_correction_sha256": metadata.get("before_cliff_correction_sha256")})
        assert occupied.all()
        native, sharpening = calibrate(Image.fromarray(pixels))
        row, column = divmod(index, 4)
        overlap_x = round(layout["regions"][index - 1]["crop"][2] * .75) - box[0] if column else 0
        overlap_y = round(layout["regions"][index - 4]["crop"][3] * .75) - box[1] if row else 0
        map_seams.insert(canvas, filled, np.asarray(native), box[0], box[1], overlap_x, overlap_y)
        history.append({"name": name, "crop_world": crop, "parts": provenance, "sharpness": sharpening})
        print(name, sharpening, flush=True)
    assert filled.all()
    master = Image.fromarray(canvas)
    retained = SOURCE / "map_detailed.webp"
    master.save(retained, lossless=True, method=6)
    assert Image.open(retained).convert("RGB").tobytes() == master.tobytes()
    job = json.loads((BASE / "job.json").read_text())
    write(SOURCE / "regions_provenance.json", {
        "world": WORLD, "composition_sha256": digest(BASE / "composition.png"),
        "approved_plan_date": job["owner_approval_date"], "generated_date": "2026-11-04",
        "method": "Seize régions peintes en trente-deux demi-régions, recouvrement de 128 unités ; raccord de faible différence.",
        "regions": history, "retained_source": retained.name, "retained_sha256": digest(retained),
        "retained_dimensions": list(master.size), "retained_density": .75,
        "pixels_lossless_verified": True,
        "prompts": ["PROMPT_DETAIL.txt", "PROMPT_REFERENCE_MATIERE.txt",
                    "PROMPT_ECHELLE_PORTE.txt", "PROMPT_ECHELLE_PORTE_FIN.txt"],
        "intermediate_images": "Conservées hors dépôt ; une seule source native assemblée retenue."})


def repair_soft_cells(image, model, work):
    """Correction locale prévue par QUALITE_DES_CARTES, sur le détail déjà peint."""
    import deblur_map
    import onnxruntime

    scores, step = sharpness_map.cell_scores(image.convert("L"), 2.25)
    reference = float(np.nanpercentile(scores, sharpness_map.REFERENCE_PERCENTILE))
    blurry = (scores < reference * sharpness_map.BLUR_RATIO) & ~np.isnan(scores)
    sharpness_map.save_outputs("environment.brazier_pass", image.convert("L"), 2.25,
                              scores, step, reference, blurry, work / "sharpness-before-repair")
    initial = int(blurry.sum())
    if not initial:
        return image, {"initial_cells": 0, "remaining_cells_frozen_reference": 0}
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
        result[y:y + inner, x:x + inner] = (
            original[y:y + inner, x:x + inner] * (1 - alpha) + sharp[ys, xs] * alpha + .5)
        if index % 25 == 0:
            print(f"Correction locale : bloc {index + 1}/{len(blocks)}", flush=True)
    corrected = Image.fromarray(result)
    after, _ = sharpness_map.cell_scores(corrected.convert("L"), 2.25)
    remaining = (after < reference * sharpness_map.BLUR_RATIO) & ~np.isnan(after)
    record = {"method": "Real-ESRGAN x4v3, débruitage 0,2 ; demi-taille puis ×4 et retour à taille initiale ; cases douces seulement.",
              "model": model.name, "model_sha256": digest(model), "initial_cells": initial,
              "initial_reference": reference, "remaining_cells_frozen_reference": int(remaining.sum()),
              "valid_cells": int((~np.isnan(scores)).sum()),
              "selected_cells_row_col": np.argwhere(blurry).tolist(), "blocks": len(blocks)}
    write(SOURCE / "sharpness_repair.json", record)
    return corrected, record


def present(work, encoding_quality, model):
    retained = SOURCE / "map_detailed.webp"
    provenance = json.loads((SOURCE / "regions_provenance.json").read_text())
    assert digest(retained) == provenance["retained_sha256"]
    assert digest(BASE / "composition.png") == provenance["composition_sha256"], "Le plan validé a changé."
    native = Image.open(retained).convert("RGB")
    assert native.size == (3762, 3762)
    full = native.resize((11286, 11286), Image.Resampling.LANCZOS)
    full, repair = repair_soft_cells(full, model, work)
    folder = ROOT / "assets/environments/brazier_pass"
    folder.mkdir(exist_ok=True)
    paths = [folder / name for name in ("map.webp", "map_1.webp", "map_2.webp")]

    def encode(index):
        full.crop((index * 3762, 0, (index + 1) * 3762, 11286)).save(
            paths[index], quality=encoding_quality, method=6)

    with ThreadPoolExecutor(max_workers=3) as executor:
        list(executor.map(encode, range(3)))
    decoded = Image.new("RGB", full.size)
    for index, path in enumerate(paths):
        decoded.paste(Image.open(path).convert("RGB"), (index * 3762, 0))
    scores, step = sharpness_map.cell_scores(decoded.convert("L"), 2.25)
    reference = float(np.nanpercentile(scores, sharpness_map.REFERENCE_PERCENTILE))
    blurry = (scores < reference * sharpness_map.BLUR_RATIO) & ~np.isnan(scores)
    if "initial_reference" in repair:
        frozen = (scores < repair["initial_reference"] * sharpness_map.BLUR_RATIO) & ~np.isnan(scores)
        repair["remaining_cells_frozen_reference_after_encoding"] = int(frozen.sum())
    sharpness_map.save_outputs("environment.brazier_pass", decoded.convert("L"), 2.25,
                              scores, step, reference, blurry, work / "sharpness")
    report = quality.check(paths, *WORLD, BASE / "composition.png")
    write(PREVIEW / "qualite.json", report)
    recipe = {"world": WORLD, "native_density": .75, "presentation_density": 2.25,
              "retained_master_sha256": digest(retained),
              "provenance": "regions_provenance.json",
              "local_scale_corrections": provenance.get("local_scale_corrections"),
              "local_bridge_paving": provenance.get("local_bridge_paving"),
              "presentation": "Lanczos ×3 après redessin, puis correction locale des cases douces ; aucun ajout procédural de texture.",
              "native_sharpness": "Masque flou rayon 1 px, seuil 2, de 0 à 120 % ; réglages par région dans la provenance.",
              "encoding": {"format": "WebP", "quality": encoding_quality, "method": 6},
              "tile_bytes": [p.stat().st_size for p in paths],
              "tiles_sha256": {p.name: digest(p) for p in paths},
              "sharpness_repair": repair,
              "relative_sharpness": {"blurry_cells": int(blurry.sum()),
                                     "valid_cells": int((~np.isnan(scores)).sum())}}
    write(SOURCE / "detail_recipe.json", recipe)
    print("QUALITÉ", report, flush=True)
    assert report["ok"], "Carte NON CONFORME : corriger avant livraison."


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generated", type=Path)
    parser.add_argument("--rebuild", action="store_true")
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--quality", type=int, default=98)
    parser.add_argument("--model", type=Path, help="Modèle ONNX x4v3, débruitage0,2, pour la correction locale.")
    args = parser.parse_args()
    work = args.work.resolve()
    assert not work.is_relative_to(ROOT)
    assert 1 <= args.quality <= 100
    work.mkdir(parents=True, exist_ok=True)
    if not args.rebuild:
        assert args.generated is not None
        build_master(args.generated.resolve(), work)
    present(work, args.quality, args.model)


if __name__ == "__main__":
    main()
