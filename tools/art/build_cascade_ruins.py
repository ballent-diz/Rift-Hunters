#!/usr/bin/env python3
"""Collisions de la carte continue : chemins dégagés, cailloux décoratifs sans collision."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage
from build_map import hue_sat_light

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/environments/cascade_ruins"
WORLD = (5016, 1672)
FIELD = (2508, 836)
STEP = 2.0


def build():
    source = Image.open(ROOT / "assets/concepts/incoming/map.three_rifts/source/map_revised.png").convert("RGB")
    assert abs(source.width / source.height - 3) < .001
    small = source.resize(FIELD, Image.Resampling.BOX)
    hue, sat, light = hue_sat_light(np.array(small))
    walk = (hue > 19) & (hue < 68) & (light > .25) & (light < .88) & (sat > .16)
    walk = np.array(Image.fromarray(walk.astype("uint8") * 255).filter(ImageFilter.MedianFilter(5))) > 128
    layer = Image.new("L", FIELD)
    draw = ImageDraw.Draw(layer)

    def polygon(points):
        draw.polygon([(int(x * FIELD[0]), int(y * FIELD[1])) for x, y in points], fill=255)

    def route(points, width=.075):
        pixels = [(int(x * FIELD[0]), int(y * FIELD[1])) for x,y in points]
        size = int(FIELD[1] * width)
        draw.line(pixels, fill=255, width=size, joint="curve")
        for x,y in (pixels[0],pixels[-1]):
            half = size / 2
            draw.ellipse((x-half,y-half,x+half,y+half),fill=255)

    # Le pont occidental est détruit. Seul le second tablier reste praticable.
    polygon([(.643, .518), (.757, .516), (.757, .581), (.643, .584)])
    route([(.625,.55), (.665,.55), (.745,.55), (.79,.56)], .065)
    # Passage alternatif sur le plateau supérieur, dessiné dans la carte.
    route([(.065,.20), (.17,.245), (.28,.23), (.30,.10), (.35,.08), (.39,.14), (.45,.215), (.50,.265), (.575,.38), (.615,.50)], .07)
    polygon([(.04,.175), (.085,.175), (.085,.23), (.04,.23)])
    # Sol de pierre du sanctuaire et de la plateforme violette.
    draw.ellipse((FIELD[0]*.004, FIELD[1]*.724, FIELD[0]*.124, FIELD[1]*.886), fill=255)
    route([(.075, .84), (.126, .976)], .055)
    draw.ellipse((FIELD[0]*.745, FIELD[1]*.296, FIELD[0]*1.05, FIELD[1]*.859), fill=255)
    route([(.715, .552), (.76, .575), (.825, .575)], .055)
    # Escaliers visibles : leurs deux débouchés sont ouverts, hors piliers et falaises.
    route([(.046,.101),(.052,.137),(.062,.177),(.08,.215)], .06)
    route([(.781,.325),(.795,.38),(.812,.425),(.84,.48)], .06)
    route([(.77,.76),(.792,.723),(.805,.68),(.819,.64),(.848,.595)], .055)
    # Carrefours et clairières : surfaces où tourner, pas uniquement des rubans de route.
    for cx, cy, rx, ry in [(.15,.52,.029,.075), (.44,.56,.025,.075), (.615,.56,.032,.08),
                           (.49,.83,.035,.08)]:
        draw.ellipse((FIELD[0]*(cx-rx), FIELD[1]*(cy-ry), FIELD[0]*(cx+rx), FIELD[1]*(cy+ry)), fill=255)
    walk |= np.array(layer) > 128
    # Remplir les petites poches bloquées au milieu du sol (cailloux), garder falaises et eau.
    holes, _ = ndimage.label(~walk)
    counts = np.bincount(holes.ravel())
    walk |= (holes > 0) & (counts[holes] <= 600)
    walk = ndimage.binary_closing(walk, iterations=6)
    # Trou du pont : le joueur ne peut pas franchir le vide, même avec une esquive.
    gap = Image.new("L", FIELD)
    gd = ImageDraw.Draw(gap)
    gd.rectangle((FIELD[0]*.334, FIELD[1]*.49, FIELD[0]*.370, FIELD[1]*.63), fill=255)
    walk &= np.array(gap) == 0
    components, _ = ndimage.label(walk)
    counts = np.bincount(components.ravel())
    counts[0] = 0
    walk = components == counts.argmax()
    inside = ndimage.distance_transform_edt(walk) * 2
    outside = ndimage.distance_transform_edt(~walk) * 2
    signed = np.where(walk, inside, -outside)
    # Départ sur la grande route du secteur occidental.
    yy, xx = np.mgrid[:FIELD[1], :FIELD[0]]
    score = np.where((signed >= 36) & ((xx < FIELD[0]*.15) & (yy < FIELD[1]*.28)),
                     -np.hypot(xx - FIELD[0]*.065, yy - FIELD[1]*.19), -np.inf)
    assert np.isfinite(score.max())
    sy, sx = np.unravel_index(score.argmax(), score.shape)
    start = [(sx+.5)*2-WORLD[0]/2, (sy+.5)*2-WORLD[1]/2]
    gy, gx = np.mgrid[8:WORLD[1]:16, 8:WORLD[0]:16]
    clear = ndimage.map_coordinates(signed, [gy/2-.5, gx/2-.5], order=1) >= 16
    labels, _ = ndimage.label(clear)
    component = labels[int((start[1]+WORLD[1]/2)//16), int((start[0]+WORLD[0]/2)//16)]
    assert component > 0 and (labels[:, int(WORLD[0]*.79/16):] == component).any(), "Plateforme inaccessible"
    field = np.clip(np.round(signed / STEP)+128, 0, 255).astype("uint8")
    Image.fromarray(field).save(BASE / "field.png")
    report = {"source_size": list(source.size), "world_size": list(WORLD),
              "start": start, "clearance": 16, "small_rocks_blocking": False,
              "connected": True, "walkable_percent": round(float(walk.mean())*100, 1)}
    (BASE / "collision_report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    manifest_path = ROOT / "assets/asset_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["entries"]["environment.cascade_ruins"] = {
        "status": "final", "kind": "map", "map": "res://assets/environments/cascade_ruins/map.webp",
        "map_tiles": ["res://assets/environments/cascade_ruins/" + name for name in ("map.webp", "map_1.webp", "map_2.webp")],
        "detail_strength": .32,
        "field": "res://assets/environments/cascade_ruins/field.png", "field_step": STEP,
        "arena_size": WORLD[0], "start": start, "filter": "linear", "ambient": {"amount": 0},
        "generated_by": "tools/art/build_cascade_ruins.py"}
    manifest_path.write_text(json.dumps(manifest, indent="\t", ensure_ascii=False)+"\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    build()
