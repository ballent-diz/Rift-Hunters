#!/usr/bin/env python3
"""Assemble les seize régions peintes et présente le Panthéon brisé.

Les dessins intermédiaires restent hors dépôt ; seul le master retenu est conservé.
Ne modifie ni manifeste, ni données de jeu, ni collisions.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

import check_map_quality as quality
import map_seams

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/concepts/incoming/map.shattered_pantheon"
SOURCE = BASE / "source"
ENVIRONMENT = ROOT / "assets/environments/shattered_pantheon"
PREVIEW = ROOT / "docs/previews/shattered-pantheon"
WORLD = (4400, 4400)
NATIVE = (3300, 3300)
GAME = (9900, 9900)
Image.MAX_IMAGE_PIXELS = None


def digest(path):
    content = path.read_bytes()
    if path.name == "plan.json":
        content = content.replace(b"\r\n", b"\n")
    return hashlib.sha256(content).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_master(work, antialias_radius):
    assert not work.resolve().is_relative_to(ROOT.resolve())
    layout = json.loads((work / "regions.json").read_text(encoding="utf-8"))
    squares = json.loads((work / "square_regions.json").read_text(encoding="utf-8"))
    assert layout["world"] == list(WORLD) and len(layout["regions"]) == 16
    assert 0 <= antialias_radius <= 0.65
    canvas = np.zeros((NATIVE[1], NATIVE[0], 3), np.uint8)
    filled = np.zeros(canvas.shape[:2], bool)
    history = []
    for index, region in enumerate(layout["regions"]):
        name = region["name"]
        spec = next(s for s in squares if s["name"] == name)
        path = work / "regions" / (name + "_generated.png")
        image = Image.open(path).convert("RGB")
        span = spec["world_square"][2] - spec["world_square"][0]
        assert image.width == image.height and image.width >= 1254 and image.width / span >= 0.75
        crop = region["crop"]
        box = [round(v * 0.75) for v in crop]
        source_box = (0, 0, spec["actual_fraction"][0] * image.width,
                      spec["actual_fraction"][1] * image.height)
        part = image.crop(source_box).resize((box[2] - box[0], box[3] - box[1]), Image.Resampling.LANCZOS)
        row, column = divmod(index, 4)
        ox = round(layout["regions"][index - 1]["crop"][2] * 0.75) - box[0] if column else 0
        oy = round(layout["regions"][index - 4]["crop"][3] * 0.75) - box[1] if row else 0
        map_seams.insert(canvas, filled, np.asarray(part), box[0], box[1], ox, oy)
        prompt_file = work / "regions" / (name + "_prompt.txt")
        history.append({"name": name, "crop_world": crop, "square_world": spec["world_square"],
                        "generated_size": list(image.size), "generated_sha256": digest(path),
                        "generated_density": image.width / span,
                        "input_sha256": digest(work / "regions" / (name + "_square_input.png")),
                        "prompt": prompt_file.read_text(encoding="utf-8")})
        print("REGION_OK", name, flush=True)
    assert filled.all()
    master = Image.fromarray(canvas)
    unfiltered_sha = hashlib.sha256(master.tobytes()).hexdigest()
    if antialias_radius:
        master = master.filter(ImageFilter.GaussianBlur(antialias_radius))
    SOURCE.mkdir(parents=True, exist_ok=True)
    target = SOURCE / "map_detailed.webp"
    master.save(target, lossless=True, exact=True, method=6)
    assert np.array_equal(np.asarray(Image.open(target).convert("RGB")), np.asarray(master))
    write(SOURCE / "regions_provenance.json", {
        "date": "2026-11-07", "world": WORLD, "native_size": NATIVE, "native_density": 0.75,
        "composition_sha256": digest(BASE / "composition.png"), "plan_sha256": digest(BASE / "plan.json"),
        "plan_hash_convention": "UTF-8, fins de ligne LF",
        "reference_scale_sha256": digest(work / "reference_scale.png"), "regions": history,
        "assembly": "Raccord de faible différence par map_seams, puis anticrénelage natif borné.",
        "antialias_radius_native": antialias_radius, "unfiltered_pixels_sha256": unfiltered_sha,
        "master_sha256": digest(target), "lossless_verified": True,
        "note": "La génération dépassait la bande de détails fins sur les régions pilotes ; calibration de matière, seuils inchangés.",
        "intermediates": "Guides, régions et retouches hors dépôt ; seul le master retenu est versionné."})
    master.resize((1536, 1536), Image.Resampling.LANCZOS).save(work / "assembled-preview.webp", quality=94)
    print("MASTER_OK", target, flush=True)


def present():
    master_path = SOURCE / "map_detailed.webp"
    master = Image.open(master_path).convert("RGB")
    assert master.size == NATIVE
    full = master.resize(GAME, Image.Resampling.LANCZOS)
    ENVIRONMENT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    paths = []
    for i in range(3):
        target = ENVIRONMENT / ("map.webp" if i == 0 else f"map_{i}.webp")
        full.crop((i * 3300, 0, (i + 1) * 3300, 9900)).save(target, lossless=True, exact=True, method=6)
        paths.append(target)
        print("TILE_OK", target.name, target.stat().st_size, flush=True)
    master.resize((1536, 1536), Image.Resampling.LANCZOS).save(PREVIEW / "detail.webp", quality=94, method=6)
    composition = Image.open(BASE / "composition.png").convert("RGB")
    composition.resize((1536, 1536), Image.Resampling.LANCZOS).save(PREVIEW / "composition.webp", quality=94)
    reference = PREVIEW / "reference_collisions.jpg"
    master.resize((1100, 1100), Image.Resampling.LANCZOS).save(
        reference, quality=85, subsampling=0, optimize=True)
    write(SOURCE / "collision_reference.json", {
        "reference": "docs/previews/shattered-pantheon/reference_collisions.jpg",
        "sha256": digest(reference), "bytes": reference.stat().st_size, "size": [1100, 1100],
        "world": WORLD, "world_units_per_pixel": 4, "whole_map": True, "crop": None,
        "master_sha256": digest(master_path), "tiles_sha256": [digest(p) for p in paths],
        "recipe": "Master natif retenu, réduction Lanczos, JPEG85 sans sous-échantillonnage.",
        "expected_return": {"format": "PNG", "size": [1100, 1100], "same_framing": True,
                            "resize_allowed": False,
                            "paint": "Rouge translucide sur bâtiments, murs, socles de statues, abris et pilier ; accès, cours, autels et place praticables."},
        "collision_mask_created": False, "runtime_integrated": False})
    report = quality.check(paths, *WORLD, BASE / "composition.png")
    write(PREVIEW / "qualite.json", report)
    write(SOURCE / "detail_recipe.json", {"native_size": NATIVE, "game_size": GAME,
          "density": 2.25, "source": "map_detailed.webp", "source_sha256": digest(master_path),
          "presentation": "Lanczos ×3 du vrai détail par régions ; tuiles WebP sans perte.",
          "tiles": [{"path": str(p.relative_to(ROOT)), "sha256": digest(p),
                     "bytes": p.stat().st_size} for p in paths], "quality_conforme": report["ok"]})
    return report["ok"]


def repair_props(work):
    """Insère les retouches locales retenues, sans toucher aux pixels hors emprises."""
    assert not work.resolve().is_relative_to(ROOT.resolve())
    batches = json.loads((work / "batches.json").read_text(encoding="utf-8"))
    before = Image.open(work / "master_before.webp").convert("RGB")
    master = before.copy()
    mask = np.minimum.outer(np.minimum(np.arange(300), np.arange(299, -1, -1)),
                            np.minimum(np.arange(300), np.arange(299, -1, -1)))
    mask = Image.fromarray(np.uint8(np.clip(mask / 12, 0, 1) * 255))
    history = []
    changed = np.zeros((3300, 3300), bool)
    for batch in batches:
        path = work / f"batch_{batch['batch']:02}_generated.png"
        image = Image.open(path).convert("RGB")
        assert image.width == image.height and image.width >= 1200
        half = image.width // 2
        for index, item in enumerate(batch["items"]):
            x, y = index % 2 * half, index // 2 * half
            patch = image.crop((x, y, x + half, y + half)).resize((300, 300), Image.Resampling.LANCZOS)
            box = item["native_box"]
            master.paste(Image.composite(patch, master.crop(box), mask), box[:2])
            changed[box[1]:box[3], box[0]:box[2]] = True
        history.append({"batch": batch["batch"], "generated_sha256": digest(path),
                        "size": list(image.size), "items": batch["items"],
                        "prompt": (work / f"batch_{batch['batch']:02}_prompt.txt").read_text(encoding="utf-8")})
    assert np.array_equal(np.asarray(before)[~changed], np.asarray(master)[~changed])
    target = SOURCE / "map_detailed.webp"
    master.save(target, lossless=True, exact=True, method=6)
    write(SOURCE / "prop_repairs.json", {"date": "2026-11-07", "before_sha256": digest(work / "master_before.webp"),
          "master_sha256": digest(target), "native_size": NATIVE, "batches": history,
          "base_size_calibration": json.loads((work / "size_history.json").read_text(encoding="utf-8")),
          "method": "Quadrants indépendants rééchantillonnés à 300 px natifs, bord fondu sur 12 px.",
          "outside_patches_unchanged": True, "central_pillar_unchanged": True,
          "note": "Réduction des abris et socles, ajout de l'abri 09, autels abaissés ; plan approuvé conservé."})
    provenance_path = SOURCE / "regions_provenance.json"
    provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
    provenance["assembled_before_repairs_sha256"] = digest(work / "master_before.webp")
    provenance["master_sha256"] = digest(target)
    provenance.setdefault("pre_delivery_plan_sha256", provenance["plan_sha256"])
    provenance.pop("generation_plan_sha256", None)
    provenance["plan_sha256"] = digest(BASE / "plan.json")
    provenance["local_repairs"] = "prop_repairs.json"
    write(provenance_path, provenance)
    print("PROP_REPAIRS_OK", sum(len(b["items"]) for b in batches), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generated", type=Path)
    parser.add_argument("--antialias-radius", type=float, default=0.5)
    parser.add_argument("--present", action="store_true")
    parser.add_argument("--repairs", type=Path)
    args = parser.parse_args()
    if args.generated:
        build_master(args.generated, args.antialias_radius)
    if args.repairs:
        repair_props(args.repairs)
    if args.present and not present():
        raise SystemExit(1)


if __name__ == "__main__":
    main()
