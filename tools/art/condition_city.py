"""Découpe et quantifie les sources peintes de la cité, sans dessiner de nouvelle matière."""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
INCOMING = ROOT / "assets/concepts/incoming/material.city"
OUT = ROOT / "draft3d/matter/city"
PANELS = {"masonry": (0, 96), "stone": (1, 160), "wood": (2, 64), "iron": (3, 160),
          "bronze": (4, 160), "paving": (6, 120), "ground": (7, 320)}


def main():
    source = Image.open(INCOMING / "source/materials.png").convert("RGB")
    report = {}
    for slot, (index, pixels) in PANELS.items():
        if slot == "ground":
            tile = Image.open(INCOMING / "source/ground.png").convert("RGB")
        else:
            x, y = index % 4, index // 4
            tile = source.crop((round(x * source.width / 4) + 2, round(y * source.height / 2) + 2,
                                round((x + 1) * source.width / 4) - 2, round((y + 1) * source.height / 2) - 2))
        colors = 16 if slot == "ground" else 12
        tile = tile.resize((pixels, pixels), Image.Resampling.NEAREST).quantize(
            colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
        tile.save(OUT / (slot + ".png"))
        report[slot] = {"source_panel": index if slot != "ground" else None,
                        "pixels": pixels, "colors": len(tile.getcolors()), "texels_per_m": 40}
    (OUT / "conditioning.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("CITY_TILES", len(report))


if __name__ == "__main__":
    main()
