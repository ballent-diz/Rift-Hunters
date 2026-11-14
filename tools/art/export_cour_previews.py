#!/usr/bin/env python3
"""Exporte les captures natives en aperçus WebP et compose une comparaison au pixel écran réel."""
import argparse
import shutil
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--smoke", type=Path)
    parser.add_argument("--out", type=Path, default=ROOT / "docs/previews/matiere-cour-veilleurs")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for name in ["terrasse", "escaliers", "abris", "entrepots"]:
        for label, folder in [("avant", args.before), ("apres", args.after)]:
            image = Image.open(folder / f"{name}.png").convert("RGB")
            assert image.width <= 1600
            image.save(args.out / f"{name}_{label}.webp", lossless=True, method=6)
    # Découpage central sans redimensionnement : le Chasseur conserve exactement ses pixels écran.
    compare = Image.new("RGB", (1600, 632), "#171826")
    for x, label, folder in [(0, "AVANT", args.before), (800, "APRES - MATIERE SEULE", args.after)]:
        image = Image.open(folder / "escaliers.png").convert("RGB").crop((400, 220, 1200, 820))
        compare.paste(image, (x, 32))
        ImageDraw.Draw(compare).text((x + 16, 10), label, fill="white")
    compare.save(args.out / "comparaison.webp", lossless=True, method=6)
    shutil.copyfile(args.report, args.out / "controle_geometrie.json")
    if args.smoke:
        Image.open(args.smoke).convert("RGB").save(args.out / "partie_12s.webp", lossless=True, method=6)
    print(f"Aperçus exportés : {args.out}")


if __name__ == "__main__":
    main()
