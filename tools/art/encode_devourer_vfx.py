"""Encode les captures Godot natives en aperçus WebP animés, sans modifier le rendu."""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT.parent / "chapter2-generation/vfx-frames"
OUT = ROOT / "docs/previews/devourer-vfx"


if __name__ == "__main__":
    catalog = json.loads((ROOT / "assets/vfx/bosses/source_devourer/catalog.json").read_text(encoding="utf-8"))
    for spec in catalog:
        paths = sorted((SOURCE / spec["id"]).glob("*.png"))
        frames = [Image.open(path).convert("RGB") for path in paths]
        assert len(frames) in (24, 30), (spec["id"], len(frames))
        durations = [round(float(spec["duration"]) / 24 * 1000)] * len(frames)
        if len(frames) == 30:
            durations[:6] = [133] * 6
        frames[0].save(OUT / (spec["id"] + ".webp"), save_all=True,
                       append_images=frames[1:], duration=durations, loop=0, quality=94, method=3)
        print(spec["id"], len(frames), "captures")
