#!/usr/bin/env python3
"""Build collision data only; the three supplied PNGs are displayed unchanged."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage
from build_map import hue_sat_light

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/environments/three_rifts"
UNIT = 2.0
STEP = 2.0


def build():
    images = [Image.open(BASE / name).convert("RGB") for name in ("L1.png", "L1p2.png", "L1p3.png")]
    assert all(image.size == (1254, 1254) for image in images)
    panels = []
    for index, image in enumerate(images):
        rgb = np.array(image.resize((627, 627), Image.Resampling.BOX))
        hue, sat, light = hue_sat_light(rgb)
        walk = (hue > 20) & (hue < 65) & (light > .28) & (light < .79) & (sat > .25)
        walk = np.array(Image.fromarray(walk.astype("uint8") * 255).filter(ImageFilter.MedianFilter(5))) > 128
        layer = Image.new("L", (627, 627))
        draw = ImageDraw.Draw(layer)
        def polygon(points):
            draw.polygon([(x / 2, y / 2) for x, y in points], fill=255)
        def ellipse(bounds):
            draw.ellipse([v / 2 for v in bounds], fill=255)
        if index == 0:
            draw.line([(320, 300), (425, 270), (500, 295)], fill=255, width=40)
            # Stone sanctuary, staircase, and existing east bridge deck.
            ellipse((40, 802, 325, 966))
            polygon([(190, 945), (285, 930), (450, 1135), (372, 1195)])
            polygon([(984, 553), (1254, 570), (1254, 655), (973, 620)])
        elif index == 1:
            draw.line([(0, 310), (175, 305), (235, 294), (310, 330), (420, 310), (550, 303)], fill=255, width=40)
            polygon([(75, 580), (395, 575), (395, 638), (75, 640)])
            polygon([(1080, 575), (1254, 560), (1254, 628), (1080, 628)])
            polygon([(870, 595), (1090, 572), (1120, 637), (925, 698)])
            ellipse((554, 127, 804, 223))
            polygon([(690, 204), (765, 207), (780, 255), (700, 268)])
        else:
            draw.line([(100, 280), (180, 285), (230, 300), (290, 310)], fill=255, width=40)
            # The violet arena is stone, so hue-based terrain recognition cannot identify it.
            ellipse((439, 350, 1310, 862))
            polygon([(0, 535), (238, 537), (238, 595), (0, 616)])
            polygon([(210, 546), (358, 586), (504, 635), (531, 575), (378, 531), (243, 515)])
            polygon([(280, 320), (400, 335), (588, 425), (530, 470), (369, 390)])
            polygon([(290, 805), (397, 749), (617, 774), (611, 841), (402, 897)])
        walk |= np.array(layer) > 128
        panels.append(walk)
    walk = np.concatenate(panels, axis=1)
    # Remove tiny decorative cracks, preserve cliffs/water, discard inaccessible islands.
    holes, count = ndimage.label(~walk)
    sizes = np.bincount(holes.ravel())
    walk |= (sizes[holes] < 24) & (holes > 0)
    labels, count = ndimage.label(walk)
    sizes = np.bincount(labels.ravel())
    sizes[0] = 0
    walk = labels == sizes.argmax()
    inside = ndimage.distance_transform_edt(walk) * UNIT
    outside = ndimage.distance_transform_edt(~walk) * UNIT
    signed = np.where(walk, inside, -outside)
    field = np.clip(np.round(signed / STEP) + 128, 0, 255).astype("uint8")
    # Safe start near the first map's central road.
    yy, xx = np.mgrid[:627, :1881]
    score = np.where((signed >= 36) & (xx < 627), -np.hypot(xx - 320, yy - 320), -np.inf)
    assert np.isfinite(score.max()), "No safe start in map 1"
    sy, sx = np.unravel_index(score.argmax(), score.shape)
    start = [(sx + .5) * UNIT - 1881, (sy + .5) * UNIT - 627]
    # Ensure a player/normal enemy can traverse all three regions, including both seams.
    clear = signed >= 16
    components, _ = ndimage.label(clear)
    connected = components == components[sy, sx]
    assert components[sy, sx] > 0
    assert connected[:, 627:1254].any(), "Map 2 unreachable with clearance"
    assert connected[270:330, 1640:1780].any(), "Violet arena unreachable with clearance"
    # Runtime flow uses a 16-unit lattice. Verify that representation too.
    gy, gx = np.mgrid[8:1254:16, 8:3762:16]
    grid_clear = ndimage.map_coordinates(signed, [gy/2-.5, gx/2-.5], order=1) >= 16
    grid_labels, _ = ndimage.label(grid_clear)
    grid_start = grid_labels[int((start[1]+627)//16), int((start[0]+1881)//16)]
    assert grid_start > 0 and (grid_labels[:, 180:] == grid_start).any(), "Runtime flow cannot reach map 3"
    Image.fromarray(field).save(BASE / "field.png")
    report = {"start": start, "walkable_percent": round(float(walk.mean()) * 100, 1),
              "clearance": 16, "connected_panels": 3, "source_sizes": [[1254, 1254]] * 3}
    (BASE / "collision_report.json").write_text(json.dumps(report, indent=2) + "\n")
    manifest_path = ROOT / "assets/asset_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    paths = ["res://assets/environments/three_rifts/" + n for n in ("L1.png", "L1p2.png", "L1p3.png")]
    manifest["entries"]["environment.three_rifts"] = {
        "status": "final", "kind": "map", "map": paths[0], "map_tiles": paths,
        "field": "res://assets/environments/three_rifts/field.png",
        "field_step": STEP, "arena_size": 3762, "start": start, "filter": "nearest",
        "generated_by": "tools/art/build_three_rifts.py", "ambient": {"amount": 0}}
    manifest_path.write_text(json.dumps(manifest, indent="	", ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report))

if __name__ == "__main__":
    build()
