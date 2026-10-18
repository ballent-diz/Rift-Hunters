#!/usr/bin/env python3
"""Prépare les ressources C5-bis et leurs recettes, sans donnée de gameplay ni fichier de src/."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROLES = ("might", "focus", "spell_base", "spell_alt", "signature")


def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def rgba(value):
    v = value.lstrip("#")
    return ", ".join(str(int(v[i:i + 2], 16) / 255) for i in (0, 2, 4)) + ", 1"


def prepare():
    specs = json.loads((ROOT / "assets/vfx/echoes/catalog.json").read_text(encoding="utf-8"))
    manifest_path = ROOT / "assets/asset_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    entries = manifest["entries"]
    rows = []
    for spec in specs:
        identity = spec["id"]
        for role in ROLES:
            visual_id = f"icon.echo.{identity}_{role}"
            folder = ROOT / "assets/concepts/incoming" / visual_id
            job = {
                "visual_id": visual_id, "cell": [512, 512], "anchor": [256, 256],
                "scale": 1, "target_height": 448, "status": "wip", "background": "alpha",
                "colors": 0, "outline": False, "anchor_mode": "mass", "resample": "lanczos",
                "preserve_alpha": True, "icon_size": 512, "preview_zoom": 1,
                "animations": [{"name": "idle", "source": "source/icon.png", "frames": 1,
                                "fps": 1, "loop": True, "layout": "row"}],
            }
            write(folder / "job.json", json.dumps(job, ensure_ascii=False, indent=2) + "\n")
            write(folder / "source/PROMPT.txt", spec["prompt_" + role] + "\n")
        families = list(zip(("attack", spec["base"], spec["alt"]), spec["forms"]))
        families += [("status", spec["status"]), ("indicator", "indicator")]
        for name, form in families:
            duration = 0.75 if name == "attack" else 1.6
            if name == "status":
                duration = 2.0
            size = 44 if name in ("attack", "status") else 88
            shape = "line" if form in ("dash", "flow", "leap", "projectile") else "area"
            if form == "cone":
                shape = "cone"
            if name == "indicator":
                shape = "line" if spec["forms"][1] == "flow" else "area"
            scene = f"assets/vfx/echoes/{identity}/{name}.tscn"
            write(ROOT / scene, f'''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://assets/vfx/echoes/echo_effect.gd" id="1"]

[node name="{identity}_{name}" type="Node2D"]
script = ExtResource("1")
echo_id = &"{identity}"
effect_kind = &"{form}"
color = Color({rgba(spec['color'])})
accent = Color({rgba(spec['accent'])})
radius = {float(size)}
visual_duration = {duration}
travel_distance = {0.0 if name == 'status' else (180.0 if name == 'attack' else 240.0)}
target_shape = &"{shape}"
''')
            # Affiche de catalogue seulement : les animations restent natives Godot.
            poster = f"assets/vfx/echoes/{identity}/poster.svg"
            write(ROOT / poster, f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<path d="M10 40 L30 10 L49 22 L34 54Z" fill="{spec['color']}"/>
<path d="M30 10 L34 54 L49 22Z" fill="{spec['accent']}"/></svg>\n''')
            entries[f"vfx.echo.{identity}.{name}"] = {
                "status": "wip", "scene": "res://" + scene, "sheet": "res://" + poster,
                "cell": [64, 64], "anchor": [32, 32], "scale": 1,
                "animations": {"idle": {"row": 0, "frames": 1, "fps": 1, "loop": False}},
                "visual_only": True, "duration": duration,
            }
            rows.append({"echo": identity, "name": name, "form": form, "scene": "res://" + scene,
                         "duration": duration, "radius": size, "target_shape": shape})
    write(ROOT / "assets/vfx/echoes/effects_catalog.json", json.dumps(rows, ensure_ascii=False, indent=2) + "\n")
    write(manifest_path, json.dumps(manifest, ensure_ascii=False, indent="\t") + "\n")
    print(f"{len(rows)} scènes autonomes ; 45 recettes d'icônes préparées.")


if __name__ == "__main__":
    prepare()
