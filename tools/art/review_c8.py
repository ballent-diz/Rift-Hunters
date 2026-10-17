#!/usr/bin/env python3
"""Contrôle non destructif des 429 poses C8 et aperçu animé, sans modifier le gameplay."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from echo_sprite_specs import C8_ECHOS

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/previews/c8"


def main():
    manifest = json.loads((ROOT / "assets/asset_manifest.json").read_text(encoding="utf-8"))["entries"]
    entries = {}
    report = {}
    for creature_id, spec in C8_ECHOS.items():
        entry = manifest["monster." + creature_id]
        sheet = Image.open(ROOT / entry["sheet"].removeprefix("res://")).convert("RGBA")
        cw, ch = entry["cell"]
        alpha = np.array(sheet)
        key = (alpha[:, :, 1] > 180) & (alpha[:, :, 0] < 45) & (alpha[:, :, 2] < 110) & (alpha[:, :, 3] > 0)
        assert not key.any(), f"{creature_id} : fond vert résiduel"
        heights, bottoms, total = [], [], 0
        for name, anim in entry["animations"].items():
            for index in range(anim["frames"]):
                box = (index*cw, anim["row"]*ch, (index+1)*cw, (anim["row"]+1)*ch)
                frame = sheet.crop(box)
                bounds = frame.getbbox()
                assert bounds, f"{creature_id}/{name}/{index} : vide"
                assert 0 < bounds[0] and 0 < bounds[1] and bounds[2] < cw and bounds[3] < ch, (
                    f"{creature_id}/{name}/{index} : bord touché {bounds}")
                if name == "idle":
                    heights.append(bounds[3]-bounds[1])
                    bottoms.append(bounds[3]-1)
                total += 1
        expected = entry["anchor"][1] - spec["hover"] + 1  # contour d'un pixel
        assert set(bottoms) == {expected}, f"{creature_id} : ancrage instable {bottoms}"
        report[creature_id] = {"poses": total, "idle_heights": heights, "idle_bottom": expected,
                               "world_height": round(float(np.median(heights))*entry["scale"], 2),
                               "cell": entry["cell"], "key_green_pixels": int(key.sum())}
        entries[creature_id] = (entry, sheet)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "quality.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    font = ImageFont.truetype(str(ROOT / "assets/fonts/inter/Inter-Variable.ttf"), 17)
    frames = []
    phases = ["idle", "move", "attack", "technique", "death"]
    for phase in phases:
        for step in range(8):
            canvas = Image.new("RGBA", (1280, 830), "#191D2D")
            draw = ImageDraw.Draw(canvas)
            draw.text((25, 15), "C8 · " + phase + " · aperçu agrandi ×2 (pas l’échelle du jeu)", font=font, fill="white")
            for index, (creature_id, (entry, sheet)) in enumerate(entries.items()):
                anim = entry["animations"][phase]
                n = min(step, anim["frames"]-1)
                cw, ch = entry["cell"]
                frame = sheet.crop((n*cw, anim["row"]*ch, (n+1)*cw, (anim["row"]+1)*ch))
                # Même grossissement d'art pour tous ; pas de remise à taille de chaque silhouette.
                frame = frame.resize((cw*2, ch*2), Image.Resampling.NEAREST)
                col, row = index%4, index//4
                x = col*320 + 160 - entry["anchor"][0]*2
                y = 85 + row*250 + 160 - entry["anchor"][1]*2
                canvas.alpha_composite(frame, (x, y))
                draw.text((col*320+20, 250+row*250), C8_ECHOS[creature_id]["name"], font=font, fill="white")
            frames.append(canvas.convert("RGB"))
    frames[0].save(OUT / "animations.gif", save_all=True, append_images=frames[1:], duration=125, loop=0, disposal=2)
    print(f"C8 : {sum(x['poses'] for x in report.values())} poses, aucun bord touché, aucun fond vert, ancres stables.")


if __name__ == "__main__":
    main()
