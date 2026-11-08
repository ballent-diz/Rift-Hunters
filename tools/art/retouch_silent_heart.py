#!/usr/bin/env python3
"""Retouches locales du Cœur du Silence, depuis ses sources et tuiles retenues.

Les essais et quatre dessins intermédiaires restent dans --work, hors dépôt.
Conserve exactement les pixels des tuiles hors des emprises retouchées.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

import check_map_quality as quality

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/concepts/incoming/map.silent_heart"
SOURCE = BASE / "source"
ENVIRONMENT = ROOT / "assets/environments/silent_heart"
PREVIEW = ROOT / "docs/previews/silent-heart"
WORLD = (5016, 3344)
NATIVE = (3762, 2508)
GAME = (11286, 7524)
Image.MAX_IMAGE_PIXELS = None


def digest(path):
    content = path.read_bytes()
    if path.suffix in (".json", ".txt", ".gd", ".py"):
        content = content.replace(b"\r\n", b"\n")
    return hashlib.sha256(content).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def world(point):
    return point[0] * 50.16, point[1] * 33.44


def patch_mask(spec):
    mask = Image.new("L", (825, 825))
    draw = ImageDraw.Draw(mask)
    left, top = spec["native_box"][:2]

    def local(at):
        return at[0] * .75 - left, at[1] * .75 - top

    if spec["id"] == "path":
        bounds = spec["path_mask_world"]
        x1, y1 = local(bounds[:2])
        x2, y2 = local(bounds[2:])
        draw.rectangle((x1, y1, x2, y2), fill=255)
    for item in spec["ice"]:
        x, y = local(world(item["center_pct"]))
        radius = (item["diameter_world"] / 2 + 50) * .75
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=255)
    for item in spec["covers"]:
        x, y = local(world(item["center_pct"]))
        draw.rectangle((x - 85, y - 150, x + 85, y + 45), fill=255)
    return mask.filter(ImageFilter.GaussianBlur(9))


def revise_plan(specs, original_plan):
    plan = json.loads((BASE / "plan.json").read_text(encoding="utf-8"))
    plan["owner_local_revision"] = {
        "date": "2026-11-07", "approved_scope": "Ouvrir le passage de DROITE, entre salle est et îlot central ; conserver l'escalier de gauche près de la cascade, la glace et les obstacles centraux ajoutés.",
        "preserve_layout": True, "collision_mask_created": False,
        "supersedes": "Sept plaques seulement et noyau final entièrement en neige ferme : ajout central autorisé par le propriétaire."}
    plan["stage"] = "detail_retouche_locale_livre"
    plan["composition_sha256"] = digest(BASE / "composition.png")
    plan["passages"] = original_plan["passages"]
    passage = next(p for p in plan["passages"] if p["id"] == "tunnel")
    passage.update(kind="Chaussée enneigée ouverte à gauche et à droite ; deux murets fermant les raccords retirés",
                   centerline_pct=[[78.4, 57], [67.8, 57]], width_world_target=290,
                   measurement_status="Lisibilité graphique contrôlée sur capture ; largeur de navigation à valider après peinture des collisions.")
    plan["cathedral"]["firm_combat_core_pct"]["revision_note"] = "Repère historique de la clairière, plus entièrement vide ni uniquement en neige ferme : glace et deux petits abris centraux autorisés."
    for spec in specs:
        for item in spec["ice"]:
            if any(p["id"] == item["id"] for p in plan["slippery_ice"]):
                continue
            plan["slippery_ice"].append({**item, "zone": {"west": "cathedral", "middle": "z2", "east": "z1"}[spec["id"]],
                "walkable": True, "required_path": False, "geometry_scope": "Nouveau repère central ; contour B1 à relever sur le détail retenu, aucun masque de collision.",
                "owner_added": True})
        for item in spec["covers"]:
            if any(p["id"] == item["id"] for p in plan["cover_rocks"]):
                continue
            plan["cover_rocks"].append({**item, "zone": {"west": "cathedral", "middle": "z2", "east": "z1"}[spec["id"]],
                "width_world_target": 140, "width_world_allowed": [110, 160],
                "blocking": True, "on_slippery_ice": False, "owner_added": True})
    write(BASE / "plan.json", plan)
    job = json.loads((BASE / "job.json").read_text(encoding="utf-8"))
    job.update(stage=plan["stage"], slippery_ice=10, cover_rocks=16,
               composition_sha256=plan["composition_sha256"], local_revision="source/local_access_revision.json")
    write(BASE / "job.json", job)


def apply(work):
    assert not work.resolve().is_relative_to(ROOT.resolve())
    specs = json.loads((work / "outputs.json").read_text(encoding="utf-8"))
    native_before = Image.open(work / "master_before.webp").convert("RGB")
    native = native_before.copy()
    composition = Image.open(work / "composition_before.png").convert("RGB")
    before = Image.new("RGB", GAME)
    for i, name in enumerate(("map.webp", "map_1.webp", "map_2.webp")):
        before.paste(Image.open(work / name).convert("RGB"), (i * 3762, 0))
    game = before.copy()
    changed = Image.new("L", GAME)
    history = []
    for spec in specs:
        image_path = work / (spec["id"] + "_generated.png")
        image = Image.open(image_path).convert("RGB")
        assert image.width == image.height and image.width >= 1254
        patch = image.resize((825, 825), Image.Resampling.LANCZOS)
        mask = patch_mask(spec)
        box = spec["native_box"]
        native.paste(patch, box[:2], mask)
        gx, gy = box[0] * 3, box[1] * 3
        alpha = mask.resize((2475, 2475), Image.Resampling.BILINEAR)
        game.paste(patch.resize((2475, 2475), Image.Resampling.LANCZOS), (gx, gy), alpha)
        changed.paste(ImageChops.lighter(changed.crop((gx, gy, gx + 2475, gy + 2475)), alpha), (gx, gy))
        cb = [round(v * composition.width / NATIVE[0]) for v in box]
        size = (cb[2] - cb[0], cb[3] - cb[1])
        composition.paste(patch.resize(size, Image.Resampling.LANCZOS), cb[:2], mask.resize(size, Image.Resampling.BILINEAR))
        history.append({"id": spec["id"], "native_box": box, "world_box": spec["world_box"],
                        "input_sha256": digest(work / (spec["id"] + "_input.png")),
                        "guide_sha256": digest(work / (spec["id"] + "_guide.png")),
                        "generated_sha256": digest(image_path), "generated_size": list(image.size),
                        "generated_density": image.width / 1100,
                        "prompt": spec["prompt"], "ice": spec["ice"], "covers": spec["covers"]})
    support = np.asarray(changed) > 0
    assert np.array_equal(np.asarray(before)[~support], np.asarray(game)[~support])
    west_box = tuple(round(v * 2.25) for v in (1850, 1750, 2470, 2150))
    assert np.array_equal(np.asarray(before.crop(west_box)), np.asarray(game.crop(west_box)))
    native.save(SOURCE / "map_detailed.webp", lossless=True, exact=True, method=4)
    composition.save(BASE / "composition.png")
    tiles = []
    for i, name in enumerate(("map.webp", "map_1.webp", "map_2.webp")):
        path = ENVIRONMENT / name
        part = game.crop((i * 3762, 0, (i + 1) * 3762, 7524))
        part.save(path, lossless=True, exact=True, method=4)
        assert np.array_equal(np.asarray(Image.open(path).convert("RGB")), np.asarray(part))
        tiles.append(path)
        print("TILE_OK", name, path.stat().st_size, flush=True)
    game.resize((1536, 1024), Image.Resampling.LANCZOS).save(PREVIEW / "detail.webp", quality=94, method=6)
    before.resize((1536, 1024), Image.Resampling.LANCZOS).save(work / "before_preview.webp", quality=94)
    reference = PREVIEW / "reference_collisions.jpg"
    game.resize((1254, 836), Image.Resampling.LANCZOS).save(reference, quality=85, subsampling=0, optimize=True)
    revise_plan(specs, json.loads((work / "plan_before.json").read_text(encoding="utf-8")))
    write(SOURCE / "local_access_revision.json", {
        "date": "2026-11-07", "world": WORLD, "native_size": NATIVE, "game_size": GAME,
        "generator": "Outil imagegen intégré ; quatre retouches du détail existant, aucune recomposition.",
        "before_master_sha256": digest(work / "master_before.webp"), "master_sha256": digest(SOURCE / "map_detailed.webp"),
        "before_composition_sha256": digest(work / "composition_before.png"), "composition_sha256": digest(BASE / "composition.png"),
        "plan_sha256": digest(BASE / "plan.json"), "text_hash_convention": "UTF-8, fins de ligne LF",
        "before_tiles_sha256": [digest(work / p.name) for p in tiles], "tiles_sha256": [digest(p) for p in tiles],
        "patches": history, "mask_recipe": "Passage de DROITE : rectangle monde (3370,1660)–(3990,2190). Glace : rayon diamètre/2+50u. Abris : boîte native x±85,y−150..+45px. Fondu natif9px.",
        "west_waterfall_passage_identical_to_original": True,
        "changed_pixel_share": round(float(support.mean()), 5), "outside_patches_pixels_identical": True,
        "source_and_tiles_lossless": True, "collision_mask_created": False,
        "runtime_integrated": False, "navigation_or_combat_tested": False})
    old_recipe = json.loads((work / "detail_recipe_before.json").read_text(encoding="utf-8"))
    write(SOURCE / "detail_recipe.json", {"world": WORLD, "native_size": NATIVE, "game_size": GAME,
          "native_density": .75, "presentation_density": 2.25, "retained_master_sha256": digest(SOURCE / "map_detailed.webp"),
          "presentation": "Tuiles retenues préservées hors masques ; quatre dessins locaux réinsérés à ×3. Aucun nouvel agrandissement global.",
          "encoding": {"format": "WebP", "lossless": True, "method": 4}, "previous_presentation": old_recipe,
          "local_revision": "local_access_revision.json", "tiles_sha256": {p.name: digest(p) for p in tiles},
          "tile_bytes": [p.stat().st_size for p in tiles]})
    write(SOURCE / "collision_reference.json", {"reference": "docs/previews/silent-heart/reference_collisions.jpg",
          "sha256": digest(reference), "size": [1254, 836], "bytes": reference.stat().st_size,
          "world": WORLD, "world_units_per_pixel": 4, "whole_map": True, "crop": None,
          "source": "Tuiles finales retenues, carte entière, réduction Lanczos, JPEG85 4:4:4.",
          "tiles_sha256": [digest(p) for p in tiles], "expected_return": {"format": "PNG", "size": [1254, 836],
          "same_framing": True, "paint": "Obstacles, parois et gouffres bloquants ; chaussée enneigée, deux raccords et dix plaques de glace praticables."},
          "replaces_previous_reference": True, "collision_mask_created": False, "runtime_integrated": False})
    report = quality.check(tiles, *WORLD, BASE / "composition.png")
    write(PREVIEW / "qualite.json", report)
    assert report["ok"], "Qualité non conforme"
    print("LOCAL_REVISION_OK", round(float(support.mean()) * 100, 2), "percent changed support", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work", required=True, type=Path)
    apply(parser.parse_args().work)
