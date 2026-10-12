#!/usr/bin/env python3
"""Génère les sprites de travail (pixel art) et met à jour assets/asset_manifest.json.

Usage : python3 tools/art/build.py [préfixe ...]
  ex. python3 tools/art/build.py monster.ashblade
Chaque module de tools/art/creatures/ expose SPECS (liste d'EntitySpec).
Les entrées dont le statut est « final » dans le manifeste ne sont jamais écrasées.
"""
import importlib
import json
import os
import pkgutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import creatures  # noqa: E402
from pixelforge import build_entity  # noqa: E402

MANIFEST = os.path.join(REPO, "assets", "asset_manifest.json")
PREVIEWS = os.path.join(REPO, "assets", "concepts", "previews")


def all_specs():
    specs = []
    for info in pkgutil.iter_modules(creatures.__path__):
        module = importlib.import_module("creatures." + info.name)
        specs.extend(getattr(module, "SPECS", []))
    return specs


def main(prefixes):
    with open(MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)
    entries = manifest["entries"]
    built = 0
    for spec in all_specs():
        if prefixes and not any(spec.visual_id.startswith(p) for p in prefixes):
            continue
        if entries.get(spec.visual_id, {}).get("status") == "final":
            print(f"ignoré (final) : {spec.visual_id}")
            continue
        entries[spec.visual_id] = build_entity(spec, REPO, PREVIEWS)
        built += 1
        print(f"généré : {spec.visual_id}")
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent="\t", ensure_ascii=False)
        f.write("\n")
    print(f"{built} entité(s) générée(s). Lancer ensuite : godot --headless --import --path .")


if __name__ == "__main__":
    main(sys.argv[1:])
