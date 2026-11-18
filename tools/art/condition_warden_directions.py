"""Calibre les poses peintes dos/face sur le Veilleur publié, sans interpoler les poses."""
from pathlib import Path

import numpy as np
from PIL import Image

from import_sheet import crop_alpha, place_in_cell, remove_background, split_frames

ROOT = Path(__file__).resolve().parents[2]
INCOMING = ROOT / "assets/concepts/incoming/player.threshold_warden"


def main():
    source = Image.open(INCOMING / "source/directions.png")
    clean = remove_background(source, "#0a1321", 30, 0, holes_min_area=1)
    names = ["idle_back", "walk_back", "idle_front", "walk_front"]
    frames = [[crop_alpha(frame) for frame in split_frames(clean, 6, "grid", [6, 4], row)]
              for row in range(4)]
    # Un facteur par vue, commun à l'idle et à la marche : aucune variation artificielle de taille.
    factors = [62 / sorted(f.height for f in frames[row])[3] for row in (0, 2)]
    for row, name in enumerate(names):
        strip = Image.new("RGBA", (672, 80))
        for column, frame in enumerate(frames[row]):
            factor = factors[row // 2]
            frame = frame.resize((round(frame.width * factor), round(frame.height * factor)),
                                 Image.Resampling.NEAREST)
            assert frame.width < 112 and frame.height < 77, (name, column, frame.size)
            strip.paste(Image.fromarray(place_in_cell(np.array(frame), (112, 80), (56, 74))),
                        (column * 112, 0))
        strip.save(INCOMING / (name + ".png"))


if __name__ == "__main__":
    main()
