#!/usr/bin/env python3
"""Finition d'une composition validée à l'échelle de la caméra ; aucune donnée de jeu."""
from pathlib import Path
import json
import hashlib
import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/concepts/incoming/map.firefly_woods"
SOURCE = BASE / "source"
WORLD = (5016, 3344)
NATIVE = (6270, 4180)


def prepare():
    original = Image.open(SOURCE / "map_detailed.png").convert("RGB").resize(WORLD, Image.Resampling.LANCZOS)
    native = original.resize(NATIVE, Image.Resampling.LANCZOS)
    jobs = json.loads((SOURCE / "fine/layout.json").read_text())
    records = []
    for job in jobs:
        path = SOURCE / f'fine/{job["id"]}_detail.png'
        if not path.exists():
            continue
        x0, y0, x1, y1 = job["crop"]
        a, b, c, d = job["core"]
        target = np.array(Image.open(SOURCE / f'fine/{job["id"]}_input.png').convert("RGB"))
        image = np.array(Image.open(path).convert("RGB"))
        small = cv2.resize(image, (x1-x0, y1-y0), interpolation=cv2.INTER_AREA)
        flow = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM).calc(
            cv2.cvtColor(target, cv2.COLOR_RGB2GRAY), cv2.cvtColor(small, cv2.COLOR_RGB2GRAY), None)
        flow = cv2.GaussianBlur(np.clip(flow, -16, 16), (0, 0), 2)
        nx0, ny0, nx1, ny1 = [round(v*1.25) for v in [x0, y0, x1, y1]]
        width, height = nx1-nx0, ny1-ny0
        f = cv2.resize(flow, (width, height), interpolation=cv2.INTER_CUBIC)
        yy, xx = np.mgrid[0:height, 0:width].astype(np.float32)
        mx = (xx/1.25+f[:,:,0]+.4)*image.shape[1]/(x1-x0)-.5
        my = (yy/1.25+f[:,:,1]+.4)*image.shape[0]/(y1-y0)-.5
        aligned = cv2.remap(image, mx, my, cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_REFLECT_101)
        wx = np.ones(width); wy = np.ones(height)
        if x0: wx *= np.clip(np.arange(width)/(max(a-x0,1)*1.25),0,1)
        if y0: wy *= np.clip(np.arange(height)/(max(b-y0,1)*1.25),0,1)
        if x1 < WORLD[0]: wx *= np.clip((width-1-np.arange(width))/(max(x1-c,1)*1.25),0,1)
        if y1 < WORLD[1]: wy *= np.clip((height-1-np.arange(height))/(max(y1-d,1)*1.25),0,1)
        alpha = Image.fromarray(np.rint(wy[:,None]*wx[None,:]*255).astype("uint8"))
        native.paste(Image.fromarray(aligned), (nx0,ny0), alpha)
        records.append({"id":job["id"],"generated_size":[image.shape[1],image.shape[0]],"world_crop":job["crop"]})
    dest = ROOT / "assets/environments/firefly_woods"
    dest.mkdir(parents=True,exist_ok=True)
    native.save(dest/"map.webp",lossless=True,method=3)
    native.resize(WORLD,Image.Resampling.LANCZOS).save(BASE/"collision/reference.webp",lossless=True,method=3)
    preview = native.copy()
    preview.thumbnail((1800,1200))
    preview.save(ROOT/"docs/previews/bois-des-lucioles/bois-carte-entiere.png")
    (SOURCE/"fine/assembly.json").write_text(json.dumps(records,indent=2)+"\n")
    hashes = []
    for path in sorted(SOURCE.rglob("*")):
        if path.is_file() and path.name!="SHA256SUMS.txt":
            hashes.append(hashlib.sha256(path.read_bytes()).hexdigest()+"  "+path.relative_to(SOURCE).as_posix())
    (SOURCE/"SHA256SUMS.txt").write_text("\n".join(hashes)+"\n")
    print(json.dumps({"native":NATIVE,"world":WORLD,"refined_sectors":len(records)},ensure_ascii=False))


if __name__ == "__main__":
    prepare()
