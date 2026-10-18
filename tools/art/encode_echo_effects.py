#!/usr/bin/env python3
"""Assemble les séquences Godot en GIF et les icônes en planche de contrôle HD / taille réelle."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/previews/c7-echos"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--frames", type=Path)
    args = parser.parse_args()
    specs = json.loads((ROOT / "assets/vfx/echoes/catalog.json").read_text(encoding="utf-8"))
    board = Image.new("RGB", (1280, 9 * 150), "#111522")
    draw = ImageDraw.Draw(board)
    for row, spec in enumerate(specs):
        draw.text((12, row * 150 + 10), spec["name"], fill="#ebdfbf")
        for col, role in enumerate(("might", "focus", "spell_base", "spell_alt", "signature")):
            path = ROOT / f"assets/ui/icons/skills/echo_{spec['id']}_{role}.png"
            if path.exists():
                icon = Image.open(path).convert("RGBA")
                board.paste(icon.resize((112, 112), Image.Resampling.LANCZOS), (155 + col * 220, row * 150),
                            icon.resize((112, 112), Image.Resampling.LANCZOS))
                icon.thumbnail((48, 48), Image.Resampling.LANCZOS)
                board.paste(icon, (280 + col * 220, row * 150 + 30), icon)
        if args.frames:
            for spell in (spec["base"], spec["alt"]):
                paths = sorted(args.frames.glob(f"{spec['id']}_{spell}_*.png"))
                if len(paths) != 20:
                    raise RuntimeError(f"{spec['id']} / {spell} : {len(paths)} images au lieu de 20")
                frames = [Image.open(p).convert("RGB") for p in paths]
                # Palette commune : le décor figé reste identique, sans scintillement ni duplication plein écran.
                palette = frames[7].quantize(colors=256, method=Image.Quantize.MEDIANCUT)
                indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
                indexed[0].save(OUT / f"{spec['id']}_{spell}.gif", save_all=True, append_images=indexed[1:],
                                duration=80, loop=0, optimize=True, disposal=1)
    board.save(OUT / "icones-controle.png")


if __name__ == "__main__":
    main()
