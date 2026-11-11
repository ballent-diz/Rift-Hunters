#!/usr/bin/env python3
"""Ombres au sol calées sur l'empreinte des sprites (Échos et monstres).

  python3 tools/art/build_shadows.py            # mesure toutes les feuilles monster.* et enemy.* et écrit le manifeste
  python3 tools/art/build_shadows.py --check    # n'écrit rien, signale les entrées à recalculer (code 1)

Pourquoi : l'ombre était un disque de taille fixe centré sous les pieds les plus bas. Sous une créature large vue de
trois quarts (quadrupède, carapace), ce disque dépasse devant elle et elle semble flotter au-dessus. L'ombre suit
maintenant l'empreinte : aussi large que les appuis, centrée sur eux, son bord bas au ras des pieds les plus bas.
Une créature dont les pieds restent au-dessus de l'ancre (volants, spectres : au moins 3 unités) garde une petite
ombre au sol sous elle : elle seule flotte.

Champ écrit : "shadow": [cx, cy, rx, ry] en pixels de la feuille, relatif à l'ancre (EntityVisual le multiplie par
l'échelle). À relancer après l'import ou le changement d'ancre d'une feuille. Le Chasseur garde son ombre d'origine.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "asset_manifest.json"
PREFIXES = ("monster.", "enemy.")
# Pieds à plus de 3 unités au-dessus de l'ancre : créature qui flotte (ombre au sol, sous elle).
FLOAT_GAP = 3.0


def _num(value):
    """Un chiffre après la virgule ; entier quand il tombe juste (même écriture que l'éditeur Godot du manifeste)."""
    rounded = round(float(value), 1)
    return int(rounded) if rounded == int(rounded) else rounded


def measure(entry):
    """[cx, cy, rx, ry] en pixels de feuille, ou None si l'entrée n'a pas de feuille mesurable."""
    if "sheet" not in entry or "anchor" not in entry or "animations" not in entry:
        return None
    path = ROOT / entry["sheet"].replace("res://", "")
    if not path.exists():
        return None
    sheet = np.array(Image.open(path).convert("RGBA"))
    width, height = entry["cell"]
    anims = entry["animations"]
    anim = anims.get("idle") or anims.get("move") or next(iter(anims.values()))
    top = anim["row"] * height
    ax, ay = entry["anchor"]
    scale = float(entry.get("scale", 1.0))
    gaps = []
    for frame in range(int(anim["frames"])):
        cell = sheet[top:top + height, frame * width:(frame + 1) * width, 3] > 100
        rows = np.where(cell.any(axis=1))[0]
        if len(rows):
            gaps.append(ay - (rows.max() + 1))
    cell = sheet[top:top + height, 0:width, 3] > 100
    ys, xs = np.where(cell)
    if not len(ys) or not gaps:
        return None
    body_w = xs.max() - xs.min() + 1
    body_h = ys.max() - ys.min() + 1
    if float(np.median(gaps)) * scale >= FLOAT_GAP:
        rx = max(body_w * 0.26, 3.0)
        return [0, _num(1.0 / scale), _num(rx), _num(rx * 0.38)]
    band = cell[max(ys.max() - max(int(body_h * 0.12), 2), 0):ys.max() + 1]
    cols = np.where(band.any(axis=0))[0]
    foot_w = cols.max() - cols.min() + 1
    rx = max(foot_w * 0.55, body_w * 0.28, 3.0)
    ry = min(rx * 0.38, body_h * 0.2)
    cx = (cols.min() + cols.max()) / 2.0 - ax
    cy = (ys.max() + 1 - ay) - ry + 1.5
    return [_num(cx), _num(cy), _num(rx), _num(ry)]


def main():
    check = "--check" in sys.argv
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    stale = []
    for key, entry in manifest["entries"].items():
        if not key.startswith(PREFIXES):
            continue
        shadow = measure(entry)
        if shadow is None:
            continue
        if entry.get("shadow") != shadow:
            stale.append(key)
            entry["shadow"] = shadow
    if check:
        for key in stale:
            print("ombre à recalculer :", key)
        sys.exit(1 if stale else 0)
    MANIFEST.write_text(json.dumps(manifest, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
    print("ombres écrites : %d entrées modifiées" % len(stale))


if __name__ == "__main__":
    main()
