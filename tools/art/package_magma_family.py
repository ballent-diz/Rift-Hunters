"""Conditionne les sources des Enfants du magma pour le pipeline commun, sans gameplay."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SPECS = {
    "magma_mite": ("Acarien de magma", "Magma Mite", "normal", 30, ["move", "attack"]),
    "lava_lurker": ("Rôdeur de lave", "Lava Lurker", "normal", 40, ["move", "attack", "plunge"]),
    "obsidian_brute": ("Brute d’obsidienne", "Obsidian Brute", "normal", 42, ["move", "attack"]),
    "ember_spitter": ("Cracheur de braise", "Ember Spitter", "normal", 36, ["move", "attack"]),
    "caldera_titan": ("Titan de caldeira", "Caldera Titan", "elite", 50,
                      ["move", "attack", "death", "eruption", "open_crater"]),
    "flame_wyrmling": ("Wyvernette de flammes", "Flame Wyrmling", "elite", 48,
                        ["move", "attack", "death", "flame_breath", "dive"]),
    "slag_matron": ("Matrone des scories", "Slag Matron", "elite", 47,
                    ["move", "attack", "death", "brood", "slag_molt"]),
}


def body_height(image, column=0, row=0, rows=3):
    frame = image.crop((round(column * image.width / 6), round(row * image.height / rows),
                        round((column + 1) * image.width / 6), round((row + 1) * image.height / rows)))
    mask = np.array(frame.convert("RGBA"))[:, :, 3] >= 128
    labels, _ = ndimage.label(mask)
    sizes = np.bincount(labels.ravel())
    main = 1 + int(np.argmax(sizes[1:]))
    ys, _ = np.where(labels == main)
    return int(ys.max() - ys.min() + 1)


def package(scratch):
    for identifier, (fr, en, tier, height, names) in SPECS.items():
        incoming = scratch / identifier
        folder = ROOT / "assets/concepts/incoming" / ("enemy." + identifier)
        source = folder / "source"
        source.mkdir(parents=True, exist_ok=True)
        metadata = json.loads((incoming / ("metadata.json" if tier == "elite" else "generation.json")).read_text(encoding="utf-8"))
        hashes = []
        for original in incoming.iterdir():
            if original.suffix.lower() not in (".png", ".txt", ".json"):
                continue
            shutil.copyfile(original, source / original.name)
            if original.suffix.lower() == ".png":
                hashes.append(hashlib.sha256(original.read_bytes()).hexdigest() + "  " + original.name)
        first = Image.open(source / ("sheet_a.png" if tier == "elite" else "sheet.png")).convert("RGBA")
        count = 3 if tier == "elite" else len(names)
        reference = sorted(body_height(first, column, rows=count) for column in range(6))[3]
        animations, normalizations = [], {}
        sheets = [("sheet_a.png", names[:3], 3), ("sheet_b.png", names[3:], 2)] if tier == "elite" else [("sheet.png", names, count)]
        for filename, rows, row_count in sheets:
            image = Image.open(source / filename).convert("RGBA")
            assert image.getchannel("A").getextrema()[0] == 0, identifier + " : alpha absent"
            factor = 1.0
            if filename == "sheet_b.png":
                stances = sorted(body_height(image, 0, row, rows=row_count) for row in range(row_count))
                factor = reference / max(1, stances[len(stances) // 2])
            normalizations[filename] = factor
            for row, name in enumerate(rows):
                strip = image.crop((0, round(row * image.height / row_count), image.width,
                                    round((row + 1) * image.height / row_count)))
                if factor != 1.0:
                    strip = strip.resize((round(strip.width * factor), round(strip.height * factor)), Image.Resampling.LANCZOS)
                strip.save(folder / (name + ".png"))
                animation = {"name": name, "source": name + ".png", "sheet_source": "source/" + filename,
                             "source_row": row, "source_scale": factor, "frames": 6,
                             "fps": 10 if name == "move" else 12, "loop": name == "move",
                             "layout": "grid", "grid": [6, 1]}
                if name == "dive":
                    animation["frame_offsets"] = [[0, value] for value in (0, -22, -48, -56, -28, 0)]
                animations.append(animation)
        job = {"id": identifier, "fr": fr, "en": en, "tier": tier, "height": height,
               "description": metadata["description"], "mode": "builtin-imagegen",
               "prompt": (source / ("prompt_a.txt" if tier == "elite" else "prompt.txt")).read_text(encoding="utf-8"),
               "references": ["assets/" + p.replace("\\", "/").split("/assets/", 1)[-1] for p in metadata["references"][:3]],
               "visual_id": "enemy." + identifier, "cell": [256, 256], "anchor": [128, 238],
               "scale": 0.5, "target_height": height * 2, "status": "wip", "background": "alpha",
               "tolerance": 0, "colors": 32, "outline": True, "resample": "lanczos",
               "anchor_mode": "mass", "isolate": True, "hover": 6 if identifier == "flame_wyrmling" else 0,
               "icon_size": 128, "preview_zoom": 2, "animations": animations, "aliases": {"idle": "move"}}
        if tier == "normal":
            job["empty_animations"] = [{"name": "death", "fps": 12, "loop": False}]
        (folder / "job.json").write_text(json.dumps(job, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        (source / "SHA256.txt").write_text("\n".join(hashes) + "\n", encoding="utf-8")
        (source / "normalization.json").write_text(json.dumps(normalizations, indent=2) + "\n", encoding="utf-8")
        print(identifier, len(animations), "animations", normalizations, flush=True)


if __name__ == "__main__":
    package(Path(sys.argv[1]).resolve())
