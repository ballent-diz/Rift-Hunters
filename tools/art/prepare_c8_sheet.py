#!/usr/bin/env python3
"""Découpe une planche C8 générée 8 colonnes × 5 lignes ; conserve les originaux et écrit les plages explicites."""
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from echo_sprite_specs import C8_ECHOS

ROOT = Path(__file__).resolve().parents[2]
NAMES = ["idle", "move", "attack", "technique", "death"]
COUNTS = [8, 8, 7, 8, 8]


def separator(activity, nominal, radius):
    start, end = max(1, nominal-radius), min(len(activity)-1, nominal+radius)
    positions = np.arange(start, end)
    empty = positions[activity[start:end] == 0]
    if not len(empty):
        raise ValueError(f"Aucune séparation vide près de {nominal} : vérifier la planche avant découpe")
    # Le centre du segment vide le plus proche évite de couper juste au bord d'une silhouette.
    groups = np.split(empty, np.where(np.diff(empty) > 1)[0] + 1)
    group = min(groups, key=lambda g: abs(float(np.median(g))-nominal))
    return int(np.median(group))


def prepare(echo_id):
    folder = ROOT / "assets/concepts/incoming" / ("monster."+echo_id)
    source = folder / "source/sheet.png"
    image = Image.open(source).convert("RGBA")
    data = np.asarray(image).astype(np.int16)
    green = np.array([0, 214, 72])
    mask = (np.max(np.abs(data[:, :, :3]-green), axis=2) > 42) & (data[:, :, 3] > 128)
    width, height = image.size
    row_edges = [0] + [separator(mask.sum(axis=1), round(height*i/5), max(8, height//20)) for i in range(1,5)] + [height]
    overrides_path = folder / "source/overrides.json"
    overrides = json.loads(overrides_path.read_text(encoding="utf-8")) if overrides_path.exists() else {}
    job_path = folder / "job.json"
    job = json.loads(job_path.read_text(encoding="utf-8"))
    report = {"id": echo_id, "source_size": image.size, "rows": row_edges, "animations": {}}
    for index, (name, count) in enumerate(zip(NAMES, COUNTS)):
        top, bottom = row_edges[index:index+2]
        activity = mask[top:bottom].sum(axis=0)
        try:
            columns = [0] + [separator(activity, round(width*i/8), max(6,width//20)) for i in range(1,8)] + [width]
        except ValueError as error:
            raise ValueError(f"{echo_id}/{name}: {error}") from error
        if name in overrides.get("ranges", {}):
            chosen = overrides["ranges"][name]
            columns = [chosen[0][0]] + [pair[1] for pair in chosen]
        if len(set(columns)) != len(columns):
            raise ValueError(f"{echo_id}/{name} : séparations répétées")
        right = columns[count]
        image.crop((0,top,right,bottom)).save(folder/(name+".png"))
        ranges = [[columns[i], columns[i+1]] for i in range(count)]
        areas = [int(mask[top:bottom, a:b].sum()) for a,b in ranges]
        if name in ("idle", "move") and max(areas) > np.median(areas) * 1.8:
            raise ValueError(f"{echo_id}/{name} : deux silhouettes possibles dans une pose")
        if min(areas) < 4:
            raise ValueError(f"{echo_id}/{name} : pose vide")
        job["animations"][index]["ranges"] = ranges
        job["animations"][index]["layout"] = "row"
        report["animations"][name] = {"frames": count, "ranges": ranges, "opaque_areas": areas}
    job_path.write_text(json.dumps(job,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    (folder/"source/slicing.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    return report


if __name__ == "__main__":
    failed = False
    for creature_id in sys.argv[1:] or C8_ECHOS:
        try:
            result = prepare(creature_id)
            print(creature_id, result["rows"], "39 poses découpées")
        except (ValueError, FileNotFoundError) as error:
            failed = True
            print(creature_id, "À VÉRIFIER :", error)
    sys.exit(1 if failed else 0)
