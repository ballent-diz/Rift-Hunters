"""Convertit les PNG préparés en WebP sans perte, sans retouche graphique."""
import argparse
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument("source", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
for name in ("cascade_ruins", "storm_highlands"):
    source = Image.open(args.source / (name + "-final.png")).convert("RGB")
    target = root / "assets" / "environments" / name / "map.webp"
    source.save(target, "WEBP", lossless=True, method=6)
    with Image.open(target) as check:
        assert check.convert("RGB").tobytes() == source.tobytes(), "Conversion avec perte"
    print(name, source.size, target.stat().st_size)
