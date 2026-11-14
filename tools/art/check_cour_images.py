#!/usr/bin/env python3
"""Contrôle des livrables bitmap et du placement déterministe de la Cour."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
COUR = ROOT / "draft3d/matter/cour"


def main():
    palette = {tuple(bytes.fromhex(color[1:])) for color in json.loads((COUR / "palette.json").read_text())["colors"]}
    assert len(palette) == 32
    ground_path = COUR / "terrain.png"
    ground = np.asarray(Image.open(ground_path).convert("RGB"))
    assert ground.shape == (640, 640, 3)
    values = ground.astype(int)
    assert not ((values[:, :, 1] > values[:, :, 0] + 4) & (values[:, :, 1] > values[:, :, 2] + 8)).any(), \
        "Il reste du vert peint dans la texture du sol"
    assert set(map(tuple, ground.reshape(-1, 3))) <= palette
    assert np.array_equal(ground[0], ground[-1]) and np.array_equal(ground[:, 0], ground[:, -1])
    assert "mipmaps/generate=false" in ground_path.with_suffix(".png.import").read_text()
    tiles = list((COUR / "textures").glob("*.png"))
    for path in tiles:
        image = np.asarray(Image.open(path).convert("RGB"))
        assert image.shape == (160, 160, 3), path
        assert set(map(tuple, image.reshape(-1, 3))) <= palette, path
        assert np.array_equal(image[0], image[-1]) and np.array_equal(image[:, 0], image[:, -1]), path
        assert "mipmaps/generate=false" in path.with_suffix(".png.import").read_text(), path
    manifest = json.loads((ROOT / "assets/asset_manifest.json").read_text(encoding="utf-8"))["entries"]
    details = json.loads((COUR / "details.json").read_text())
    assert len(details) >= 20
    for detail in details:
        entry = manifest[detail["id"]]
        assert entry["anchor"] == [32, 60] and entry["scale"] == 0.5 and entry["filter"] == "nearest"
        job = json.loads((ROOT / entry["imported_from"]).read_text())
        assert job["collision"] is False
        path = ROOT / entry["sheet"].removeprefix("res://")
        image = np.asarray(Image.open(path).convert("RGBA"))
        assert image.shape == (64, 64, 4) and set(np.unique(image[:, :, 3])) <= {0, 255}
        assert image[60:, :, 3].max() == 0, detail
        assert set(map(tuple, image[image[:, :, 3] > 0, :3])) <= palette
        assert path.read_bytes() == (ROOT / entry["imported_from"]).with_name("idle.png").read_bytes()
    placement_path = COUR / "placements.json"
    before = placement_path.read_bytes()
    subprocess.run([sys.executable, str(ROOT / "tools/art/place_cour_details.py")], check=True)
    assert placement_path.read_bytes() == before, "Le placement n'est pas reproductible"
    placement = json.loads(before)
    assert placement["collision"] is False
    placed_ids = {p["visual_id"] for p in placement["placements"]}
    assert placed_ids <= {d["id"] for d in details} and len(placed_ids) >= 20
    assert not placed_ids & {"object.cour_crack_thin", "object.cour_crack_branch"}
    for path in (COUR / "materials").glob("*.tres"):
        assert "texture_filter = 0" in path.read_text(), path
    print(json.dumps({"status": "conforme", "palette": len(palette), "seamless_tiles": len(tiles),
                      "continuous_ground": "640px / 16m", "anchored_details": len(details),
                      "placements": len(placement["placements"]),
                      "placement_sha256": hashlib.sha256(before).hexdigest()}, ensure_ascii=False))


if __name__ == "__main__":
    main()
