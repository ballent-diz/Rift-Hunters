#!/usr/bin/env python3
"""Effets des Corrompus aux couleurs de chaque famille, générés avec pixelfx : effets génériques (impact,
disparition, anneaux des boss) pour toutes les familles, et effets des compétences (assets/vfx/pixelfx/techniques.json)
pour les seules familles qui les utilisent. Une feuille déjà présente n'est pas refaite (--force pour tout refaire).

pixelfx (https://github.com/patch-gg/pixelfx, licence MIT) n'est pas copié dans le dépôt : on le clone à part, puis
  python3 tools/art/build_pixelfx.py <chemin du dépôt pixelfx>
Pour chaque effet et chaque famille de tools/art/pixelfx/families.json, écrit assets/vfx/pixelfx/<effet>/<famille>.png
(feuille transparente) et .json (cadres, pivot, cadence ; format Aseprite de pixelfx). Puis réimporter le projet.
Nécessite Node 18 ou plus."""
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "tools" / "art" / "pixelfx" / "families.json"
OUT = ROOT / "assets" / "vfx" / "pixelfx"
TECHNIQUES = OUT / "techniques.json"


def enemy_family(enemy_id):
    text = (ROOT / "data" / "enemies" / f"{enemy_id}.tres").read_text(encoding="utf-8")
    match = re.search(r'^family = &"(\w+)"', text, re.M)
    return match.group(1) if match else "violet"


def effects_of(entry):
    """Noms d'effets d'une entrée {moment: nom ou [noms]} (les clés time et param ne sont pas des effets)."""
    names = []
    for moment, value in entry.items():
        if moment in ("time", "param"):
            continue
        names.extend(value if isinstance(value, list) else [value])
    return names


def technique_jobs(catalog):
    """(effet, famille) à générer pour les compétences."""
    jobs = set()
    for enemy_id, techniques in catalog["enemies"].items():
        family = enemy_family(enemy_id)
        for entry in techniques.values():
            jobs.update((name, family) for name in effects_of(entry))
    boss_families = catalog["boss_families"]
    for boss_id, family in boss_families.items():
        for entry in list(catalog["boss_common"].values()) + list(catalog["bosses"].get(boss_id, {}).values()):
            jobs.update((name, family) for name in effects_of(entry))
    return sorted(job for job in jobs if job[0] in catalog["effects"])


def render(repo, effect, spec, family, palette):
    name = spec["source"].split("/")[1]
    opts = dict(spec.get("opts", {}), palette=palette)
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["node", "tools/render.mjs", spec["source"], "--sheet", "--no-actor", "--bg", "none",
                        "--opts", json.dumps(opts), "--out", tmp], cwd=repo, check=True, stdout=subprocess.DEVNULL)
        folder = OUT / effect
        folder.mkdir(parents=True, exist_ok=True)
        for ext in ("png", "json"):
            shutil.copy(Path(tmp) / spec["source"] / f"{name}.{ext}", folder / f"{family}.{ext}")
    print(f"{effect}/{family}")


def main() -> None:
    args = [arg for arg in sys.argv[1:] if not arg.startswith("--")]
    if len(args) != 1:
        sys.exit(__doc__)
    repo = Path(args[0]).resolve()
    if not (repo / "tools" / "render.mjs").exists():
        sys.exit(f"{repo} : dépôt pixelfx introuvable (tools/render.mjs)")
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    force = "--force" in sys.argv
    jobs = [(effect, spec, family) for effect, spec in config["effects"].items() for family in config["families"]]
    catalog = json.loads(TECHNIQUES.read_text(encoding="utf-8"))
    jobs += [(effect, catalog["effects"][effect], family) for effect, family in technique_jobs(catalog)]
    for effect, spec, family in jobs:
        if force or not (OUT / effect / f"{family}.png").exists():
            render(repo, effect, spec, family, config["families"][family])

if __name__ == "__main__":
    main()
