#!/usr/bin/env python3
"""Conditionne les planches retenues du Glacier silencieux, puis utilise l'importeur commun.

Usage : python3 tools/art/package_chapter4.py /workspace/.rift-art [identifiant ...]
Les essais restent hors dépôt ; seuls les sources retenues et leurs recettes sont copiés.
"""
import hashlib
import json
from pathlib import Path
import shutil
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_sheet  # noqa: E402


def body_height(image, column, row, rows):
    frame = image.crop((round(column * image.width / 6), round(row * image.height / rows),
                        round((column + 1) * image.width / 6), round((row + 1) * image.height / rows)))
    mask = np.asarray(frame.convert("RGBA"))[:, :, 3] >= 128
    labels, count = ndimage.label(mask)
    if not count:
        raise ValueError("Pose de référence vide")
    sizes = np.bincount(labels.ravel())
    ys = np.nonzero(labels == 1 + int(np.argmax(sizes[1:])))[0]
    return int(ys.max() - ys.min() + 1)


def package(scratch, selected):
    plans = json.loads((scratch / "chapter4-plans.json").read_text())
    identifiers = list(dict.fromkeys(p["id"] for p in plans))
    for identifier in identifiers:
        if selected and identifier not in selected:
            continue
        group = [p for p in plans if p["id"] == identifier]
        meta = group[0]
        folder = ROOT / "assets/concepts/incoming" / meta["visual_id"]
        source = folder / "source"
        source.mkdir(parents=True, exist_ok=True)
        images = {}
        for p in group:
            path = scratch / "generated" / identifier / ("sheet_" + p["sheet"] + ".png")
            image = Image.open(path).convert("RGBA")
            if image.getchannel("A").getextrema()[0] != 0:
                raise ValueError(f"{identifier}/{p['sheet']} : alpha absent")
            images[p["sheet"]] = image
        reference = float(np.median([body_height(images["a"], c, 0, group[0]["rows"]) for c in range(6)]))
        animations, normalization, hashes = [], {}, {}
        for p in group:
            letter = p["sheet"]
            filename = "sheet_" + letter + ".png"
            # La première pose des techniques est une anticipation avec le corps complet.
            # Un seul facteur par planche, jamais de normalisation pose par pose.
            factor = 1.0 if letter == "a" else reference / float(np.median([
                body_height(images[letter], 0, row, p["rows"]) for row in range(len(p["animations"]))
            ]))
            normalization[filename] = round(factor, 6)
            shutil.copyfile(scratch / "generated" / identifier / filename, source / filename)
            (source / ("prompt_" + letter + ".txt")).write_text(p["prompt"] + "\n", encoding="utf-8")
            hashes[filename] = hashlib.sha256((source / filename).read_bytes()).hexdigest()
            for row, name in enumerate(p["animations"]):
                animations.append({"name": name, "source": "source/" + filename,
                                   "grid": [6, p["rows"]], "row": row, "frames": 6,
                                   "fps": 8 if name == "idle" else 10 if name == "move" else 12,
                                   "loop": name in ("idle", "move", "lit", "dim"),
                                   "source_scale": round(factor, 6)})
        boss = identifier == "nivorath"
        job = {"visual_id": meta["visual_id"], "cell": [512, 512] if boss else [256, 256],
               "anchor": [256, 480] if boss else [128, 238], "scale": 0.5,
               "target_height": meta["height"] * 2, "status": "final", "background": "alpha",
               "tolerance": 0, "colors": 32, "outline": True, "anchor_mode": "mass",
               "resample": "lanczos", "hover": meta["hover"], "isolate": True,
               "preview_zoom": 1, "icon_size": 128, "animations": animations,
               "aliases": {} if boss or identifier == "brazier" else {"idle": "move"}}
        if len(group) == 1 and identifier != "brazier":
            job["empty_animations"] = [{"name": "death", "fps": 12, "loop": False}]
        (folder / "job.json").write_text(json.dumps(job, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        (source / "SHA256.json").write_text(json.dumps(hashes, indent=2) + "\n")
        (source / "normalization.json").write_text(json.dumps(normalization, indent=2) + "\n")
        import_sheet.run(str(folder / "job.json"), preview_dir=str(scratch / "import-previews"))
        print(identifier, len(animations), "animations", normalization, flush=True)


if __name__ == "__main__":
    package(Path(sys.argv[1]), set(sys.argv[2:]))
