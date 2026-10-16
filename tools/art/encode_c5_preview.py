"""Encode les images capturées par Godot en aperçu WebP animé, sans retouche."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "docs/previews/c5"

if __name__ == "__main__":
    frames = [Image.open(p).convert("RGB") for p in sorted(FOLDER.glob("effects_[0-9][0-9].png"))]
    if len(frames) != 48:
        raise SystemExit("48 captures natives attendues ; lancer c5_preview.tscn d’abord.")
    # Durées alternées : 24 images par seconde, boucle de deux secondes.
    frames[0].save(FOLDER / "effects.webp", save_all=True, append_images=frames[1:],
                   duration=[42, 41, 42] * 16, loop=0, lossless=True, method=4)
    print("Aperçu animé : docs/previews/c5/effects.webp")
