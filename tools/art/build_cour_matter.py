#!/usr/bin/env python3
"""Conditionne les images peintes retenues : palette commune, tuiles périodiques, cellules ancrées.

Les sources bitmap sont produites avec imagegen ; ce script ne dessine pas de textures de remplacement.
Usage : python tools/art/build_cour_matter.py <atlas_peint> <planche_details> <pierres_neutres>
"""
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "draft3d/matter/cour"
NAMES = ["paving", "stone", "moss", "masonry", "oak", "split_oak", "iron", "bronze",
         "burgundy", "indigo", "rubble", "earth", "corrupt_stone", "cracks", "limestone", "algae"]
DETAILS = ["grass_olive", "grass_broad", "grass_dry", "fern", "rubble", "slate", "brick", "gravel",
           "puddle", "damp", "leaves_dry", "leaves_green", "root_moss", "vine_wall", "ivy", "root_dry",
           "web_round", "web_corner", "skull", "bones", "crack_thin", "crack_branch", "corruption", "veins"]
TARGETS = ["151522", "242435", "333344", "454553", "575969", "6b707c", "858b96", "a2a6a9",
           "28242b", "3e3030", "55413b", "6e5548", "8c7057", "ad906d", "1d302c", "2b4535",
           "405c3b", "587348", "78905a", "292039", "432d52", "61436d", "86518b", "b768a2",
           "3c454d", "56646d", "7b8d91", "aab7ad", "927748", "c0a36d", "c5c6b1", "e0d9bd"]


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def retain_source(source, target):
    if Path(source).resolve() != target.resolve():
        shutil.copyfile(source, target)


def reference_palette():
    paths = ["assets/sprites/players/hunter/hunter_sheet.png",
             "assets/sprites/monsters/mossback/mossback_sheet.png",
             "assets/sprites/monsters/thornweave/thornweave_sheet.png",
             "assets/sprites/monsters/stormshell/stormshell_sheet.png",
             "assets/sprites/enemies/char_golem/char_golem_sheet.png",
             "assets/sprites/enemies/cinder_knight/cinder_knight_sheet.png",
             "assets/sprites/enemies/skitterling/skitterling_sheet.png"]
    pixels = []
    for path in paths:
        im = np.asarray(Image.open(ROOT / path).convert("RGBA"))
        pixels.append(im[im[:, :, 3] > 220, :3])
    colors, counts = np.unique(np.concatenate(pixels), axis=0, return_counts=True)
    candidates = colors[counts >= 3].astype(np.int32)
    picked = []
    for color in TARGETS:
        target = np.array([int(color[i:i + 2], 16) for i in (0, 2, 4)])
        order = np.argsort(np.sum((candidates - target) ** 2, axis=1))
        for index in order:
            value = tuple(int(v) for v in candidates[index])
            if value not in picked:
                picked.append(value)
                break
    return picked, paths


def periodic_edges(image, width=8):
    """Accorde les seules marges avant quantification ; les bords opposés sont identiques au texel près."""
    a = np.asarray(image.convert("RGB"), dtype=np.float32).copy()
    for axis in (0, 1):
        a = np.swapaxes(a, 0, axis)
        for i in range(width):
            mix = 0.5 * (1.0 - i / width) ** 2
            left, right = a[i].copy(), a[-1 - i].copy()
            a[i] = left * (1 - mix) + right * mix
            a[-1 - i] = right * (1 - mix) + left * mix
        a = np.swapaxes(a, 0, axis)
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)))


def main(atlas_path, details_path, stone_path):
    palette, references = reference_palette()
    pal = Image.new("P", (1, 1))
    pal.putpalette([v for rgb in palette for v in rgb] + [0] * (768 - len(palette) * 3))
    OUT.mkdir(parents=True, exist_ok=True)
    write_json(OUT / "palette.json", {"colors": ["#%02x%02x%02x" % c for c in palette],
                                    "sampled_from": references, "texel_m": 0.025,
                                    "hunter_texel_m": 0.02405, "tile_size": 160, "tile_span_m": 4.0})
    atlas = Image.open(atlas_path).convert("RGB")
    stone_atlas = Image.open(stone_path).convert("RGB")
    final = Image.new("RGB", (640, 640))
    for i, name in enumerate(NAMES):
        x, y = i % 4, i // 4
        source_x, source_y = (2, 3) if name == "paving" else (x, y)
        image, divisions = atlas, 4
        if name in ["paving", "stone", "moss", "masonry", "rubble", "cracks", "limestone", "algae"]:
            image, divisions = stone_atlas, 2
            source_x, source_y = ((1, 0) if name in ["paving", "limestone"] else
                                  ((1, 1) if name in ["moss", "algae"] else (0, 0)))
        tile = image.crop((round(source_x * image.width / divisions) + 4,
                           round(source_y * image.height / divisions) + 4,
                           round((source_x + 1) * image.width / divisions) - 4,
                           round((source_y + 1) * image.height / divisions) - 4))
        tile = periodic_edges(tile.resize((160, 160), Image.Resampling.NEAREST))
        tile_palette = pal
        if name in ["paving", "stone", "masonry", "rubble", "cracks", "limestone"]:
            # Sol calme : la finesse vient de la matière, pas de joints noirs qui concurrencent les sprites.
            indices = [3, 4, 5, 15, 17] if name in ["paving", "limestone"] else [3, 4, 15, 16, 17]
            ramp = [palette[k] for k in indices]
            tile_palette = Image.new("P", (1, 1))
            tile_palette.putpalette([v for rgb in ramp for v in rgb] + list(ramp[-1]) * (256 - len(ramp)))
        tile = tile.quantize(palette=tile_palette, dither=Image.Dither.NONE).convert("RGB")
        (OUT / "textures").mkdir(exist_ok=True)
        tile.save(OUT / "textures" / f"{name}.png")
        final.paste(tile, (x * 160, y * 160))
        a = np.asarray(tile)
        assert np.array_equal(a[0], a[-1]) and np.array_equal(a[:, 0], a[:, -1]), name
    final.save(OUT / "materials_atlas.png")
    source = ROOT / "assets/concepts/incoming/material.cour_veilleurs"
    previous_job = json.loads((source / "job.json").read_text(encoding="utf-8")) if (source / "job.json").exists() else {}
    (source / "source").mkdir(parents=True, exist_ok=True)
    retain_source(atlas_path, source / "source/atlas_matieres.png")
    retain_source(stone_path, source / "source/pierres_neutres.png")
    if (source / "atlas.png").exists():
        (source / "atlas.png").unlink()
    write_json(source / "job.json", {"visual_id": "material.cour_veilleurs", "status": "wip",
               "kind": "material_atlas", "source": ["source/atlas_matieres.png", "source/pierres_neutres.png"],
               "output": "res://draft3d/matter/cour/materials_atlas.png", "grid": [4, 4], "cell": [160, 160],
               "colors": 32, "generated_with": "imagegen", "neutral_albedo": True,
               "conditioning": "nearest, periodic edge matching (8 texels), shared sprite-sampled palette",
               "tile_names": NAMES})
    if "ground" in previous_job:
        job_path = source / "job.json"
        job = json.loads(job_path.read_text(encoding="utf-8"))
        job["ground"] = previous_job["ground"]
        job["source"].append("source/terrain.png")
        write_json(job_path, job)
    details = Image.open(details_path).convert("RGBA")
    shared = ROOT / "assets/concepts/incoming/planches_communes/cour_details/source"
    shared.mkdir(parents=True, exist_ok=True)
    retain_source(details_path, shared / "planche.png")
    contact = Image.new("RGBA", (4 * 64, 6 * 64))
    definitions = []
    manifest_path = ROOT / "assets/asset_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for i, name in enumerate(DETAILS):
        if name == "vine_wall":
            continue  # Le dessin contient un morceau de mur : refusé pour ne pas ajouter de faux obstacle.
        x, y = i % 4, i // 4
        tile = details.crop((x * details.width // 4, y * details.height // 6,
                             (x + 1) * details.width // 4, (y + 1) * details.height // 6))
        tile = tile.resize((64, 64), Image.Resampling.NEAREST)
        alpha = np.asarray(tile.getchannel("A"))
        rgb = tile.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
        rgb.putalpha(Image.fromarray(np.uint8(alpha >= 128) * 255))
        box = rgb.getbbox()
        assert box and box[2] > box[0] and box[3] > box[1], name
        # Pied fixe, sans changement d'échelle propre à chaque objet.
        placed = Image.new("RGBA", (64, 64))
        content = rgb.crop(box)
        placed.paste(content, (32 - content.width // 2, 60 - content.height), content)
        visual_id = "object.cour_" + name
        folder = ROOT / "assets/concepts/incoming" / visual_id
        folder.mkdir(parents=True, exist_ok=True)
        placed.save(folder / "idle.png")
        job = {"visual_id": visual_id, "cell": [64, 64], "anchor": [32, 60], "scale": 0.5,
               "status": "wip", "background": "alpha", "keep_size": True, "registered_cells": True,
               "colors": 32, "outline": False, "generated_with": "imagegen", "collision": False,
               "animations": [{"name": "idle", "source": "idle.png", "frames": 1, "fps": 1, "loop": True}]}
        write_json(folder / "job.json", job)
        target = OUT / "details" / f"{name}.png"
        target.parent.mkdir(exist_ok=True)
        placed.save(target)
        upright = name.startswith("grass") or name in ("fern", "ivy")
        definitions.append({"id": visual_id, "name": name, "upright": upright})
        manifest["entries"][visual_id] = {"status": "wip", "kind": "environment_detail",
            "imported_from": str((folder / "job.json").relative_to(ROOT)).replace("\\", "/"),
            "sheet": "res://" + str(target.relative_to(ROOT)).replace("\\", "/"),
            "cell": [64, 64], "anchor": [32, 60], "scale": 0.5, "filter": "nearest",
            "animations": {"idle": {"row": 0, "frames": 1, "fps": 1, "loop": True}}}
        contact.paste(placed, (x * 64, y * 64), placed)
    contact.save(OUT / "details_atlas.png")
    write_json(OUT / "details.json", definitions)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    ignore = ROOT / "assets/concepts/incoming/.gdignore"
    ignore.parent.mkdir(parents=True, exist_ok=True)
    ignore.touch()
    print(f"Palette : {len(palette)} couleurs ; 16 textures périodiques ; {len(definitions)} détails ancrés.")


if __name__ == "__main__":
    main(*sys.argv[1:4])
