#!/usr/bin/env python3
"""Exporte la carte19 depuis ses sources peintes, sans toucher au manifeste ni au niveau.

--present : tuiles intactes depuis le master natif ; correction locale des cases douces.
Les sources et exports brisés partagent le fond intact, afin de préserver tous les pixels hors plaques.
Les intermédiaires et images entières de revue restent dans --work, hors dépôt.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import check_map_quality as quality
import map_regions
import sharpness_map

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/concepts/incoming/map.lighthouse_floe"
SOURCE = BASE / "source"
PREVIEW = ROOT / "docs/previews/lighthouse-floe"
ENVIRONMENT = ROOT / "assets/environments/lighthouse_floe"
WORLD = (5016, 5016)
NATIVE = (3762, 3762)
GAME = (11286, 11286)
Image.MAX_IMAGE_PIXELS = None


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def repair_soft_cells(image, model, work):
    """Correction locale prévue par QUALITE_DES_CARTES, sur le détail déjà peint."""
    import deblur_map
    import onnxruntime

    scores, step = sharpness_map.cell_scores(image.convert("L"), 2.25)
    reference = float(np.nanpercentile(scores, sharpness_map.REFERENCE_PERCENTILE))
    blurry = (scores < reference * sharpness_map.BLUR_RATIO) & ~np.isnan(scores)
    sharpness_map.save_outputs("environment.lighthouse_floe", image.convert("L"), 2.25,
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


def intact_paths():
    return [ENVIRONMENT / name for name in ("map.webp", "map_1.webp", "map_2.webp")]


def decoded_intact():
    image = Image.new("RGB", GAME)
    for index, path in enumerate(intact_paths()):
        tile = Image.open(path).convert("RGB")
        assert tile.size == (3762, 11286)
        image.paste(tile, (index * 3762, 0))
    return image


def present(work, encoding_quality, model):
    retained = SOURCE / "map_detailed.webp"
    provenance = json.loads((SOURCE / "regions_provenance.json").read_text())
    assert digest(retained) == provenance["retained_sha256"]
    assert digest(BASE / "composition.png") == provenance["composition_sha256"]
    native = Image.open(retained).convert("RGB")
    assert native.size == NATIVE
    full = native.resize(GAME, Image.Resampling.LANCZOS)
    full, repair = repair_soft_cells(full, model, work)
    ENVIRONMENT.mkdir(parents=True, exist_ok=True)
    paths = intact_paths()

    def encode(index):
        full.crop((index * 3762, 0, (index + 1) * 3762, 11286)).save(
            paths[index], quality=encoding_quality, method=6)
        print("TUILE_INTACTE", paths[index].name, paths[index].stat().st_size, flush=True)

    with ThreadPoolExecutor(max_workers=3) as executor:
        list(executor.map(encode, range(3)))
    decoded = decoded_intact()
    scores, step = sharpness_map.cell_scores(decoded.convert("L"), 2.25)
    reference = float(np.nanpercentile(scores, sharpness_map.REFERENCE_PERCENTILE))
    blurry = (scores < reference * sharpness_map.BLUR_RATIO) & ~np.isnan(scores)
    if "initial_reference" in repair:
        frozen = (scores < repair["initial_reference"] * sharpness_map.BLUR_RATIO) & ~np.isnan(scores)
        repair["remaining_cells_frozen_reference_after_encoding"] = int(frozen.sum())
    sharpness_map.save_outputs("environment.lighthouse_floe", decoded.convert("L"), 2.25,
                              scores, step, reference, blurry, work / "sharpness")
    report = quality.check(paths, *WORLD, BASE / "composition.png")
    write(PREVIEW / "qualite_intacte.json", report)
    recipe = {"world": WORLD, "native_density": .75, "presentation_density": 2.25,
              "retained_master_sha256": digest(retained), "provenance": "regions_provenance.json",
              "presentation": "Lanczos ×3 après redessin des16régions ; correction locale des cases douces seulement.",
              "encoding": {"format": "WebP", "quality": encoding_quality, "method": 6},
              "tile_bytes": [p.stat().st_size for p in paths],
              "tiles_sha256": {p.name: digest(p) for p in paths}, "sharpness_repair": repair,
              "relative_sharpness": {"blurry_cells": int(blurry.sum()),
                                     "valid_cells": int((~np.isnan(scores)).sum())}}
    write(SOURCE / "detail_recipe.json", recipe)
    print("QUALITE_INTACTE", report, flush=True)
    assert report["ok"], "Carte intacte NON CONFORME : corriger avant livraison."


def polygon_mask(polygon, size):
    """Appartenance du centre de pixel au polygone ; bords sans débordement."""
    points = np.asarray(polygon, np.float64) / 100 * np.asarray(size, np.float64)
    lower = np.maximum(0, np.floor(points.min(axis=0)).astype(int))
    upper = np.minimum(size, np.ceil(points.max(axis=0)).astype(int))
    x0, y0 = lower.tolist()
    x1, y1 = upper.tolist()
    x = (np.arange(x0, x1) + .5)[None, :]
    y = (np.arange(y0, y1) + .5)[:, None]
    mask = np.zeros((y1 - y0, x1 - x0), bool)
    for start, end in zip(points, np.roll(points, -1, axis=0)):
        if start[1] == end[1]:
            continue
        crossing = ((start[1] > y) != (end[1] > y)) & (
            x < (end[0] - start[0]) * (y - start[1]) / (end[1] - start[1]) + start[0])
        mask ^= crossing
    assert mask.any()
    return (x0, y0, x1, y1), mask


def make_native_delta(generated):
    """Compile les ouvertures peintes en une source transparente commune au cadrage natif."""
    assert not generated.is_relative_to(ROOT)
    plan = json.loads((BASE / "plan.json").read_text())
    rows = json.loads((generated / "opened_outputs.json").read_text())
    assert len(rows) == len(plan["plates"]) == 14
    canvas = np.zeros((3762, 3762, 4), np.uint8)
    union = np.zeros((3762, 3762), bool)
    history = []
    for plate in plan["plates"]:
        row = next(r for r in rows if r["id"] == plate["id"])
        assert digest(generated / row["input_file"]) == row["input_sha256"], "Recadrage de génération modifié."
        path = Path(row["path"])
        source = Image.open(path).convert("RGB")
        crop = row["box_world"]
        bounds = [round(v * .75) for v in crop]
        density = min(source.width / (crop[2] - crop[0]), source.height / (crop[3] - crop[1]))
        assert density >= .75
        native = source.resize((bounds[2] - bounds[0], bounds[3] - bounds[1]), Image.Resampling.LANCZOS)
        native, sharpening = map_regions.match_sharpness(native)
        box, mask = polygon_mask(plate["polygon_pct"], NATIVE)
        x0, y0, x1, y1 = box
        assert not union[y0:y1, x0:x1][mask].any(), "Deux plaques se recouvrent."
        union[y0:y1, x0:x1] |= mask
        painted = np.asarray(native.crop((x0 - bounds[0], y0 - bounds[1], x1 - bounds[0], y1 - bounds[1])))
        region = canvas[y0:y1, x0:x1]
        region[mask, :3] = painted[mask]
        region[mask, 3] = 255
        luminance = painted[mask].astype(float) @ np.array([.2126, .7152, .0722])
        dark_fraction = float((luminance < 100).mean())
        assert dark_fraction >= .6, (plate["id"], "Ouverture insuffisamment sombre", dark_fraction)
        history.append({"id": plate["id"], "world_crop": crop, "input_sha256": row["input_sha256"],
                        "generated_sha256": digest(path), "generated_dimensions": list(source.size),
                        "generated_density": density, "native_sharpening_percent": sharpening,
                        "dark_water_fraction": round(dark_fraction, 4), "prompts": row["prompts"]})
    target = SOURCE / "broken_delta.webp"
    Image.fromarray(canvas).save(target, lossless=True, exact=True, method=6)
    assert np.array_equal(np.asarray(Image.open(target).convert("RGBA")), canvas)
    assert not canvas[~union, 3].any()
    plan["detail_generated"] = True
    plan["paired_images"]["broken_generated"] = True
    plan["stage"] = "detail_graphique_livre"
    write(BASE / "plan.json", plan)
    write(SOURCE / "broken_provenance.json", {
        "date": "2026-11-05", "world": WORLD, "native_size": NATIVE,
        "master_sha256": digest(SOURCE / "map_detailed.webp"), "delta_sha256": digest(target),
        "plan_sha256": digest(BASE / "plan.json"),
        "method": "Mêmes16régions communes ;14ouvertures peintes localement, limitées strictement aux polygones B4.",
        "outside_plate_alpha_zero": True, "static_collision_mask_created": False, "plates": history})


def export_states(work):
    """Reconstruit deux images entières et les14surimpressions sans doubler le fond dans Git."""
    plan = json.loads((BASE / "plan.json").read_text())
    provenance = json.loads((SOURCE / "broken_provenance.json").read_text())
    delta_path = SOURCE / "broken_delta.webp"
    assert digest(delta_path) == provenance["delta_sha256"]
    assert digest(SOURCE / "map_detailed.webp") == provenance["master_sha256"]
    assert digest(BASE / "plan.json") == provenance["plan_sha256"]
    common_native = Image.open(SOURCE / "map_detailed.webp").convert("RGB")
    delta_native = Image.open(delta_path).convert("RGBA")
    broken_native = Image.alpha_composite(common_native.convert("RGBA"), delta_native).convert("RGB")
    common_native.save(work / "native_intact.webp", lossless=True, exact=True, method=6)
    broken_native.save(work / "native_broken.webp", lossless=True, exact=True, method=6)
    native_outside = np.asarray(delta_native)[:, :, 3] == 0
    assert np.array_equal(np.asarray(Image.open(work / "native_intact.webp"))[native_outside],
                          np.asarray(Image.open(work / "native_broken.webp"))[native_outside])
    common = decoded_intact()
    broken = common.copy()
    delta = delta_native.resize(GAME, Image.Resampling.LANCZOS)
    union = np.zeros((11286, 11286), bool)
    folder = ENVIRONMENT / "broken"
    folder.mkdir(exist_ok=True)
    overlays = []
    for plate in plan["plates"]:
        box, mask = polygon_mask(plate["polygon_pct"], GAME)
        x0, y0, x1, y1 = box
        union[y0:y1, x0:x1] |= mask
        pixels = np.asarray(delta.crop(box)).copy()
        pixels[~mask] = 0
        pixels[mask, 3] = 255
        path = folder / (plate["id"] + ".webp")
        Image.fromarray(pixels).save(path, lossless=True, exact=True, method=6)
        decoded = Image.open(path).convert("RGBA")
        assert np.array_equal(np.asarray(decoded), pixels)
        broken.paste(decoded.convert("RGB"), (x0, y0), decoded.getchannel("A"))
        overlays.append({"id": plate["id"], "file": path.relative_to(ROOT).as_posix(),
                         "pixel_rect_on_full_image": list(box),
                         "world_rect_on_full_image": [round(v / 2.25, 6) for v in box],
                         "sha256": digest(path)})
        print("OUVERTURE_EXPORTÉE", plate["id"], flush=True)
    changed = np.any(np.asarray(common) != np.asarray(broken), axis=2)
    assert not changed[~union].any(), "Pixels modifiés hors plaques après encodage."
    temp = work / "broken_tiles"
    temp.mkdir(exist_ok=True)
    paths = []
    for index in range(3):
        path = temp / ("map_%d.png" % index)
        tile = broken.crop((index * 3762, 0, (index + 1) * 3762, 11286))
        tile.save(path, compress_level=3)
        assert np.array_equal(np.asarray(Image.open(path).convert("RGB")), np.asarray(tile))
        paths.append(path)
    # La référence de composition de cet état conserve le plan approuvé partout
    # sauf aux ouvertures B4 demandées. Comparer des trous noirs à des plaques
    # claires mesurerait le changement d'état, plutôt qu'une dérive du plan.
    composition = Image.open(BASE / "composition.png").convert("RGB")
    reference_pixels = np.asarray(composition).copy()
    state_pixels = np.asarray(delta_native.resize(composition.size, Image.Resampling.LANCZOS))
    reference_union = np.zeros((composition.height, composition.width), bool)
    for plate in plan["plates"]:
        box, mask = polygon_mask(plate["polygon_pct"], composition.size)
        reference_union[box[1]:box[3], box[0]:box[2]] |= mask
    reference_pixels[reference_union] = state_pixels[reference_union, :3]
    reference = SOURCE / "composition_broken_reference.webp"
    Image.fromarray(reference_pixels).save(reference, lossless=True, exact=True, method=6)
    assert np.array_equal(np.asarray(Image.open(reference))[~reference_union],
                          np.asarray(composition)[~reference_union])
    write(SOURCE / "broken_reference_recipe.json", {
        "composition_sha256": digest(BASE / "composition.png"), "delta_sha256": digest(delta_path),
        "reference_sha256": digest(reference), "size": list(composition.size),
        "method": "Composition approuvée inchangée hors plaques ; projection des seules ouvertures B4 dans leurs polygones.",
        "outside_plates_identical": True, "quality_thresholds_unchanged": True})
    report = quality.check(paths, *WORLD, reference)
    write(PREVIEW / "qualite_brisee.json", report)
    assert report["ok"], "Carte brisée NON CONFORME."
    # Les aperçus respectent aussi la frontière des plaques après réduction et encodage.
    preview_size = (1536, 1536)
    intact_preview = common.resize(preview_size, Image.Resampling.LANCZOS)
    broken_preview = np.asarray(broken.resize(preview_size, Image.Resampling.LANCZOS)).copy()
    allowed = np.zeros((1536, 1536), bool)
    for plate in plan["plates"]:
        box, mask = polygon_mask(plate["polygon_pct"], preview_size)
        allowed[box[1]:box[3], box[0]:box[2]] |= mask
    broken_preview[~allowed] = np.asarray(intact_preview)[~allowed]
    intact_preview.save(PREVIEW / "intacte.webp", lossless=True, exact=True, method=6)
    Image.fromarray(broken_preview).save(PREVIEW / "brisee.webp", lossless=True, exact=True, method=6)
    assert np.array_equal(np.asarray(Image.open(PREVIEW / "intacte.webp"))[~allowed],
                          np.asarray(Image.open(PREVIEW / "brisee.webp"))[~allowed])
    receipt = {"world": WORLD, "native_size": NATIVE, "game_size": GAME,
               "pixel_rule": "Centre du pixel à l’intérieur du polygone ; aucun débordement.",
               "source_master_sha256": digest(SOURCE / "map_detailed.webp"),
               "source_delta_sha256": digest(delta_path), "plan_sha256": digest(BASE / "plan.json"),
               "intact_tiles_sha256": {p.name: digest(p) for p in intact_paths()},
               "overlays": overlays, "changed_pixels_inside_plates": int(changed[union].sum()),
               "changed_pixels_outside_plates": 0, "native_outside_equal_after_encoding": True,
               "game_outside_equal_after_encoding": True, "preview_outside_equal_after_encoding": True,
               "native_whole_images_sha256": {n: digest(work / n) for n in ("native_intact.webp", "native_broken.webp")},
               "storage": "Fond commun stocké une fois,14surimpressions et source delta sans perte ; deux images entières reconstituables.",
               "static_collision_mask_created": False, "runtime_integrated": False}
    write(SOURCE / "paired_recipe.json", receipt)
    write(PREVIEW / "superposition.json", receipt)
    print("DEUX_ETATS_CONFORMES_PIXELS_HORS_PLAQUES_IDENTIQUES", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--present", action="store_true")
    parser.add_argument("--generated-broken", type=Path)
    parser.add_argument("--export-states", action="store_true")
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--quality", type=int, default=98)
    parser.add_argument("--model", type=Path)
    args = parser.parse_args()
    work = args.work.resolve()
    assert not work.is_relative_to(ROOT), "Intermédiaires hors dépôt."
    work.mkdir(parents=True, exist_ok=True)
    assert 1 <= args.quality <= 100
    if args.present:
        present(work, args.quality, args.model)
    if args.generated_broken:
        make_native_delta(args.generated_broken.resolve())
    if args.export_states:
        export_states(work)


if __name__ == "__main__":
    main()
