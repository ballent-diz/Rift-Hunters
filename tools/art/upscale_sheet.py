#!/usr/bin/env python3
"""Rééchantillonne une feuille de sprites pour qu'elle ait la même densité de pixels que le décor peint.

  python3 tools/art/upscale_sheet.py object.altar_seal 2

Un objet posé sur une carte dessinée (2,25 pixels par unité) paraît flou si sa feuille en a deux fois moins : le
filtre linéaire l'étire à l'écran. L'outil agrandit la feuille d'un facteur entier (Lanczos, alpha prémultiplié, puis
masque flou léger pour retrouver des contours nets) et met à jour le manifeste : cellule et ancre multipliées, échelle
divisée. La taille en jeu ne change pas. À relancer après chaque nouvelle cuisson de la feuille.
Nécessite Pillow.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "asset_manifest.json"
# Masque flou après agrandissement : rend aux contours la netteté du décor sans halo visible.
SHARPEN = ImageFilter.UnsharpMask(radius=1.2, percent=90, threshold=2)


def upscale(image, factor):
    size = (image.width * factor, image.height * factor)
    big = image.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")
    rgb = big.convert("RGB").filter(SHARPEN)
    rgb.putalpha(big.getchannel("A"))
    return rgb


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    entry_id, factor = sys.argv[1], int(sys.argv[2])
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entry = manifest["entries"][entry_id]
    path = ROOT / entry["sheet"].removeprefix("res://")
    sheet = upscale(Image.open(path), factor)
    sheet.save(path, optimize=True)
    entry["cell"] = [v * factor for v in entry["cell"]]
    entry["anchor"] = [v * factor for v in entry["anchor"]]
    entry["scale"] = round(float(entry.get("scale", 1.0)) / factor, 4)
    MANIFEST.write_text(json.dumps(manifest, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{entry_id} : {sheet.width} x {sheet.height}, cellule {entry['cell']}, échelle {entry['scale']}")


if __name__ == "__main__":
    main()
