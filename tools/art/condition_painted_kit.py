#!/usr/bin/env python3
"""Ajuste les gabarits peints à des îlots coplanaires, sans modifier les sommets des modules."""
import json
import math
import shutil
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "draft3d/matter/painted_kit"
SCALES = {"wall": [1, 1, 1], "stairs_wide": [1, 0.5, 1.5], "pillar_decorated": [1, 1, 1],
          "wall_cracked": [1, 1, 1], "wall_broken": [1, 1, 1], "wall_doorway": [1, 1, 1]}
DENSITY = 40


def save_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def islands(points):
    """Composantes partageant une arête ET le même plan ; pas de raccord entre blocs séparés."""
    triangles = points.reshape(-1, 3, 3)
    cross = np.cross(triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0])
    lengths = np.linalg.norm(cross, axis=1)
    normals = -cross / np.maximum(lengths[:, None], 1e-12)
    parent = list(range(len(triangles)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    edges = defaultdict(list)
    for i, triangle in enumerate(triangles):
        for a, b in [(0, 1), (1, 2), (2, 0)]:
            key = tuple(sorted([tuple(np.round(triangle[a], 4)), tuple(np.round(triangle[b], 4))]))
            for j in edges[key]:
                if np.dot(normals[i], normals[j]) > 0.9999:
                    plane_error = abs(np.dot(normals[i], triangles[i, 0] - triangles[j, 0]))
                    if plane_error < 0.0002:
                        parent[find(i)] = find(j)
            edges[key].append(i)
    groups = defaultdict(list)
    for i in range(len(triangles)):
        groups[find(i)].append(i)
    return [(indices, normals[indices[0]], float(lengths[indices].sum() * 0.5)) for indices in groups.values()]


def project(points, normal):
    axis = int(np.argmax(np.abs(normal)))
    if axis == 1:
        return points[:, [0, 2]], axis
    return np.column_stack([points[:, 0] if axis == 2 else points[:, 2], -points[:, 1]]), axis


def face_image(module, normal, area, projected, bounds, panels):
    lo, hi = bounds
    size = np.maximum(hi - lo, 0.001)
    width, height = [max(2, math.ceil(float(s) * DENSITY)) for s in size]
    axis = int(np.argmax(np.abs(normal)))
    if module == "stairs_wide" and normal[1] > 0.7:
        source = panels[1].crop((0, 0, 320, 32))
        role = "tread_worn_front_edge"
    elif module == "stairs_wide" and axis == 2 and size[1] <= 0.4:
        source = panels[1].crop((0, 32, 320, 64))
        role = "riser_lower_seam"
    elif module == "pillar_decorated" and axis != 1:
        # Hauteur globale du pilier : le pied humide ne se répète pas sur chaque segment.
        box = ((0.5 + lo[0] / 4) * 160, (0.5 + lo[1] / 4) * 160,
               (0.5 + hi[0] / 4) * 160, (0.5 + hi[1] / 4) * 160)
        # V = -Y ; la texture peinte va du sommet (0) au pied (160).
        box = (box[0], (1 + lo[1] / 4) * 160, box[2], (1 + hi[1] / 4) * 160)
        source = panels[2].crop(tuple(round(v) for v in box))
        role = "pillar_height_registered"
    elif axis != 1 and area > 2.0:
        box = ((0.5 + lo[0] / 4) * 160, (1 + lo[1] / 4) * 160,
               (0.5 + hi[0] / 4) * 160, (1 + hi[1] / 4) * 160)
        box = tuple(max(0, min(160, round(v))) for v in box)
        if box[2] <= box[0] or box[3] <= box[1]:
            source = panels[3]
        else:
            source = panels[0].crop(box)
        role = "masonry_registered_in_height"
    else:
        source = panels[3]
        role = "individual_block_edge_wear"
    return source.resize((width, height), Image.Resampling.NEAREST), role


def pack(patches, atlas_width=512, max_height=2048):
    """Atlas de 512 px par défaut, gouttière de 2 px étendue aux bords ; dimensions réglables pour les grands props."""
    x = y = row_height = 0
    for patch in sorted(patches, key=lambda p: p["image"].height, reverse=True):
        width, height = patch["image"].size
        assert width + 4 <= atlas_width
        if x + width + 4 > atlas_width:
            x = 0
            y += row_height
            row_height = 0
        patch["at"] = (x + 2, y + 2)
        x += width + 4
        row_height = max(row_height, height + 4)
    height = 2 ** math.ceil(math.log2(max(y + row_height, 32)))
    assert height <= max_height
    atlas = Image.new("RGB", (atlas_width, height), patches[0]["image"].getpixel((0, 0)))
    for patch in patches:
        image, (x, y) = patch["image"], patch["at"]
        atlas.paste(image, (x, y))
        atlas.paste(image.crop((0, 0, image.width, 1)).resize((image.width, 2)), (x, y - 2))
        atlas.paste(image.crop((0, image.height - 1, image.width, image.height)).resize((image.width, 2)),
                    (x, y + image.height))
        atlas.paste(image.crop((0, 0, 1, image.height)).resize((2, image.height)), (x - 2, y))
        atlas.paste(image.crop((image.width - 1, 0, image.width, image.height)).resize((2, image.height)),
                    (x + image.width, y))
    return atlas


def main(source_path, geometry_path, only=None):
    OUT.mkdir(parents=True, exist_ok=True)
    raw = Image.open(source_path).convert("RGB")
    # Palette commune de 48 couleurs, sans tramage ; les sprites actuels dépassent eux-mêmes 32 couleurs.
    palette = raw.quantize(colors=48, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    panels = []
    for i in range(4):
        x, y = i % 2, i // 2
        box = (round(x * raw.width / 2) + 2, round(y * raw.height / 2) + 2,
               round((x + 1) * raw.width / 2) - 2, round((y + 1) * raw.height / 2) - 2)
        size = (320, 320) if i == 1 else (160, 160)
        panels.append(raw.crop(box).resize(size, Image.Resampling.NEAREST)
                      .quantize(palette=palette, dither=Image.Dither.NONE).convert("RGB"))
    geometry = json.loads(Path(geometry_path).read_text(encoding="utf-8"))
    if only:
        geometry = {key: geometry[key] for key in only.split(",")}
    report_path = OUT / "report.json"
    reports = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    panels[0].save(OUT / "masonry_tile.png")
    for module, surfaces in geometry.items():
        plans, patches = {}, []
        for s, surface in enumerate(surfaces):
            painted = surface["slot"] in ["stone", "cracks", "rubble", "moss"]
            positions = np.array(surface["positions"]) * np.array(SCALES[module])
            plans[str(s)] = {"painted": painted}
            if not painted:
                continue
            plans[str(s)]["uv"] = [[0.0, 0.0] for _ in positions]
            for indices, normal, area in islands(positions):
                vertices = [t * 3 + c for t in indices for c in range(3)]
                projected, axis = project(positions[vertices], normal)
                lo, hi = projected.min(axis=0), projected.max(axis=0)
                image, role = face_image(module, normal, area, projected, (lo, hi), panels)
                patches.append({"surface": str(s), "vertices": vertices, "projected": projected,
                                "lo": lo, "hi": hi, "image": image, "role": role})
        atlas = pack(patches)
        for patch in patches:
            x, y = patch["at"]
            width, height = patch["image"].size
            unit = (patch["projected"] - patch["lo"]) / np.maximum(patch["hi"] - patch["lo"], 1e-9)
            for vertex, point in zip(patch["vertices"], unit):
                # Centres des texels de bord : aucune fuite depuis la gouttière voisine.
                uv = [(x + 0.5 + point[0] * (width - 1)) / atlas.width,
                      (y + 0.5 + point[1] * (height - 1)) / atlas.height]
                plans[patch["surface"]]["uv"][vertex] = uv
        atlas.save(OUT / f"{module}.png")
        save_json(OUT / f"{module}_uv.json", {"module": module, "scale": SCALES[module],
                  "texels_per_m": DENSITY, "surfaces": plans})
        roles = defaultdict(int)
        for patch in patches:
            roles[patch["role"]] += 1
        reports[module] = {"atlas": list(atlas.size), "islands": len(patches), "roles": dict(roles)}
    save_json(OUT / "report.json", reports)
    incoming = ROOT / "assets/concepts/incoming/material.painted_kit"
    (incoming / "source").mkdir(parents=True, exist_ok=True)
    target = incoming / "source/templates.png"
    if Path(source_path).resolve() != target.resolve():
        shutil.copyfile(source_path, target)
    save_json(incoming / "job.json", {"visual_id": "material.painted_kit", "kind": "module_uv_templates",
              "status": "wip", "generated_with": "imagegen", "source": "source/templates.png",
              "grid": [2, 2], "colors": 48, "modules": list(SCALES), "texels_per_m": DENSITY,
              "roles": ["wall_height", "tread_riser_trims", "pillar_height", "individual_stone"],
              "geometry": "unchanged", "collisions": "unchanged"})
    print(json.dumps(reports, ensure_ascii=False))


if __name__ == "__main__":
    main(*sys.argv[1:4])
