"""Conditionnement uniquement : sources peintes, réduction nearest et palette sans tramage."""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/concepts/incoming/material.outpost/source"
TARGET = ROOT / "draft3d/matter/outpost"
SLOTS = ["masonry", "wood", "roof", "iron", "canvas", "ice", "cliff"]


def main():
    image = Image.open(SOURCE / "materials.png").convert("RGB")
    report = {}
    for index, slot in enumerate(SLOTS + ["ground"]):
        if slot == "ground":
            tile = Image.open(SOURCE / "ground.png").convert("RGB")
            pixels, colors = 320, 12
        else:
            x, y = index % 3, index // 3
            tile = image.crop((round(x * image.width / 3) + 2, round(y * image.height / 3) + 2,
                               round((x + 1) * image.width / 3) - 2, round((y + 1) * image.height / 3) - 2))
            pixels, colors = 160, 12 if slot in ["masonry", "wood", "roof", "cliff"] else 6
        tile = tile.resize((pixels, pixels), Image.Resampling.NEAREST).quantize(
            colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
        tile.save(TARGET / (slot + ".png"))
        report[slot] = {"size": tile.size, "colors": len(tile.getcolors()), "texels_per_m": 40}
    (TARGET / "conditioning.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
