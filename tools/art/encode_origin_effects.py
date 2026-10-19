#!/usr/bin/env python3
"""Exporte les GIF C5-ter à l'échelle native, avec la durée propre de chaque effet."""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/previews/c5-echos-origine"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--frames", required=True, type=Path)
    parser.add_argument("--only", help="Réexporter un seul Écho après une retouche ciblée.")
    parser.add_argument("--catalog", action="append", type=Path, help="Catalogue(s) de scènes à assembler.")
    parser.add_argument("--out", type=Path, default=OUT, help="Dossier de livraison des aperçus.")
    parser.add_argument("--skip-existing", action="store_true", help="Conserver les GIF plus récents que leurs images.")
    parser.add_argument("--delta", action="store_true", help="Conserver le décor entre images, sans réduire la définition.")
    args = parser.parse_args()
    entries = []
    for catalog in args.catalog or [ROOT / "assets/vfx/echoes/origin_scenes.json"]:
        entries.extend(json.loads(catalog.read_text(encoding="utf-8")))
    args.out.mkdir(parents=True, exist_ok=True)
    summary = []
    for entry in entries:
        if entry["name"] in ("status", "indicator"):
            continue
        count = max(20, min(64, math.ceil(entry["duration"] * 16)))
        stem = entry["echo"] + "_" + entry["name"]
        delay = max(20, round(entry["duration"] * 1000 / count / 10) * 10)
        summary.append({"echo": entry["echo"], "effect": entry["name"], "frames": count,
                        "frame_ms": delay, "source_duration": entry["duration"], "size": [1280, 720]})
        if args.only and entry["echo"] not in args.only.split(","):
            continue
        paths = [args.frames / f"{stem}_{i:02d}.png" for i in range(count)]
        destination = args.out / f"{stem}.gif"
        if args.skip_existing and destination.exists():
            if destination.stat().st_mtime_ns >= max(path.stat().st_mtime_ns for path in paths):
                print(stem, "conservé")
                continue
        frames = [Image.open(path).convert("RGB") for path in paths]
        palette = frames[count // 3].quantize(colors=255 if args.delta else 256, method=Image.Quantize.MEDIANCUT)
        if args.delta:
            colors = palette.getpalette()
            colors[765:768] = colors[:3]
            palette.putpalette(colors)
        indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
        if args.delta:
            deltas, previous, references = [], None, {}
            for number, frame in enumerate(indexed):
                current = np.array(frame)
                current[current == 255] = 0
                full = current.copy()
                if number in (0, count // 2, count - 1):
                    references[number] = np.array(colors, dtype=np.uint8).reshape(256, 3)[full]
                if previous is not None:
                    current[current == previous] = 255
                delta = Image.fromarray(current, 'P')
                delta.putpalette(colors)
                deltas.append(delta)
                previous = full
            deltas[0].save(destination, save_all=True, append_images=deltas[1:], duration=delay,
                           loop=0, optimize=False, disposal=1, transparency=255)
            with Image.open(destination) as decoded:
                elapsed, checked = 0, 0
                for number in range(decoded.n_frames):
                    decoded.seek(number)
                    end = elapsed + decoded.info['duration']
                    for source_frame, expected in references.items():
                        if elapsed <= source_frame * delay < end:
                            assert np.array_equal(np.array(decoded.convert('RGB')), expected), (stem, source_frame)
                            checked += 1
                    elapsed = end
                assert checked == len(references) and elapsed == count * delay, (stem, 'durée incorrecte')
        else:
            indexed[0].save(destination, save_all=True, append_images=indexed[1:],
                            duration=delay, loop=0, optimize=True, disposal=1)
        print(stem, count, "images")
    (args.out / "animations.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
