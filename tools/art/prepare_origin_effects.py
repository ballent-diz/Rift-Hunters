#!/usr/bin/env python3
"""Catalogue C5-ter ; ressources de présentation, aucune donnée de gameplay modifiée."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPECS = [
    {"id": "ashblade", "name": "Cendrelame", "color": "ed792b", "accent": "ffc979",
     "attack": ["blade_pounce", 42, 0.65, 140], "status": None,
     "spells": [["ash_dance", "ash_dance", 48, 1.6, 0, "area"],
                ["cinder_dash", "cinder_dash", 48, 0.75, 240, "line"]]},
    {"id": "mossback", "name": "Mousseroc", "color": "e77b31", "accent": "ffc36c",
     "attack": ["stone_slam", 95, 0.6, 0], "status": "fracture",
     "spells": [["gravity_well", "stone_gravity", 110, 2.4, 0, "area"],
                ["stone_taunt", "stone_taunt", 100, 1.6, 0, "area"]]},
    {"id": "glimmerwing", "name": "Lucivelle", "color": "60c7ed", "accent": "e2f6ff",
     "attack": ["prism_orb", 30, 0.6, 180], "status": "prism_mark",
     "spells": [["prism_flare", "prism_flare", 95, 1.1, 0, "area"],
                ["spark_rain", "spark_rain", 95, 1.6, 0, "area"]]},
    {"id": "thornweave", "name": "Ronceline", "color": "668951", "accent": "dfc77b",
     "attack": ["thorn_patch", 75, 4.0, 0], "status": "roots",
     "spells": [["briar_wall", "briar_wall", 44, 4.0, 240, "line"],
                ["bloom", "bloom", 95, 1.6, 0, "area"]]},
    {"id": "voltwisp", "name": "Fulgurine", "color": "6297ad", "accent": "f4c75c",
     "attack": ["chain", 30, 0.5, 180], "status": "electrified",
     "spells": [["ion_storm", "ion_storm", 110, 1.8, 0, "area"],
                ["chain_arc", "chain", 30, 0.75, 240, "line"]]},
    {"id": "gloommaw", "name": "Gueule-d’ombre", "color": "534178", "accent": "bba1df",
     "attack": ["devour", 32, 0.65, 0], "status": None,
     "spells": [["feast", "feast", 100, 1.1, 0, "area"],
                ["maw_pit", "maw_pit", 95, 1.8, 0, "area"]]},
    {"id": "mirrorling", "name": "Mirelle", "color": "91b4e7", "accent": "f0f5ff",
     "attack": ["mirror_bolt", 30, 0.65, 180], "status": None,
     "spells": [["reflection", "reflection", 65, 2.0, 0, "area"],
                ["mirror_shards", "mirror_shards", 30, 0.8, 240, "line"]]},
]


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def rgba(value):
    return ", ".join(str(int(value[i:i + 2], 16) / 255) for i in (0, 2, 4)) + ", 1"


def main():
    manifest_path = ROOT / "assets/asset_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    catalog = []
    for spec in SPECS:
        identity = spec["id"]
        effect, radius, duration, distance = spec["attack"]
        scenes = [["attack", effect, radius, duration, distance, "area"]] + spec["spells"]
        if spec["status"]:
            scenes += [["status", spec["status"], 20, 1.2, 0, "area"]]
        scenes += [["indicator", "indicator", 95, 1.6, 240, "area"]]
        poster = f"assets/vfx/echoes/{identity}/poster.svg"
        write(ROOT / poster, f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64">
<path d="M9 45L29 9L53 22L36 55Z" fill="#{spec['color']}"/>
<path d="M29 9L36 55L53 22Z" fill="#{spec['accent']}"/></svg>\n''')
        for name, form, radius, duration, distance, shape in scenes:
            scene = f"assets/vfx/echoes/{identity}/{name}.tscn"
            write(ROOT / scene, f'''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://assets/vfx/echoes/origin_effect.gd" id="1"]

[node name="{identity}_{name}" type="Node2D"]
script = ExtResource("1")
echo_id = &"{identity}"
effect_kind = &"{form}"
color = Color({rgba(spec['color'])})
accent = Color({rgba(spec['accent'])})
radius = {float(radius)}
visual_duration = {float(duration)}
travel_distance = {float(distance)}
target_shape = &"{shape}"
loop_visual = {"true" if name == "reflection" else "false"}
''')
            entry_id = f"vfx.echo.{identity}.{name}"
            manifest["entries"][entry_id] = {
                "status": "wip", "scene": "res://" + scene, "sheet": "res://" + poster,
                "cell": [64, 64], "anchor": [32, 32], "scale": 1,
                "animations": {"idle": {"row": 0, "frames": 1, "fps": 1, "loop": False}},
                "visual_only": True, "duration": duration,
            }
            catalog.append({"echo": identity, "name": name, "form": form, "scene": "res://" + scene,
                            "radius": radius, "duration": duration, "distance": distance, "shape": shape})
    write(ROOT / "assets/vfx/echoes/origin_catalog.json", json.dumps(SPECS, ensure_ascii=False, indent=2) + "\n")
    write(ROOT / "assets/vfx/echoes/origin_scenes.json", json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    write(manifest_path, json.dumps(manifest, ensure_ascii=False, indent="\t") + "\n")
    print(f"C5-ter : {len(catalog)} scènes préparées, sept Échos ; aucun fichier de src/ ou data/ modifié.")


if __name__ == "__main__":
    main()
