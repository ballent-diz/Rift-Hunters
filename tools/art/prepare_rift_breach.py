#!/usr/bin/env python3
"""Découpe et importe la planche générée de la faille (8 colonnes, 3 animations)."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
from prepare_c8_sheet import separator
import import_sheet

ROOT = Path(__file__).resolve().parents[2]


def main():
    folder = ROOT / "assets/concepts/incoming/enemy.rift_breach"
    image = Image.open(folder / "source/sheet.png").convert("RGBA")
    data = np.array(image).astype(int)
    mask = np.abs(data[:, :, :3]-[0, 214, 72]).max(axis=2) > 45
    width, height = image.size
    rows = [0] + [separator(mask.sum(axis=1), round(height*i/3), height//18) for i in range(1, 3)] + [height]
    job_path = folder / "job.json"
    job = json.loads(job_path.read_text(encoding="utf-8"))
    for row, animation in enumerate(job["animations"]):
        top, bottom = rows[row:row+2]
        activity = mask[top:bottom].sum(axis=0)
        columns = [0] + [separator(activity, round(width*i/8), width//32) for i in range(1, 8)] + [width]
        image.crop((0, top, width, bottom)).save(folder / animation["source"])
        animation["ranges"] = [[columns[i], columns[i+1]] for i in range(8)]
    job_path.write_text(json.dumps(job, indent=2)+"\n", encoding="utf-8")
    import_sheet.run(str(job_path), preview_dir=str(ROOT / "docs/previews/a3-failles"))
    print("Faille : 24 poses importées.")


if __name__ == "__main__":
    main()
