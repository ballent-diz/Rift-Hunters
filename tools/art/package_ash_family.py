"""Prépare les jobs d’import des Calcinés depuis leurs sources générées, sans gameplay."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
SPECS = {
    "ash_hound": ("Chien de suie", "Soot Hound", "normal", 38, ["move", "attack", "leap"]),
    "char_golem": ("Golem de charbon", "Char Golem", "normal", 40, ["move", "attack"]),
    "smoke_wisp": ("Feu-fumée", "Smoke Wisp", "normal", 36, ["move", "attack"]),
    "pyre_brute": ("Brute du bûcher", "Pyre Brute", "elite", 49, ["move", "attack", "death", "pyre_slam", "blazing_rage"]),
    "ashen_widow": ("Veuve de cendre", "Ashen Widow", "elite", 46, ["move", "attack", "death", "lay_eggs", "soot_web"]),
    "cinder_knight": ("Chevalier calciné", "Cinder Knight", "elite", 50, ["move", "attack", "death", "charge", "spinning_slash"]),
}


def package(scratch):
    for identifier, (fr, en, tier, height, names) in SPECS.items():
        folder = REPO / "assets/concepts/incoming" / ("enemy." + identifier)
        source = folder / "source"
        source.mkdir(parents=True, exist_ok=True)
        incoming = scratch / identifier
        metadata_path = incoming / ("metadata.json" if tier == "elite" else "generation.json")
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        (source / "generation.json").write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        animations, hashes = [], []
        sheets = [("a", names[:3], 3), ("b", names[3:], 2)] if tier == "elite" else [("", names, len(names))]
        for label, rows, count in sheets:
            filename = f"sheet_{label}.png" if label else "sheet.png"
            shutil.copyfile(incoming / filename, source / filename)
            prompt_file = f"prompt_{label}.txt" if label else "prompt.txt"
            shutil.copyfile(incoming / prompt_file, source / prompt_file)
            hashes.append(hashlib.sha256((source / filename).read_bytes()).hexdigest() + "  " + filename)
            image = Image.open(source / filename).convert("RGBA")
            for row, name in enumerate(rows):
                image.crop((0, round(row * image.height / count), image.width,
                            round((row + 1) * image.height / count))).save(folder / (name + ".png"))
                animations.append({"name": name, "source": name + ".png", "sheet_source": "source/" + filename,
                                   "source_row": row, "frames": 6, "fps": 10 if name == "move" else 12,
                                   "loop": name == "move", "layout": "grid", "grid": [6, 1]})
        (source / "SHA256.txt").write_text("\n".join(hashes) + "\n", encoding="utf-8")
        original = metadata.get("sheet_a", metadata)
        references = original.get("references", metadata.get("references", []))
        job = {"id": identifier, "fr": fr, "en": en, "tier": tier, "height": height,
               "description": metadata.get("description", original.get("description", fr)),
               "prompt": original.get("prompt", (source / ("prompt_a.txt" if tier == "elite" else "prompt.txt")).read_text(encoding="utf-8")),
               "references": references, "visual_id": "enemy." + identifier, "cell": [256, 256],
               "anchor": [128, 238], "scale": 0.5, "target_height": height * 2,
               "status": "wip", "background": "alpha", "tolerance": 0, "colors": 32,
               "outline": True, "resample": "lanczos", "anchor_mode": "mass", "isolate": True,
               "hover": 10 if identifier == "smoke_wisp" else 0, "icon_size": 128, "preview_zoom": 2,
               "animations": animations,
               "aliases": {"idle": "move"}}
        if tier == "normal":
            job["empty_animations"] = [{"name": "death", "fps": 12, "loop": False}]
        (folder / "job.json").write_text(json.dumps(job, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(identifier, len(animations), "animations")


if __name__ == "__main__":
    package(Path(sys.argv[1]).resolve())
