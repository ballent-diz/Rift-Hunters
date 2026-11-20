"""Prépare et importe les planches peintes des Rapiécés avec l'importeur du jeu."""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

import import_sheet
from build_shadows import measure
from sprite_source_tools import pack, split_source, write

ROOT = Path(__file__).resolve().parents[2]
INCOMING = ROOT / "assets/concepts/incoming"
FAMILY = {
    "biting_bobbin": (30, (72, 64), ()),
    "patch_mender": (43, (88, 64), ()),
    "veil_moth": (34, (88, 64), ()),
    "split_puppet": (42, (88, 72), ("spring_kick",)),
    "war_shuttle": (48, (96, 80), ("braced_shuttle", "loom_strike")),
    "shroud_spinner": (48, (96, 80), ("thread_gather", "shroud")),
    "tapestry_ram": (43, (104, 80), ("bow_and_ram", "fringe_bristle")),
}


def animation(name, sheet, rows, row, factor=1.0):
    return {"name": name, "source": sheet, "layout": "grid", "grid": [6, rows], "row": row,
            "frames": 6, "fps": 10 if name == "move" else 12, "loop": name == "move",
            "source_scale": round(factor, 8)}


def import_one(identifier, preview_dir):
    target, (width, height), techniques = FAMILY[identifier]
    elite = len(techniques) == 2
    hover = 8 if identifier == "veil_moth" else 0
    anchor = [width // 2, height - (6 if hover else 10)]
    folder = INCOMING / ("enemy." + identifier)
    names = ["move", "attack"] + (["death"] if elite else list(techniques))
    a, info_a = split_source(folder / "source/planche_A.png", len(names))
    base = sorted(p.height for p in a[:6])[3]
    pack(a, len(names), folder / "planche_A.webp")
    animations = [animation(name, "planche_A.webp", len(names), row) for row, name in enumerate(names)]
    sources = [info_a]
    scaled = [(pose, 1.0) for pose in a]
    if elite:
        b, info_b = split_source(folder / "source/planche_B.png", 2)
        factor = base / float(np.median([b[i].height for i in (0, 5, 6, 11)]))
        pack(b, 2, folder / "planche_B.webp")
        animations.extend(animation(name, "planche_B.webp", 2, row, factor)
                          for row, name in enumerate(techniques))
        sources.append(info_b)
        scaled.extend((pose, factor) for pose in b)
    for pose, factor in scaled:
        target = min(target, int((width - 5) * base / (pose.width * factor)),
                     int((anchor[1] - hover - 4) * base / (pose.height * factor)))
    assert target >= 26, (identifier, target)
    if hover:
        animations[0]["frame_offsets"] = [[0, y] for y in (0, -1, -2, -2, -1, 0)]
    job = {"visual_id": "enemy." + identifier, "cell": [width, height], "anchor": anchor,
           "scale": .5, "target_height": target, "status": "final", "background": "alpha",
           "colors": 32, "outline": False, "hover": hover, "preview_zoom": 2,
           "anchor_mode": "mass" if identifier in ("biting_bobbin", "veil_moth", "tapestry_ram") else "feet",
           "animations": animations, "aliases": {"idle": "move"}, "family": "Les Rapiécés"}
    if not elite:
        job["empty_animations"] = [{"name": "death", "fps": 12, "loop": False}]
    write(folder / "job.json", job)
    entry = import_sheet.run(str(folder / "job.json"), preview_dir=str(preview_dir))
    sheet = Image.open(ROOT / entry["sheet"].removeprefix("res://")).convert("RGBA")
    shifted = False
    for clip in animations:
        row = entry["animations"][clip["name"]]["row"]
        offsets = clip.get("frame_offsets", [[0, 0] for _ in range(6)])
        for i, offset in enumerate(offsets):
            box = sheet.crop((i * width, row * height, (i + 1) * width, (row + 1) * height)).getbbox()
            assert box, (identifier, clip["name"], i)
            dx = max(0, 2 - box[0]) - max(0, box[2] - width + 2)
            if dx:
                offset[0] += dx
                shifted = True
        clip["frame_offsets"] = offsets
    if shifted:
        write(folder / "job.json", job)
        entry = import_sheet.run(str(folder / "job.json"), preview_dir=str(preview_dir))
        sheet = Image.open(ROOT / entry["sheet"].removeprefix("res://")).convert("RGBA")
    pixels = np.array(sheet)
    assert len(np.unique(pixels[pixels[:, :, 3] > 0, :3], axis=0)) <= 32, identifier
    for clip in animations:
        row = entry["animations"][clip["name"]]["row"]
        for i in range(6):
            pose = sheet.crop((i * width, row * height, (i + 1) * width, (row + 1) * height))
            box = pose.getbbox()
            assert box and box[0] > 0 and box[1] > 0 and box[2] < width and box[3] < height, (identifier, clip, i, box)
    write(folder / "source/normalisation.json", {"planches": sources, "hauteur_cible": target})
    print(identifier, target, "px", len(animations) * 6, "poses", flush=True)
    return entry


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview-dir", type=Path, required=True)
    params = parser.parse_args()
    path = ROOT / "assets/asset_manifest.json"
    for identifier in FAMILY:
        entry = import_one(identifier, params.preview_dir)
        manifest = json.loads(path.read_text(encoding="utf-8"))
        entry_id = "enemy." + identifier
        manifest["entries"][entry_id]["shadow"] = measure(entry)
        assert manifest["entries"][entry_id]["shadow"], identifier
        path.write_text(json.dumps(manifest, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
