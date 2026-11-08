#!/usr/bin/env python3
"""Découpe les poses réellement dessinées des Déchus puis appelle l'import standard.

Les originaux restent dans source/. Les planches normalisées ne redessinent rien :
alpha binaire, composantes par pose et rangement dans une grille sans découpe.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import import_sheet

ROOT = Path(__file__).resolve().parents[2]
INCOMING = ROOT / "assets/concepts/incoming"
IDS = ["fallen_militia", "corrupted_hound", "lantern_wraith", "fallen_crossbowman",
       "fallen_captain", "rift_herald", "cobble_golem"]
ELITES = IDS[4:]
TECHNIQUES = {"fallen_crossbowman": ["corrupted_bolt"],
              "fallen_captain": ["shield_wall", "rallying_cry"],
              "rift_herald": ["soul_link", "corruption_seal"],
              "cobble_golem": ["tunnel", "slab_armor"]}
TARGETS = dict(zip(IDS, [48, 32, 40, 46, 48, 50, 48]))


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def digest(path):
    content = path.read_bytes()
    if path.suffix in (".json", ".txt"):
        content = content.replace(b"\r\n", b"\n")
    return hashlib.sha256(content).hexdigest()


def split_source(path, rows):
    """Les composantes récupèrent aussi les pointes qui dépassent une limite de grille virtuelle."""
    source = Image.open(path).convert("RGBA")
    array = np.asarray(source).copy()
    opaque = array[:, :, 3] >= 128
    labels, _ = ndimage.label(opaque, np.ones((3, 3), bool))
    sizes = np.bincount(labels.ravel())
    boxes = ndimage.find_objects(labels)
    step_x, step_y = source.width / 6, source.height / rows
    groups = {}
    for label, box in enumerate(boxes, 1):
        if box is None or sizes[label] < 10:
            continue
        yy, xx = np.where(labels[box] == label)
        cx, cy = float(xx.mean()) + box[1].start, float(yy.mean()) + box[0].start
        col, row = min(5, int(cx / step_x)), min(rows - 1, int(cy / step_y))
        groups.setdefault((row, col), []).append((int(sizes[label]), label, box))
    poses, records = [], []
    for row in range(rows):
        for col in range(6):
            components = sorted(groups.get((row, col), []), reverse=True)
            assert components and components[0][0] >= 200, (path, row, col, components)
            main = components[0]
            # Les petits débris voulus sont conservés ; seuls les poussières et bouts de bord sont exclus.
            kept = [c for c in components if c[0] >= max(10, main[0] * .001)
                    and (c == main or (c[2][0].start > 0 and c[2][1].start > 0
                                      and c[2][0].stop < source.height and c[2][1].stop < source.width))]
            y0 = min(c[2][0].start for c in kept)
            y1 = max(c[2][0].stop for c in kept)
            x0 = min(c[2][1].start for c in kept)
            x1 = max(c[2][1].stop for c in kept)
            crop = array[y0:y1, x0:x1].copy()
            mask = np.isin(labels[y0:y1, x0:x1], [c[1] for c in kept])
            crop[:, :, 3] = np.where(mask, 255, 0)
            crop[~mask, :3] = 0
            poses.append(Image.fromarray(crop))
            records.append({"row": row, "column": col, "original_bounds": [x0, y0, x1, y1],
                            "components_kept": len(kept), "source_pixels": int(mask.sum())})
    return poses, {"source": path.name, "sha256": digest(path), "size": list(source.size),
                   "alpha_threshold": 128, "grid": [6, rows], "poses": records}


def pack(poses, rows, destination):
    side = max(max(p.width, p.height) for p in poses) + 32
    canvas = Image.new("RGBA", (side * 6, side * rows))
    for i, frame in enumerate(poses):
        canvas.paste(frame, ((i % 6) * side + (side - frame.width) // 2,
                            (i // 6 + 1) * side - 16 - frame.height))
    canvas.save(destination, lossless=True, exact=True, method=4)


def import_one(identifier, preview_dir):
    folder = INCOMING / ("enemy." + identifier)
    rows_a = 3 if identifier in ELITES or identifier == "fallen_crossbowman" else 2
    a, info_a = split_source(folder / "source/planche_A.png", rows_a)
    b, info_b = [], None
    if identifier in ELITES:
        b, info_b = split_source(folder / "source/planche_B.png", 2)
    reference_height = float(np.median([p.height for p in a[:6]]))
    # Une seule échelle par planche B, estimée sur ses retours en position de repos.
    source_scale_b = reference_height / float(np.median([b[i].height for i in (0, 5, 6, 11)])) if b else 1.0
    hover = 8 if identifier == "lantern_wraith" else 0
    anchor = [32, 58 if hover else 54]
    target = TARGETS[identifier]
    all_scaled = [(p, 1.0) for p in a] + [(p, source_scale_b) for p in b]
    while any(round(p.width * target / reference_height * scale) > 60
              or round(p.height * target / reference_height * scale) > anchor[1] - hover - 1
              for p, scale in all_scaled):
        target -= 1
    assert target >= 28, (identifier, target)
    pack(a, rows_a, folder / "planche_A.webp")
    if b:
        pack(b, 2, folder / "planche_B.webp")
    animations = [{"name": "move", "source": "planche_A.webp", "grid": [6, rows_a], "row": 0,
                   "frames": 6, "fps": 12 if identifier == "corrupted_hound" else 10, "loop": True},
                  {"name": "attack", "source": "planche_A.webp", "grid": [6, rows_a], "row": 1,
                   "frames": 6, "fps": 12, "loop": False}]
    if identifier == "fallen_crossbowman":
        animations.append({"name": "corrupted_bolt", "source": "planche_A.webp", "grid": [6, 3], "row": 2,
                           "frames": 6, "fps": 9, "loop": False})
    if identifier in ELITES:
        animations.append({"name": "death", "source": "planche_A.webp", "grid": [6, 3], "row": 2,
                           "frames": 6, "fps": 10, "loop": False})
        for row, name in enumerate(TECHNIQUES[identifier]):
            animations.append({"name": name, "source": "planche_B.webp", "grid": [6, 2], "row": row,
                               "source_scale": round(source_scale_b, 8), "frames": 6,
                               "fps": 9 if name in ["shield_wall", "soul_link"] else 12, "loop": False})
    if hover:
        animations[0]["frame_offsets"] = [[0, y] for y in (0, -1, -2, -1, 0, 1)]
    job = {"visual_id": "enemy." + identifier, "cell": [64, 64], "anchor": anchor, "scale": .5,
           "target_height": target, "status": "final", "background": "alpha", "colors": 32,
           "outline": False, "flip": False, "hover": hover,
           "anchor_mode": "mass" if identifier in ["corrupted_hound", "lantern_wraith", "cobble_golem"] else "feet",
           "animations": animations, "aliases": {"idle": "move"},
           "family": "Les Déchus", "chapter": 5,
           "integration": "Claude : comportements et données ; aucun gameplay modifié par ce lot."}
    if identifier not in ELITES:
        job["empty_animations"] = [{"name": "death", "fps": 12, "loop": False}]
    write(folder / "job.json", job)
    entry = import_sheet.run(str(folder / "job.json"), preview_dir=str(preview_dir))
    # Le rangement n'entame pas les arêtes : on décale seulement une pose collée à une limite horizontale.
    sheet = Image.open(ROOT / entry["sheet"].removeprefix("res://")).convert("RGBA")
    changed = False
    for animation in job["animations"]:
        offsets = animation.get("frame_offsets", [[0, 0] for _ in range(6)])
        offsets = [list(offset) for offset in offsets]
        row = entry["animations"][animation["name"]]["row"]
        for i in range(6):
            box = sheet.crop((i * 64, row * 64, (i + 1) * 64, (row + 1) * 64)).getbbox()
            assert box, (identifier, animation["name"], i)
            dx = max(0, 2 - box[0]) - max(0, box[2] - 62)
            if dx:
                offsets[i][0] += dx
                changed = True
        animation["frame_offsets"] = offsets
    write(folder / "job.json", job)
    if changed:
        entry = import_sheet.run(str(folder / "job.json"), preview_dir=str(preview_dir))
    write(folder / "source/normalization.json", {"sheets": [i for i in (info_a, info_b) if i],
          "packing": "Composantes alpha de chaque pose, grille carrée avec32px de marge, sans redessin.",
          "reference_height_source": reference_height, "source_scale_B": source_scale_b,
          "target_height": target, "world_height_base": target * .5, "native_cell": [64, 64],
          "text_hash_convention": "UTF-8, fins de ligne LF",
          "same_scale_through_each_animation": True, "death_and_tunnel_not_regrown": True})
    hashes = {p.name: digest(p) for p in sorted((folder / "source").iterdir()) if p.is_file() and p.name != "SHA256.json"}
    write(folder / "source/SHA256.json", hashes)
    print("IMPORTED", identifier, "target", target, "B-scale", round(source_scale_b, 4), flush=True)
    return {"visual_id": job["visual_id"], "source_sheets": 2 if b else 1,
            "painted_poses": len(a) + len(b), "job": str((folder / "job.json").relative_to(ROOT)).replace("\\", "/")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview-dir", type=Path, required=True)
    args = parser.parse_args()
    args.preview_dir.mkdir(parents=True, exist_ok=True)
    catalog = [import_one(identifier, args.preview_dir) for identifier in IDS]
    write(ROOT / "docs/art/DECHUS_CATALOGUE.json", catalog)


if __name__ == "__main__":
    main()
