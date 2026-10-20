#!/usr/bin/env python3
"""Assemble les retouches d'une seule composition ; ne calcule aucune collision."""
from pathlib import Path
import hashlib
import json
import numpy as np
import cv2
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/concepts/incoming/map.firefly_woods"
PREVIEW = ROOT / "docs/previews/bois-des-lucioles"


def register_region(image, target_path, region_id, factor):
    """Recalage des détails sur leur géométrie commune ; conserve les corrections locales demandées."""
    target = np.array(Image.open(target_path).convert("RGB"))
    height, width = target.shape[:2]
    generated = np.array(image)
    small = cv2.resize(generated, (width, height), interpolation=cv2.INTER_AREA)
    reference_gray = cv2.cvtColor(target, cv2.COLOR_RGB2GRAY)
    generated_gray = cv2.cvtColor(small, cv2.COLOR_RGB2GRAY)
    flow = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM).calc(reference_gray, generated_gray, None)
    flow = cv2.GaussianBlur(np.clip(flow, -24, 24), (0, 0), 2)
    # La lisière méridionale et la séparation centrale ont volontairement changé de géométrie.
    if region_id.endswith("_2"):
        flow *= np.clip((height * .48 - np.arange(height)) / (height * .12), 0, 1)[:, None, None]
    if region_id == "1_1":
        yy, xx = np.mgrid[0:height, 0:width]
        diagonal = height * (.15 + .58 * xx / width)
        protection = np.clip((np.abs(yy-diagonal)-height*.11)/(height*.07), 0, 1)
        flow *= protection[:, :, None]
    enlarged = cv2.resize(flow, (width*factor, height*factor), interpolation=cv2.INTER_CUBIC)
    yy, xx = np.mgrid[0:height*factor, 0:width*factor].astype(np.float32)
    map_x = (xx/factor + enlarged[:, :, 0] + .5/factor)*generated.shape[1]/width-.5
    map_y = (yy/factor + enlarged[:, :, 1] + .5/factor)*generated.shape[0]/height-.5
    aligned = cv2.remap(generated, map_x, map_y, cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_REFLECT_101)
    return Image.fromarray(aligned), {"region": region_id, "method": "DIS medium, bornage 24 px source",
        "median_offset_px": round(float(np.median(np.linalg.norm(flow, axis=2))), 3), "opencv": cv2.__version__}


def assemble():
    source = BASE / "source"
    jobs = json.loads((source / "regions/layout.json").read_text())
    factor = 3
    width, height = 1536 * factor, 1024 * factor
    total = np.zeros((height, width, 3), dtype=np.float32)
    weight = np.zeros((height, width), dtype=np.float32)
    registrations = []
    for job in jobs:
        x0, y0, x1, y1 = job["crop"]
        a, b, c, d = job["core"]
        image = Image.open(source / f'regions/{job["id"]}_detail.png').convert("RGB")
        image, registration = register_region(image, source / f'regions/{job["id"]}_input.png', job["id"], factor)
        registrations.append(registration)
        xx = np.arange(x0*factor, x1*factor, dtype=np.float32)/factor
        yy = np.arange(y0*factor, y1*factor, dtype=np.float32)/factor
        wx = np.ones(xx.shape, dtype=np.float32)
        wy = np.ones(yy.shape, dtype=np.float32)
        if x0 > 0:
            wx *= np.clip((xx-x0)/(a-x0), 0, 1)
        if x1 < 1536:
            wx *= np.clip((x1-xx)/(x1-c), 0, 1)
        if y0 > 0:
            wy *= np.clip((yy-y0)/(b-y0), 0, 1)
        if y1 < 1024:
            wy *= np.clip((y1-yy)/(y1-d), 0, 1)
        alpha = wy[:, None] * wx[None, :]
        total[y0*factor:y1*factor, x0*factor:x1*factor] += np.array(image)*alpha[:, :, None]
        weight[y0*factor:y1*factor, x0*factor:x1*factor] += alpha
    (source / "regions/alignment.json").write_text(json.dumps(registrations, indent=2)+"\n")
    assert weight.min() > 0, "Un trou dans les recouvrements"
    result = Image.fromarray(np.rint(total/weight[:, :, None]).clip(0, 255).astype("uint8"))
    patch_path = source / "bridge_detail.png"
    if patch_path.exists():
        patch = Image.open(patch_path).convert("RGB").resize((1110, 585), Image.Resampling.LANCZOS)
        xx = np.minimum(np.arange(1110), np.arange(1110)[::-1]) / 45.0
        yy = np.minimum(np.arange(585), np.arange(585)[::-1]) / 45.0
        alpha = Image.fromarray(np.rint(np.clip(yy[:, None] * np.clip(xx, 0, 1)[None, :], 0, 1)*255).astype("uint8"))
        result.paste(patch, (2400, 1185), alpha)
    result.save(source / "map_detailed.png")
    (BASE / "collision").mkdir(exist_ok=True)
    # 1 pixel = 1 unité, même cadrage. La peinture rouge sera fournie par le propriétaire.
    working = result.resize((5016, 3344), Image.Resampling.LANCZOS)
    working.save(BASE / "collision/reference.webp", lossless=True, method=6)
    with Image.open(BASE / "collision/reference.webp") as check:
        assert check.tobytes() == working.tobytes(), "Conversion avec perte"
    PREVIEW.mkdir(parents=True, exist_ok=True)
    small = working.copy()
    small.thumbnail((1800, 1200))
    small.save(PREVIEW / "bois-carte-entiere.png")
    hashes = []
    for path in sorted(source.rglob("*")):
        if path.is_file() and path.name != "SHA256SUMS.txt":
            hashes.append(hashlib.sha256(path.read_bytes()).hexdigest()+"  "+path.relative_to(source).as_posix())
    (source / "SHA256SUMS.txt").write_text("\n".join(hashes)+"\n", encoding="utf-8")
    print(json.dumps({"native_assembly": list(result.size), "working": list(working.size),
                      "working_bytes": (BASE / "collision/reference.webp").stat().st_size,
                      "source_files_hashed": len(hashes)}, ensure_ascii=False))


if __name__ == "__main__":
    assemble()
