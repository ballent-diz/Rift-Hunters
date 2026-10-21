#!/usr/bin/env python3
"""Rend nettes les zones floues d'une carte dessinée (Real-ESRGAN, en local, sans carte graphique).

  python3 tools/art/deblur_map.py environment.cascade_ruins [--preview <dossier>]

1. tools/art/sharpness_map.py repère les cases floues (comparées aux cases nettes de la même carte) ;
2. chaque bloc touché est réduit de moitié, agrandi ×4 par Real-ESRGAN (x4plus), puis ramené à sa taille : les
   contours redeviennent nets sans changer les formes ni les couleurs (la réduction au quart invente des formes) ;
3. le résultat est fondu dans la carte par un masque adouci (pas de couture), seules les zones floues changent.
Limite : une zone dont les objets sont dessinés trop gros (pavés deux fois plus grands) reste trop grosse ; seule une
région régénérée (tools/art/map_regions.py) corrige l'échelle.
Modèle : RealESRGAN_x4plus.pth (licence BSD-3, github.com/xinntao/Real-ESRGAN) téléchargé une fois dans
~/.cache/rift_hunters/ et converti en ONNX par tools/art/esrgan_onnx.py (pas besoin de PyTorch).
Relancer ensuite build_minimap.py, check_map_quality.py et sharpness_map.py.
Nécessite numpy, Pillow, scipy, onnx et onnxruntime.
"""
import argparse
import json
import sys
import urllib.request
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
import esrgan_onnx  # noqa: E402
import sharpness_map  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "asset_manifest.json"
CACHE = Path.home() / ".cache" / "rift_hunters"
MODEL_URL = "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth"
# Bloc traité d'un coup (pixels de la carte) et recouvrement entre blocs (bords du réseau ignorés).
BLOCK = 512
OVERLAP = 32
# Adoucissement du masque (pixels) : fondu entre zones corrigées et zones déjà nettes.
FEATHER = 24.0
Image.MAX_IMAGE_PIXELS = None


def session():
    CACHE.mkdir(parents=True, exist_ok=True)
    onnx_path = CACHE / "realesrgan_x4plus.onnx"
    if not onnx_path.exists():
        pth = CACHE / "RealESRGAN_x4plus.pth"
        if not pth.exists():
            print("Téléchargement du modèle Real-ESRGAN…")
            urllib.request.urlretrieve(MODEL_URL, pth)
        esrgan_onnx.build(esrgan_onnx.load_pth(pth), str(onnx_path))
    return ort.InferenceSession(str(onnx_path), providers=["CPUExecutionProvider"])


def sharpen_block(sess, block):
    """Bloc RGB (uint8) : réduit de moitié, ×4 par le réseau, ramené à sa taille."""
    h, w = block.shape[:2]
    half = Image.fromarray(block).resize((max(w // 2, 1), max(h // 2, 1)), Image.Resampling.LANCZOS)
    x = np.asarray(half).astype(np.float32).transpose(2, 0, 1)[None] / 255.0
    y = sess.run(None, {"input": x})[0][0].transpose(1, 2, 0)
    big = Image.fromarray((np.clip(y, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8))
    return np.asarray(big.resize((w, h), Image.Resampling.LANCZOS)).astype(np.float32)


def blurry_mask(env_id, size):
    _, _, scores, step, reference, blurry = sharpness_map.analyse(env_id)
    mask = np.zeros((size[1], size[0]), dtype=np.float32)
    for r, c in zip(*np.nonzero(blurry)):
        mask[r * step:(r + 1) * step, c * step:(c + 1) * step] = 1.0
    return np.clip(ndimage.gaussian_filter(mask, FEATHER), 0.0, 1.0) if mask.any() else mask


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("env_id")
    parser.add_argument("--preview", type=Path, help="écrit la carte corrigée ici au lieu de remplacer les tuiles")
    args = parser.parse_args()
    entry = json.loads(MANIFEST.read_text(encoding="utf-8"))["entries"][args.env_id]
    paths = [sharpness_map.res_path(p) for p in entry.get("map_tiles") or [entry["map"]]]
    tiles = [Image.open(p).convert("RGB") for p in paths]
    width, height = sum(t.size[0] for t in tiles), tiles[0].size[1]
    full = Image.new("RGB", (width, height))
    x = 0
    for t in tiles:
        full.paste(t, (x, 0))
        x += t.size[0]
    mask = blurry_mask(args.env_id, full.size)
    print(f"{args.env_id} : {mask.mean():.0%} de la carte à rendre nette")
    src = np.asarray(full).astype(np.float32)
    out = src.copy()
    sess = session()
    inner = BLOCK - 2 * OVERLAP
    blocks = [(y, x) for y in range(0, height, inner) for x in range(0, width, inner)
              if mask[y:y + inner, x:x + inner].max() > 0.01]
    for i, (y, x) in enumerate(blocks):
        y0, x0 = max(y - OVERLAP, 0), max(x - OVERLAP, 0)
        y1, x1 = min(y + inner + OVERLAP, height), min(x + inner + OVERLAP, width)
        sharp = sharpen_block(sess, src[y0:y1, x0:x1].astype(np.uint8))
        ys, xs = slice(y - y0, y - y0 + min(inner, height - y)), slice(x - x0, x - x0 + min(inner, width - x))
        m = mask[y:y + inner, x:x + inner, None]
        out[y:y + inner, x:x + inner] = src[y:y + inner, x:x + inner] * (1.0 - m) + sharp[ys, xs] * m
        if i % 20 == 0:
            print(f"  bloc {i + 1} / {len(blocks)}", flush=True)
    result = Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8))
    if args.preview:
        args.preview.mkdir(parents=True, exist_ok=True)
        result.save(args.preview / (args.env_id.removeprefix("environment.") + "_deblurred.png"))
        return
    x = 0
    for t, p in zip(tiles, paths):
        result.crop((x, 0, x + t.size[0], height)).save(p, lossless=True, method=4)
        x += t.size[0]
    print("Tuiles remplacées :", ", ".join(p.name for p in paths))


if __name__ == "__main__":
    main()
