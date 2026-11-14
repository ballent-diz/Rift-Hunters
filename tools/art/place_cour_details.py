#!/usr/bin/env python3
"""Placement déterministe de petits détails sans collision ; emprises et passages conservés."""
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "draft3d/matter/cour"
SEED = 241114
rng = random.Random(SEED)
definitions = json.loads((ROOT / "details.json").read_text(encoding="utf-8"))
by_name = {entry["name"]: entry for entry in definitions}
placements = []


def add(name, x, z, height=0.065, orientation=None):
    definition = by_name[name]
    placements.append({"name": f"detail_{len(placements):03d}_{name}", "visual_id": definition["id"],
                       "position": [round(x, 3), round(height, 3), round(z, 3)],
                       "orientation": orientation or ("upright" if definition["upright"] else "ground"),
                       "yaw": rng.choice([0, 90, 180, 270])})


for x in range(-46, 47, 4):
    height = 2.065 if abs(x) < 12 or x > 32 else 0.065
    add(rng.choice(["grass_olive", "grass_broad", "fern", "ivy"]), x + rng.uniform(-0.6, 0.6), -19.6, height)
    add(rng.choice(["root_moss", "leaves_green", "slate"]), x + 0.8, -19.2, height)
for side in [-1, 1]:
    for z in range(-16, 35, 5):
        add(rng.choice(["grass_olive", "grass_dry", "ivy"]), side * 47.7, z)
        add(rng.choice(["root_dry", "rubble", "gravel"]), side * 47, z + 0.9)
    for z in [-14, -2, 14, 30]:
        add("ivy", side * 23.8, z)
        add("root_moss", side * 23.4, z + 0.9)
    for z in [-4.5, 2.5]:
        add("grass_broad", side * 7.8, z + 0.5)
        add("slate", side * 8, z - 0.6)
    for x, z in [(19, 14), (20, -10), (9, 31)]:
        add("leaves_dry", side * x - 0.8, z + 1.0)
        add("gravel", side * x - 1.2, z + 0.4)
    add("root_dry", side * 8, -11.65)
    add("fern", side * 10.9, -11.55)

# Chaque variante retenue apparaît au moins deux fois, dans des recoins hors des principaux axes.
for i, entry in enumerate(definitions):
    name = entry["name"]
    if name.startswith("web"):
        add(name, -20 + (i % 4) * 4, -19.94, 1.2, "wall")
        add(name, 18 + (i % 3) * 4, -19.94, 1.6, "wall")
    else:
        side = -1 if i % 2 else 1
        x = side * (29 + (i % 4) * 4)
        z = 1 + (i // 4) * 5
        add(name, x, z)
        add(name, -x + 0.4, z + 1.8)

for _ in range(42):
    x, z = rng.uniform(-21, 21), rng.uniform(-4, 18)
    if abs(x) < 3 or abs(z - 10) < 2 or abs(abs(x) - 15) < 2:
        continue
    if abs(abs(x) - 7) < 1.6 and (abs(z + 4.5) < 1.6 or abs(z - 2.5) < 1.6):
        continue
    add(rng.choice(["crack_thin", "crack_branch", "damp", "leaves_dry"]), x, z)

result = {"seed": SEED, "units": "metres", "collision": False, "placements": placements}
(ROOT / "placements.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"{len(placements)} placements, {len({p['visual_id'] for p in placements})} variantes, seed {SEED}")
