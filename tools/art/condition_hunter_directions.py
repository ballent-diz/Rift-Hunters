"""Calibre les quatre bandes peintes du Chasseur original, sans inventer de poses."""
from pathlib import Path

import numpy as np
from PIL import Image

from import_sheet import crop_alpha, place_in_cell, remove_background, split_frames

ROOT = Path(__file__).resolve().parents[2]
INCOMING = ROOT / "assets/concepts/incoming/player.hunter"


def main():
    names = ["idle_back", "walk_back", "idle_front", "walk_front"]
    rows = []
    for name in names:
        source = remove_background(Image.open(INCOMING / "source" / (name + ".png")),
                                   "#0a1321", 22, 0, holes_min_area=1)
        rows.append([crop_alpha(frame) for frame in split_frames(source, 6, "grid", [6, 1], 0)])
    factors = [64 / sorted(frame.height for frame in rows[row])[3] for row in (0, 2)]
    for row, name in enumerate(names):
        strip = Image.new("RGB", (576, 80), "#0a1321")
        for column, frame in enumerate(rows[row]):
            factor = factors[row // 2]
            frame = frame.resize((round(frame.width * factor), round(frame.height * factor)),
                                 Image.Resampling.NEAREST)
            assert frame.width < 94 and frame.height < 77, (name, column, frame.size)
            cell = Image.fromarray(place_in_cell(np.array(frame), (96, 80), (48, 74)))
            strip.paste(cell, (column * 96, 0), cell)
        strip.save(INCOMING / (name + ".png"))


if __name__ == "__main__":
    main()
