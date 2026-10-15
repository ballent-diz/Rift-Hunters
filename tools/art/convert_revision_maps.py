"""Convertit les trois panneaux contigus en WebP sans perte, sans retouche graphique."""
import argparse
from pathlib import Path
from PIL import Image
p = argparse.ArgumentParser()
p.add_argument("source", type=Path)
args = p.parse_args()
root = Path(__file__).resolve().parents[2]
for name in ("cascade_ruins", "storm_highlands"):
    for index in range(3):
        source = Image.open(args.source / f"{name}_{index}.png").convert("RGB")
        filename = "map.webp" if index == 0 else f"map_{index}.webp"
        target = root / "assets" / "environments" / name / filename
        source.save(target, "WEBP", lossless=True, method=6)
        with Image.open(target) as check:
            assert check.convert("RGB").tobytes() == source.tobytes(), "Conversion avec perte"
        print(name, index, source.size, target.stat().st_size, flush=True)
