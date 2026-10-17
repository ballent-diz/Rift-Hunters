#!/usr/bin/env python3
"""Test de l'outil d'import : simule une planche « générée par IA » (grande, lissée, fond vert, espacements
irréguliers) à partir des sprites procéduraux, l'importe, et vérifie le résultat. Ne modifie pas le dépôt."""
import json
import os
import sys
import tempfile
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import import_sheet  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
SHEET = os.path.join(REPO, "assets", "sprites", "monsters", "ashblade", "ashblade_sheet.png")


def fake_generated_row(sheet, row, frames, tmp, name, upscale=7):
    """Une ligne de l'animation, agrandie avec lissage (comme une image d'IA) sur fond vert, espacement irrégulier."""
    src = Image.open(sheet)
    with open(os.path.join(REPO, "assets", "asset_manifest.json"), encoding="utf-8") as handle:
        cw, ch = json.load(handle)["entries"]["monster.ashblade"]["cell"]
    rng = np.random.default_rng(row)
    width = sum(cw * upscale + int(rng.integers(20, 90)) for _ in range(frames)) + 40
    canvas = Image.new("RGBA", (width, ch * upscale + 60), (0, 214, 72, 255))
    x = 20
    for i in range(frames):
        frame = src.crop((i * cw, row * ch, (i + 1) * cw, (row + 1) * ch)).resize((cw * upscale, ch * upscale), Image.LANCZOS)
        canvas.paste(frame, (x, 30), frame)
        x += cw * upscale + int(rng.integers(20, 90))
    noisy = np.array(canvas).astype(int)
    noisy[:, :, :3] += rng.integers(-6, 7, noisy[:, :, :3].shape)
    Image.fromarray(np.clip(noisy, 0, 255).astype(np.uint8), "RGBA").convert("RGB").save(os.path.join(tmp, name))


def main():
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        fake_generated_row(SHEET, 0, 8, tmp, "idle.png")
        fake_generated_row(SHEET, 2, 7, tmp, "attack.png")
        job = {"visual_id": "monster.import_test", "cell": [64, 64], "anchor": [32, 54], "scale": 0.5, "target_height": 40,
               "background": "auto", "tolerance": 50, "holes": 42, "holes_min_area": 1, "despill": True, "colors": 24, "outline": False, "status": "wip",
               "animations": [{"name": "idle", "source": "idle.png", "frames": 8, "fps": 8},
                              {"name": "attack", "source": "attack.png", "frames": 7, "fps": 16, "loop": False}]}
        job_path = os.path.join(tmp, "job.json")
        with open(job_path, "w") as f:
            json.dump(job, f)
        entry = import_sheet.run(job_path, preview_only=True, preview_dir=tmp)
        preview = Image.open(os.path.join(tmp, "monster_import_test_import.png"))
        if entry["animations"]["idle"]["frames"] != 8 or entry["animations"]["attack"]["frames"] != 7:
            failures.append("nombre de frames incorrect : %s" % entry["animations"])
        # Vérifie une frame reconstruite directement.
        img = import_sheet.despill(import_sheet.remove_background(
            Image.open(os.path.join(tmp, "idle.png")), "auto", 50, 42, holes_min_area=1))
        arr = np.array(img)
        if arr[0, 0, 3] != 0 or arr[-1, -1, 3] != 0:
            failures.append("le fond n'a pas été retiré")
        green = (arr[:, :, 1] > 180) & (arr[:, :, 0] < 60) & (arr[:, :, 3] > 0)
        if green.sum() > arr.shape[0]:
            failures.append("trop de pixels verts résiduels : %d" % green.sum())
        sheet_preview = np.array(preview.convert("RGB")).astype(int)
        orange = (sheet_preview[:, :, 0] > 180) & (sheet_preview[:, :, 1] > 80) & (sheet_preview[:, :, 1] < 170) & \
            (sheet_preview[:, :, 2] < 110)
        if orange.sum() < 50:
            failures.append("les accents saturés (braises) ont été perdus par la réduction de palette")
        frames = import_sheet.split_frames(img, 8, "auto")
        if len(frames) != 8:
            failures.append("découpage : %d frames au lieu de 8" % len(frames))
        # Fond uni contrôlé : un trou de fond d'un pixel est retiré, le feuillage reste intact.
        keyed = Image.new("RGBA", (7, 7), (80, 130, 60, 255))
        keyed.putpixel((3, 3), (0, 214, 72, 255))
        keyed.putpixel((0, 0), (0, 214, 72, 255))
        clean = import_sheet.remove_background(keyed, "#00D648", 30, 42, holes_min_area=1)
        if clean.getpixel((3, 3))[3] != 0 or clean.getpixel((2, 2))[3] != 255:
            failures.append("fond enfermé : le vert doit disparaître sans trouer les couleurs naturelles")
        # Ancrage : le bas de la créature tombe sur l'ancre, ou `hover` pixels au-dessus pour un volant.
        blob = np.zeros((20, 10, 4), dtype=np.uint8)
        blob[2:18, 1:9] = 255
        for hover in (0, 6):
            cell = import_sheet.place_in_cell(blob, (64, 64), (32, 54), hover)
            bottom = int(np.nonzero(cell[:, :, 3].any(axis=1))[0].max())
            if bottom != 54 - hover:
                failures.append("ancrage (hover=%d) : bas en %d au lieu de %d" % (hover, bottom, 54 - hover))
        print("Aperçu :", preview.size)
    if failures:
        print("ÉCHEC :", "; ".join(failures))
        sys.exit(1)
    print("Import OK : fond retiré, frames découpées, échelle et palette communes, ancrage aux pieds.")


if __name__ == "__main__":
    main()
