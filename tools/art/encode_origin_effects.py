#!/usr/bin/env python3
"""Exporte les GIF C5-ter à l'échelle native, avec la durée propre de chaque effet."""
import argparse
import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/previews/c5-echos-origine"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--frames", required=True, type=Path)
    parser.add_argument("--only", help="Réexporter un seul Écho après une retouche ciblée.")
    args = parser.parse_args()
    entries = json.loads((ROOT / "assets/vfx/echoes/origin_scenes.json").read_text(encoding="utf-8"))
    summary = []
    for entry in entries:
        if entry["name"] in ("status", "indicator"):
            continue
        count = max(20, min(64, math.ceil(entry["duration"] * 16)))
        stem = entry["echo"] + "_" + entry["name"]
        delay = max(20, round(entry["duration"] * 1000 / count / 10) * 10)
        summary.append({"echo": entry["echo"], "effect": entry["name"], "frames": count,
                        "frame_ms": delay, "source_duration": entry["duration"], "size": [1280, 720]})
        if args.only and args.only != entry["echo"]:
            continue
        paths = [args.frames / f"{stem}_{i:02d}.png" for i in range(count)]
        frames = [Image.open(path).convert("RGB") for path in paths]
        palette = frames[count // 3].quantize(colors=256, method=Image.Quantize.MEDIANCUT)
        indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
        indexed[0].save(OUT / f"{stem}.gif", save_all=True, append_images=indexed[1:],
                        duration=delay, loop=0, optimize=True, disposal=1)
        print(stem, count, "images")
    (OUT / "animations.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
