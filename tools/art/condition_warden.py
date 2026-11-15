"""Conditionne les planches peintes du Veilleur, sans dessiner ni interpoler de poses."""
import json
from pathlib import Path

import numpy as np
from PIL import Image

from import_sheet import crop_alpha, isolate_frame, place_in_cell, remove_background, run, split_frames
from build_shadows import measure

ROOT = Path(__file__).resolve().parents[2]
INCOMING = ROOT / "assets/concepts/incoming/player.threshold_warden"


def main():
    source_a = remove_background(Image.open(INCOMING / "source/A.png"), "alpha", 0)
    source_b = remove_background(Image.open(INCOMING / "source/B.png"), "alpha", 0)
    rows = []
    for source, grid, row, count in [(source_a, [7, 3], 0, 6), (source_a, [7, 3], 1, 6),
                                     (source_a, [7, 3], 2, 7), (source_b, [7, 2], 0, 7),
                                     (source_b, [7, 2], 1, 6)]:
        rows.append([crop_alpha(isolate_frame(f)) for f in split_frames(source, count, "grid", grid, row)])
    heights = sorted(f.height for f in rows[0])
    base_factor = 62 / heights[len(heights) // 2]
    # Deux planches distinctes : calibrer B sur ses poses neutres, sans changer les proportions des poses de chute.
    b_height = (rows[3][0].height + rows[3][-1].height) / 2
    factors = [base_factor] * 3 + [62 / b_height] * 2
    definitions = [("idle", 7, True), ("move", 10, True), ("attack", 18, False),
                   ("hurt", 16, False), ("death", 8, False)]
    prepared = Image.new("RGBA", (7 * 112, 5 * 80))
    for row, frames in enumerate(rows):
        for column, frame in enumerate(frames):
            factor = factors[row]
            frame = frame.resize((round(frame.width * factor), round(frame.height * factor)), Image.Resampling.NEAREST)
            assert frame.width <= 110 and frame.height <= 76, (row, column, frame.size)
            cell = Image.fromarray(place_in_cell(np.array(frame), (112, 80), (56, 74)))
            prepared.paste(cell, (column * 112, row * 80))
    prepared.save(INCOMING / "registered.png")
    job = {
        "visual_id": "player.threshold_warden", "cell": [112, 80], "anchor": [56, 74], "scale": 0.65,
        "keep_size": True, "registered_cells": True, "background": "alpha", "colors": 48,
        "outline": False, "status": "wip", "animations": [], "aliases": {"dash": "attack"},
        "generated_with": "imagegen", "sources": ["source/A.png", "source/B.png"],
        "reference": "player.hunter", "source_b_reference": "source/A.png",
        "prompts": "prompts.json",
        "conditioning": "tools/art/condition_warden.py", "preview_zoom": 3,
    }
    for row, (name, fps, loop) in enumerate(definitions):
        job["animations"].append({"name": name, "source": "registered.png", "frames": len(rows[row]),
                                  "fps": fps, "loop": loop, "layout": "grid", "grid": [7, 5], "row": row})
    (INCOMING / "job.json").write_text(json.dumps(job, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    output = ROOT.parent / "Rift-Hunters-matiere-travail/warden"
    output.mkdir(parents=True, exist_ok=True)
    entry = run(str(INCOMING / "job.json"), preview_dir=str(output))
    entry["shadow"] = measure(entry)
    path = ROOT / "assets/asset_manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest["entries"][job["visual_id"]] = entry
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    print(json.dumps(entry, indent=2))


if __name__ == "__main__":
    main()
