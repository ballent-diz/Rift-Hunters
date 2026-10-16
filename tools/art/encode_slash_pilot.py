"""Encode sans retouche les 60 images natives du pilote de Taille fendante."""
from pathlib import Path
from PIL import Image

FOLDER = Path(__file__).resolve().parents[2] / "docs/previews/c5/pilot"

if __name__ == "__main__":
    images = sorted(FOLDER.glob("frame_[0-9][0-9].png"))
    if len(images) != 60:
        raise SystemExit("60 images attendues ; lancer c5_slash_pilot.tscn avec --capture.")
    frames = [Image.open(p).convert("RGB") for p in images]
    frames[0].save(FOLDER / "taille-fendante.webp", save_all=True, append_images=frames[1:],
                   duration=[33,33,34]*20, loop=0, lossless=True, method=3)
    print("Pilote : 2 secondes, 30 images/s, 1920 × 1080, encodage sans perte.")
