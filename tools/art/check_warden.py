"""Vérifie les cellules livrées et produit des aperçus à partir des frames, sans dessiner de poses."""
import json
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT.parent / "Rift-Hunters-matiere-travail/warden"


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((ROOT / "assets/asset_manifest.json").read_text(encoding="utf-8"))
    baseline = json.loads(subprocess.check_output(
        ["git", "-c", "safe.directory=" + ROOT.as_posix(), "show", "HEAD:assets/asset_manifest.json"], cwd=ROOT))
    old = baseline["entries"]["player.hunter"]
    assert manifest["entries"]["player.hunter"] == old
    entry = manifest["entries"]["player.threshold_warden"]
    image = Image.open(ROOT / entry["sheet"].removeprefix("res://")).convert("RGBA")
    array = np.array(image)
    assert set(np.unique(array[:, :, 3])) == {0, 255}
    colors = len(np.unique(array[array[:, :, 3] > 0, :3], axis=0))
    assert colors <= 48
    metrics = {}
    for name, clip in entry["animations"].items():
        if name == "dash":
            continue
        boxes = []
        for frame in range(clip["frames"]):
            box = cell(image, clip["row"], frame).getbbox()
            assert box and box[0] > 0 and box[2] < 112 and box[1] > 0 and box[3] < 80, (name, frame, box)
            boxes.append(box)
        metrics[name] = {"frames": clip["frames"], "fps": clip["fps"], "bounds": boxes}
    result = {"status": "conforme", "colors": colors, "alpha": "0/255", "cell": entry["cell"],
              "anchor": entry["anchor"], "scale": entry["scale"], "frames": sum(m["frames"] for m in metrics.values()),
              "animations": metrics, "dash": "alias attack, comme le joueur actuel", "original_entry": "identique"}
    (OUTPUT / "sprite_validation.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    frames = []
    captions = {"idle": "Repos", "move": "Marche", "attack": "Attaque", "hurt": "Blessure", "death": "Chute"}
    for tick in range(36):
        canvas = Image.new("RGB", (1120, 190), (24, 28, 40))
        draw = ImageDraw.Draw(canvas)
        for column, name in enumerate(captions):
            clip = entry["animations"][name]
            index = int(tick / 12 * clip["fps"])
            index = index % clip["frames"] if clip["loop"] else min(index, clip["frames"] - 1)
            frame = cell(image, clip["row"], index).resize((224, 160), Image.Resampling.NEAREST)
            canvas.paste(frame, (column * 224, 26), frame)
            draw.text((column * 224 + 18, 8), captions[name], fill=(220, 224, 232))
        frames.append(canvas)
    frames[0].save(OUTPUT / "animations.gif", save_all=True, append_images=frames[1:], duration=83, loop=0, optimize=True)
    old_image = Image.open(ROOT / old["sheet"].removeprefix("res://")).convert("RGBA")
    contact = Image.new("RGB", (672, 300), (24, 28, 40))
    draw = ImageDraw.Draw(contact)
    draw.text((25, 10), "Chasseur actuel", fill="white")
    draw.text((360, 10), "Veilleur des Seuils", fill="white")
    frame = old_image.crop((0, 0, 96, 80)).resize((288, 240), Image.Resampling.NEAREST)
    contact.paste(frame, (15, 42), frame)
    frame = cell(image, 0, 0).resize((336, 240), Image.Resampling.NEAREST)
    contact.paste(frame, (336, 42), frame)
    contact.save(OUTPUT / "comparison.png")
    print("WARDEN_CHECK", result["frames"], "poses,", colors, "couleurs ; joueur original identique")


def cell(image, row, frame):
    return image.crop((frame * 112, row * 80, (frame + 1) * 112, (row + 1) * 80))


if __name__ == "__main__":
    main()
