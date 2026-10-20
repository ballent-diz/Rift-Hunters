#!/usr/bin/env python3
"""Prépare l'image validée du Gué des Brumes, sans produire de collisions."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/concepts/incoming/map.mist_ford"
OUT = ROOT / "docs/previews/gue-des-brumes"


def prepare():
    original = BASE / "source/map_connected.png"
    restored = BASE / "source/map_upscaled.png"
    image = Image.open(restored).convert("RGB")
    assert image.size == (6144, 4096)
    target = ROOT / "assets/environments/mist_ford"
    target.mkdir(parents=True, exist_ok=True)
    native = target / "map.webp"
    image.save(native, lossless=True, method=3)
    shutil.copyfile(native, BASE / "source/map_upscaled.webp")
    with Image.open(native) as check:
        assert check.convert("RGB").tobytes() == image.tobytes()
    (BASE / "collision").mkdir(exist_ok=True)
    working = image.resize((5016, 3344), Image.Resampling.LANCZOS)
    working.save(BASE / "collision/carte_a_peindre.png", compress_level=6)
    overview = image.copy()
    overview.thumbnail((1800, 1200))
    OUT.mkdir(parents=True, exist_ok=True)
    overview.save(OUT / "carte-entiere.png")
    source_hashes = []
    for path in sorted((BASE / "source").rglob("*")):
        if path.is_file() and path.name not in ["SHA256SUMS.txt", "map_upscaled.png"]:
            source_hashes.append(hashlib.sha256(path.read_bytes()).hexdigest()+"  "+
                                 path.relative_to(BASE / "source").as_posix())
    (BASE / "source/SHA256SUMS.txt").write_bytes(("\n".join(source_hashes)+"\n").encode("utf-8"))
    job = {
        "id": "map.mist_ford", "status": "final", "mode": "built-in image_gen",
        "validation_proprietaire": "Carte et accès corrigés validés le 20 octobre 2026",
        "source": "source/map_source.png", "selected_source": "source/map_connected.png",
        "source_size": [1536, 1024], "world_size": [5016, 3344],
        "working_image": "collision/carte_a_peindre.png", "working_size": [5016, 3344],
        "presentation": "res://assets/environments/mist_ford/map.webp",
        "presentation_size": [6144, 4096],
        "prompts": {"master": "source/PROMPT.txt", "connectivity": "source/PROMPT-connectivity.txt"},
        "references": [
            "assets/environments/fractured_plain_map/map.webp",
            "assets/environments/cascade_ruins/map.webp",
            "assets/environments/storm_highlands/map.webp",
            "source/references/firefly_woods.webp (PR #36, commit 794620e)"
        ],
        "upscale": {
            "tool": "Real-ESRGAN ncnn Vulkan 20220424",
            "model": "realesr-animevideov3", "factor": 4, "tile": 128,
            "command": "realesrgan-ncnn-vulkan -i map_connected.png -o map_upscaled.png "
                       "-n realesr-animevideov3 -s 4 -t 128 -j 1:1:1",
            "source": "https://github.com/xinntao/Real-ESRGAN/releases/tag/v0.2.5.0",
            "note": "Restauration apprise des contours et textures, puis conversion WebP sans perte. "
                    "La résolution source reste 1536 × 1024 ; aucune nouvelle composition générée."
        },
        "preparation": "tools/art/prepare_mist_ford.py",
        "collision_handoff": {
            "owner_paints": True, "rectangles_generated": False, "mask_generated": False,
            "runtime_registered": False,
            "note": "Le propriétaire gère seul les collisions et les rectangles. Claude raccorde ensuite "
                    "l'autel, les gués, les vagues et le gardien. L'eau profonde bloque ; les gués restent ouverts."
        },
        "native_sha256": hashlib.sha256(native.read_bytes()).hexdigest(),
        "working_sha256": hashlib.sha256((BASE / "collision/carte_a_peindre.png").read_bytes()).hexdigest()
    }
    (BASE / "job.json").write_text(json.dumps(job, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"source": [1536, 1024], "presentation": image.size,
                      "working": working.size, "source_files": len(source_hashes),
                      "native_bytes": native.stat().st_size}, ensure_ascii=False))


if __name__ == "__main__":
    prepare()
