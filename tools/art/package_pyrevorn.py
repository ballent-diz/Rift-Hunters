"""Archive les quatre planches de Pyrevorn et prépare leur import, sans gameplay."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

from PIL import Image
import numpy as np
from scipy import ndimage

from package_magma_family import body_height

ROOT = Path(__file__).resolve().parents[2]
SHEETS = {
    "a": ["idle", "move", "claws"],
    "b": ["magma_breath", "crater_rain", "brood_call"],
    "c": ["transform", "death"],
    "d": ["phase2_idle", "skyfall", "rift_eye"],
}


def package(scratch):
    folder = ROOT / "assets/concepts/incoming/boss.pyrevorn"
    source = folder / "source"
    source.mkdir(parents=True, exist_ok=True)
    hashes = []
    for original in scratch.iterdir():
        if original.suffix.lower() not in (".png", ".txt", ".json"):
            continue
        shutil.copyfile(original, source / original.name)
        if original.suffix.lower() == ".png":
            hashes.append(hashlib.sha256(original.read_bytes()).hexdigest() + "  " + original.name)
    reference_image = Image.open(source / "sheet_a.png").convert("RGBA")
    reference = sorted(body_height(reference_image, column) for column in range(6))[3]
    animations, normalizations = [], {}
    for label, names in SHEETS.items():
        filename = "sheet_" + label + ".png"
        image = Image.open(source / filename).convert("RGBA")
        assert image.getchannel("A").getextrema()[0] == 0, "Alpha absent : " + filename
        # La pose de départ de chaque planche garde la même hauteur corporelle.
        # Le vol et l'effondrement ne sont jamais remis individuellement à l'échelle.
        factor = reference / body_height(image, rows=len(names))
        normalizations[filename] = factor
        for row, name in enumerate(names):
            strip = image.crop((0, round(row * image.height / len(names)), image.width,
                                round((row + 1) * image.height / len(names))))
            strip = strip.resize((round(strip.width * factor), round(strip.height * factor)), Image.Resampling.LANCZOS)
            if name == "skyfall":
                # La retouche ne contient qu'une rangée : ses six composantes entières
                # sont réespacées, sans redessiner ni couper les ailes.
                repair = np.array(Image.open(source / "skyfall_repair.png").convert("RGBA"))
                labels, _ = ndimage.label(repair[:, :, 3] > 64)
                poses = []
                for component, bounds in enumerate(ndimage.find_objects(labels), 1):
                    mask = labels[bounds] == component
                    if int(mask.sum()) > 1000:
                        poses.append((bounds[1].start, component, bounds))
                poses.sort()
                assert len(poses) == 6, "La retouche doit contenir six poses séparées"
                size_factor = reference / (poses[0][2][0].stop - poses[0][2][0].start)
                strip = Image.new("RGBA", (4608, 768))
                boxes = []
                for column, (_, component, bounds) in enumerate(poses):
                    mask = ndimage.binary_dilation(labels == component, iterations=2)
                    pixels = repair.copy()
                    pixels[~mask, 3] = 0
                    pose = Image.fromarray(pixels).crop(Image.fromarray(pixels).getbbox())
                    pose = pose.resize((round(pose.width * size_factor), round(pose.height * size_factor)),
                                       Image.Resampling.LANCZOS)
                    assert pose.width < 750 and pose.height < 730
                    strip.paste(pose, (column * 768 + (768 - pose.width) // 2, 740 - pose.height))
                    boxes.append(list(bounds[i].indices(repair.shape[i])[:2] for i in range(2)))
                (source / "skyfall_extraction.json").write_text(
                    json.dumps({"component_bounds_yx": boxes, "scale": size_factor}, indent=2) + "\n", encoding="utf-8")
            strip.save(folder / (name + ".png"))
            animation = {"name": name, "source": name + ".png", "sheet_source": "source/" + filename,
                         "source_row": row, "source_scale": factor, "frames": 6,
                         "fps": 7 if "idle" in name else 9,
                         "loop": "idle" in name or name == "move", "layout": "grid", "grid": [6, 1]}
            if name == "skyfall":
                animation["sheet_source"] = "source/skyfall_repair.png"
                animation["source_row"] = 0
                animation["source_scale"] = size_factor
                animation["frame_offsets"] = [[0, y] for y in (0, -60, -140, -170, -70, 0)]
            animations.append(animation)
    job = {"id": "pyrevorn", "fr": "Pyrevorn", "en": "Pyrevorn", "tier": "boss",
           "visual_id": "boss.pyrevorn", "cell": [512, 512], "anchor": [256, 480],
           "scale": 1.0, "target_height": 150, "status": "wip", "background": "alpha", "tolerance": 0,
           "colors": 32, "outline": True, "resample": "lanczos", "anchor_mode": "mass", "isolate": True,
           "icon_size": 256, "preview_zoom": 1, "animations": animations, "aliases": {"attack": "claws"},
           "mode": "builtin-imagegen", "prompt": (source / "prompt_a.txt").read_text(encoding="utf-8"),
           "description": "Dévoreur volcanique quadrupède, ailes de basalte, cratère dorsal, quatre yeux orange et œil blanc."}
    (folder / "job.json").write_text(json.dumps(job, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (source / "SHA256.txt").write_text("\n".join(hashes) + "\n", encoding="utf-8")
    (source / "normalization.json").write_text(json.dumps(normalizations, indent=2) + "\n", encoding="utf-8")
    print("Pyrevorn :", len(animations), "animations de six poses", normalizations)


if __name__ == "__main__":
    package(Path(sys.argv[1]).resolve())
