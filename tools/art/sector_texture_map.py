#!/usr/bin/env python3
"""Carte de netteté utilisant les mesures et seuils communs du contrôle qualité."""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from check_map_quality import measure, bands, REFERENCE, SECTOR

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--images", nargs="+", required=True)
    parser.add_argument("--world", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    world = [float(v) for v in args.world.lower().split("x")]
    paths = [Path(p) for p in args.images]
    result = measure(paths, *world)
    limits = bands(json.loads(REFERENCE.read_text(encoding="utf-8")))
    width = 1536
    height = round(width * world[1] / world[0])
    full = Image.new("RGB", (width, height))
    for i, path in enumerate(paths):
        tile = Image.open(path).convert("RGB")
        x0, x1 = round(i * width / len(paths)), round((i+1) * width / len(paths))
        full.paste(tile.resize((x1-x0, height), Image.Resampling.LANCZOS), (x0, 0))
    overlay = Image.new("RGBA", full.size)
    draw = ImageDraw.Draw(overlay)
    font = ImageFont.truetype(str(Path(__file__).resolve().parents[2] / "assets/fonts/inter/Inter-Variable.ttf"), 16)
    rows = []
    for x, y, smooth, fine, medium in result["sectors"]:
        values = dict(smooth=smooth, fine=fine, medium=medium)
        below = smooth > limits["smooth"]["sector"][1] or any(values[k] < limits[k]["sector"][0] for k in ("fine", "medium"))
        above = any(values[k] > limits[k]["sector"][1] for k in ("fine", "medium"))
        state = "details insuffisants" if below else "details excessifs" if above else "conforme"
        color = (245,65,70,90) if below else (255,190,40,90) if above else (50,200,130,65)
        box = (round(x/world[0]*width), round(y/world[1]*height),
               round(min(x+SECTOR,world[0])/world[0]*width), round(min(y+SECTOR,world[1])/world[1]*height))
        draw.rectangle(box, fill=color, outline=(255,255,255,180), width=2)
        draw.text((box[0]+5,box[1]+5), f"{fine:.0f} / {medium:.0f}", font=font, fill="white", stroke_width=1, stroke_fill="black")
        rows.append(dict(x=x,y=y,smooth=smooth,fine=fine,medium=medium,status=state))
    preview = full.convert("RGBA")
    preview.alpha_composite(overlay)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    preview.convert("RGB").save(out / "nettete.png")
    data = dict(world=world,source="check_map_quality.py ; seuils sectoriels inchangés",legend={"green":"conforme","red":"détails insuffisants ou surface trop lisse","amber":"détails excessifs"},sectors=rows)
    (out / "nettete.json").write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    count = sum(r["status"]=="details insuffisants" for r in rows)
    print(f"{count} secteurs avec détails insuffisants sur {len(rows)} ; ce contrôle ne remplace pas l’examen visuel.")
    return int(count>0)
if __name__ == "__main__":
    raise SystemExit(main())
