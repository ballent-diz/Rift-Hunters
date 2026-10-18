#!/usr/bin/env python3
"""Prépare les huit poses peintes en atlas transparent, sans inventer de détails."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
from prepare_c8_sheet import separator
from import_sheet import remove_background, despill

ROOT = Path(__file__).resolve().parents[2]


def main():
    folder = ROOT / "assets/concepts/incoming/vfx.barrier_energy"
    image = Image.open(folder / "source/sheet.png").convert("RGBA")
    arr = np.array(image).astype(int)
    mask = abs(arr[:, :, :3]-[0, 214, 72]).max(axis=2) > 45
    width, height = image.size
    middle = separator(mask.sum(axis=1), height//2, height//10)
    atlas = Image.new("RGBA", (256*8, 256))
    frames, ranges = [], []
    for row, (top, bottom) in enumerate([(0, middle), (middle, height)]):
        activity = mask[top:bottom].sum(axis=0)
        columns = [0]+[separator(activity, round(width*i/4), width//32) for i in range(1, 4)]+[width]
        for index in range(4):
            crop = image.crop((columns[index], top, columns[index+1], bottom))
            clean = despill(remove_background(crop, "#00D648", 35, 45, holes_min_area=1))
            clean = clean.crop(clean.getbbox()).resize((256, 256), Image.Resampling.LANCZOS)
            atlas.paste(clean, ((row*4+index)*256, 0))
            frames.append(clean)
            ranges.append([columns[index], top, columns[index+1], bottom])
    destination = ROOT / "assets/vfx/barriers/energy_sheet.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(destination)
    (folder / "slicing.json").write_text(json.dumps({"source_rects": ranges, "fps": 12}, indent=2)+"\n")
    manifest_path = ROOT / "assets/asset_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["entries"]["vfx.barrier.energy"] = {"status": "final", "sheet": "res://assets/vfx/barriers/energy_sheet.png",
        "cell": [256, 256], "anchor": [128, 128], "scale": 1.0,
        "generated_by": "tools/art/prepare_barrier_energy.py",
        "animations": {"idle": {"row": 0, "frames": 8, "fps": 12, "loop": True}}}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent="\t")+"\n", encoding="utf-8")
    # Aperçu de la véritable séquence, sur fond sombre.
    previews = []
    for frame in frames:
        canvas = Image.new("RGBA", (256, 256), "#171429")
        canvas.alpha_composite(frame)
        previews.append(canvas.convert("RGB"))
    previews[0].save(ROOT / "docs/previews/a3-failles/barriere-animation.gif", save_all=True,
                     append_images=previews[1:], duration=83, loop=0, disposal=2)
    print("Barrière : huit poses à 12 images/s, atlas transparent importable.")


if __name__ == "__main__":
    main()
