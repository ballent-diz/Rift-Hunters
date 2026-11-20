"""Conditionne les quatre planches peintes de l’Ourdisseur et les importe avec le pipeline du jeu."""
import argparse
from pathlib import Path
from statistics import median

import numpy as np
from PIL import Image

import import_sheet
from sprite_source_tools import pack, split_source, write

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "assets/concepts/incoming/boss.loom_devourer"
PLATES = {
    "A": ("idle", "move", "attack"),
    "B": ("warp_gate", "shuttle_reel"),
    "C": ("transform", "phase2_idle", "phase2_move"),
    "D": ("reverse_weave", "bobbin_throw", "death"),
}
LOOPS = {"idle": 7, "move": 9, "phase2_idle": 7, "phase2_move": 9}
CELL = (448, 304)
ANCHOR = (224, 280)


def fit_icon(sheet, path):
    pose = sheet.crop((0, 0, *CELL))
    pose = pose.crop(pose.getbbox())
    pose.thumbnail((58, 58), Image.Resampling.NEAREST)
    icon = Image.new("RGBA", (64, 64))
    icon.paste(pose, ((64 - pose.width) // 2, (64 - pose.height) // 2))
    icon.save(path)


def run(preview_dir):
    sources = {letter: split_source(FOLDER / "source" / f"planche_{letter}.png", len(clips))
               for letter, clips in PLATES.items()}
    # Les poses neutres calibrent les planches, jamais les attaques ni la carcasse.
    a, b, c, d = [sources[letter][0] for letter in PLATES]
    base = sorted(p.height for p in a[:6])[3]
    resting = (0, 5, 6, 11)
    c_factor = base / c[0].height
    phase2_height = median(p.height for p in c[6:12]) * c_factor
    factors = {"A": 1.0, "B": base / median(b[i].height for i in resting),
               "C": c_factor, "D": phase2_height / median(d[i].height for i in resting)}
    target = 238
    for letter, (poses, _) in sources.items():
        for pose in poses:
            scale = factors[letter] / base
            target = min(target, int((CELL[0] - 6) / (pose.width * scale)),
                         int((ANCHOR[1] - 4) / (pose.height * scale)))
    assert target >= 175, target
    animations = []
    for letter, names in PLATES.items():
        packed = f"planche_{letter}.webp"
        pack(sources[letter][0], len(names), FOLDER / packed)
        for row, name in enumerate(names):
            animations.append({"name": name, "source": packed, "layout": "grid", "grid": [6, len(names)],
                               "row": row, "frames": 6, "fps": LOOPS.get(name, 10), "loop": name in LOOPS,
                               "source_scale": round(factors[letter], 8)})
    job = {"visual_id": "boss.loom_devourer", "cell": CELL, "anchor": ANCHOR, "scale": .5, "target_height": target,
           "anchor_mode": "mass", "status": "final", "background": "alpha", "outline": False, "colors": 32,
           "preview_zoom": 1, "animations": animations, "family": "Les Rapiécés"}
    path = FOLDER / "job.json"
    write(path, job)
    entry = import_sheet.run(str(path), preview_dir=str(preview_dir))
    sheet_path = ROOT / entry["sheet"].removeprefix("res://")
    sheet = Image.open(sheet_path).convert("RGBA")
    pixels = np.asarray(sheet)
    assert len(np.unique(pixels[pixels[:, :, 3] > 0, :3], axis=0)) <= 32
    width, height = CELL
    bounds = {}
    for name, clip in entry["animations"].items():
        y = clip["row"] * height
        frames = [sheet.crop((i * width, y, (i + 1) * width, y + height)) for i in range(6)]
        boxes = [f.getbbox() for f in frames]
        assert len({f.tobytes() for f in frames}) >= 4, name
        assert all(b and b[0] >= 2 and b[1] >= 2 and b[2] <= width - 2 and b[3] <= height - 2
                   for b in boxes), (name, boxes)
        assert all(b[3] == ANCHOR[1] + 1 for b in boxes), (name, boxes)
        bounds[name] = boxes
    fit_icon(sheet, ROOT / entry["icon"].removeprefix("res://"))
    write(FOLDER / "source/normalisation.json", {"sources": [info for _, info in sources.values()],
          "facteurs": factors, "hauteur_cible": target, "cadres_finaux": bounds})
    print("L’Ourdisseur", target, "pixels au repos,", len(animations) * 6, "poses peintes.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview-dir", type=Path, required=True)
    run(parser.parse_args().preview_dir)
