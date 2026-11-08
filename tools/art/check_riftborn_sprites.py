#!/usr/bin/env python3
"""Audit des fichiers réellement livrés : alpha, palette, poses, marges et ancres."""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

from import_riftborn import ROOT, IDS, ELITES, digest, write


def check(output):
    manifest = json.loads((ROOT / "assets/asset_manifest.json").read_text(encoding="utf-8"))["entries"]
    report, failures = {}, []
    for identifier in IDS:
        key = "enemy." + identifier
        entry = manifest[key]
        folder = ROOT / "assets/concepts/incoming" / key
        job = json.loads((folder / "job.json").read_text(encoding="utf-8"))
        side = entry["cell"][0]
        assert entry["cell"] == [side, side] and entry["scale"] == .5
        image = Image.open(ROOT / entry["sheet"].removeprefix("res://")).convert("RGBA")
        pixels = np.asarray(image)
        palette = np.unique(pixels[pixels[:, :, 3] > 0, :3], axis=0)
        if len(palette) > 32 or set(np.unique(pixels[:, :, 3])) != {0, 255}:
            failures.append(key + " : palette ou alpha")
        animations = {}
        for animation in job["animations"]:
            name = animation["name"]
            spec = entry["animations"][name]
            bounds, frames = [], []
            for index in range(spec["frames"]):
                frame = image.crop((index * side, spec["row"] * side, (index + 1) * side, (spec["row"] + 1) * side))
                box = frame.getbbox()
                if not box or min(box[:2]) < 2 or max(box[2:]) > side - 2:
                    failures.append(f"{key}/{name}/{index} : marge ou pose vide {box}")
                bounds.append(list(box) if box else None)
                frames.append(np.asarray(frame))
            unique = len({frame.tobytes() for frame in frames})
            if unique < min(spec["frames"], 5 if name == "move" else 4):
                failures.append(f"{key}/{name} : seulement {unique} poses distinctes")
            heights = [b[3] - b[1] for b in bounds if b]
            if name == "move":
                expected = [entry["anchor"][1] - job.get("hover", 0)
                            + offset[1] for offset in animation["frame_offsets"]]
                bottoms = [b[3] - 1 for b in bounds if b]
                if bottoms != expected:
                    failures.append(f"{key} : ancre verticale {bottoms}, attendu {expected}")
            if name == "death" and heights[-1] >= heights[0] * .65:
                failures.append(key + " : mort non affaissée")
            areas = [np.count_nonzero(frame[:, :, 3]) for frame in frames]
            if name in ["rift_step", "portal_jump"] and min(areas) >= max(areas) * .15:
                failures.append(key + " : disparition peu lisible")
            animations[name] = {"bounds": bounds, "heights": heights, "unique_frames": unique,
                                "fps": spec["fps"], "loop": spec["loop"]}
        if identifier not in ELITES:
            death = entry["animations"]["death"]
            assert death["frames"] == 1 and not death["loop"]
            assert not image.crop((0, death["row"] * side, side, (death["row"] + 1) * side)).getbbox()
        hashes = json.loads((folder / "source/SHA256.json").read_text(encoding="utf-8"))
        icon = Image.open(ROOT / entry["icon"].removeprefix("res://")).convert("RGBA")
        icon_box = icon.getbbox()
        assert icon.size == (64, 64) and icon_box and min(icon_box[:2]) >= 3 and max(icon_box[2:]) <= 61
        for filename, value in hashes.items():
            if digest(folder / "source" / filename) != value:
                failures.append(key + " : empreinte source " + filename)
        report[key] = {"colors": len(palette), "cell": entry["cell"], "scale": .5,
                       "elite_runtime_factor": 1.5 if identifier in ELITES else 1,
                       "target_height": job["target_height"], "animations": animations,
                       "sheet_sha256": digest(ROOT / entry["sheet"].removeprefix("res://"))}
    poses = sum(sum(len(a["bounds"]) for a in v["animations"].values()) for v in report.values())
    result = {"sprites": report, "entities": len(report), "painted_poses": poses,
              "failures": failures, "ok": not failures, "text_hash_convention": "UTF-8, fins de ligne LF"}
    assert poses == 162
    write(output, result)
    print("SPRITES_AUDIT", len(report), "monstres", poses, "poses", len(failures), "erreurs", flush=True)
    for failure in failures:
        print(failure)
    return not failures


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(0 if check(args.out) else 1)
