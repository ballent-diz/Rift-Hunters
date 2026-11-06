#!/usr/bin/env python3
"""Effets génériques des Corrompus (impact, disparition) aux couleurs de chaque famille, générés avec pixelfx.

pixelfx (https://github.com/patch-gg/pixelfx, licence MIT) n'est pas copié dans le dépôt : on le clone à part, puis
  python3 tools/art/build_pixelfx.py <chemin du dépôt pixelfx>
Pour chaque effet et chaque famille de tools/art/pixelfx/families.json, écrit assets/vfx/pixelfx/<effet>/<famille>.png
(feuille transparente) et .json (cadres, pivot, cadence ; format Aseprite de pixelfx). Puis réimporter le projet.
Nécessite Node 18 ou plus."""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "tools" / "art" / "pixelfx" / "families.json"
OUT = ROOT / "assets" / "vfx" / "pixelfx"


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    repo = Path(sys.argv[1]).resolve()
    if not (repo / "tools" / "render.mjs").exists():
        sys.exit(f"{repo} : dépôt pixelfx introuvable (tools/render.mjs)")
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    for effect, spec in config["effects"].items():
        name = spec["source"].split("/")[1]
        for family, palette in config["families"].items():
            opts = dict(spec.get("opts", {}), palette=palette)
            with tempfile.TemporaryDirectory() as tmp:
                subprocess.run(["node", "tools/render.mjs", spec["source"], "--sheet", "--no-actor", "--bg", "none",
                                "--opts", json.dumps(opts), "--out", tmp], cwd=repo, check=True,
                               stdout=subprocess.DEVNULL)
                folder = OUT / effect
                folder.mkdir(parents=True, exist_ok=True)
                for ext in ("png", "json"):
                    shutil.copy(Path(tmp) / spec["source"] / f"{name}.{ext}", folder / f"{family}.{ext}")
            print(f"{effect}/{family}")


if __name__ == "__main__":
    main()
