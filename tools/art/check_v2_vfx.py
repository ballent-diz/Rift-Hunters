#!/usr/bin/env python3
"""Contrôle des livraisons graphiques des combos, passifs et mutations de la v2 (docs/design/FICHES_VFX_GAMEPLAY_V2.md,
FICHES_VFX_MUTATIONS_V2.md).

Pour chaque effet : présence de la planche PNG et du JSON PixelFX, nombre d'images, fps, boucle, taille des images
cohérente avec la planche. Pour chaque illustration : PNG carré 1254 px et entrée du catalogue
`assets/ui/items/catalog.json`. Un fichier absent est « en attente » (le jeu joue le repli) ; un fichier présent
mais non conforme est une erreur (code de sortie 1).

    python3 tools/art/check_v2_vfx.py
"""
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VFX = ROOT / "assets/vfx/pixelfx"
ITEMS = ROOT / "assets/ui/items"
# id : (images, fps, boucle) selon les fiches.
EFFECTS = {
    "combo_prismatic_execution": (12, 20, False),
    "combo_prismatic_deluge": (12, 24, False),
    "combo_gravity_blade": (14, 24, False),
    "passive_dash_blade": (6, 24, False),
    "passive_void_wake": (8, 8, True),
    "passive_counter_cut": (10, 22, False),
    # Mutations des six sorts v2 (docs/design/FICHES_VFX_MUTATIONS_V2.md).
    "mutation_mark_execute": (12, 24, False),
    "mutation_mark_hunt": (8, 20, False),
    "mutation_rend_pierce": (6, 24, False),
    "mutation_step_trap": (12, 20, False),
    "mutation_stasis_shards": (8, 16, False),
    "mutation_rain_storm": (8, 10, True),
    "mutation_rain_focus": (8, 24, False),
    "mutation_veil_recoil": (8, 20, False),
}
ILLUSTRATIONS = ["passive_dash_blade", "passive_void_wake", "passive_counter_cut", "passive_anchor", "rule_extra_slot"]
ILLUSTRATION_SIZE = 1254


def png_info(path: Path) -> tuple[int, int, int]:
    """Largeur, hauteur et type de couleur (6 = RGBA) lus dans l'en-tête IHDR."""
    head = path.read_bytes()[:33]
    if head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        raise ValueError("pas un PNG")
    width, height, _depth, color = struct.unpack(">IIBB", head[16:26])
    return width, height, color


def check_effect(effect: str, spec: tuple[int, int, bool]) -> list[str]:
    png = VFX / effect / "violet.png"
    meta_path = VFX / effect / "violet.json"
    if not png.exists() and not meta_path.exists():
        return []
    if not png.exists() or not meta_path.exists():
        return ["fichier manquant : %s" % (png if not png.exists() else meta_path).relative_to(ROOT)]
    errors: list[str] = []
    width, height, color = png_info(png)
    if color != 6:
        errors.append("planche non RGBA")
    data = json.loads(meta_path.read_text(encoding="utf-8"))
    frames = data["frames"]
    frames = frames if isinstance(frames, list) else list(frames.values())
    meta = data["meta"]["pixelfx"]
    count, fps, loop = spec
    if len(frames) != count or int(meta.get("frames", len(frames))) != len(frames):
        errors.append("%d images (fiche : %d)" % (len(frames), count))
    if abs(float(meta["fps"]) - fps) > 0.01:
        errors.append("%s fps (fiche : %d)" % (meta["fps"], fps))
    if bool(meta.get("loop", False)) != loop:
        errors.append("boucle %s (fiche : %s)" % (meta.get("loop"), loop))
    sizes = {(f["frame"]["w"], f["frame"]["h"]) for f in frames}
    if len(sizes) != 1:
        errors.append("images de tailles différentes")
    for f in frames:
        r = f["frame"]
        if r["x"] + r["w"] > width or r["y"] + r["h"] > height:
            errors.append("image hors de la planche")
            break
    return errors


def check_illustration(card: str, catalog: dict) -> list[str]:
    png = ITEMS / "upgrades" / (card + ".png")
    entry = catalog.get("entries", {}).get("upgrade." + card)
    if not png.exists():
        return ["entrée du catalogue sans image"] if entry else []
    errors: list[str] = []
    width, height, _color = png_info(png)
    if (width, height) != (ILLUSTRATION_SIZE, ILLUSTRATION_SIZE):
        errors.append("%d × %d px (fiche : %d × %d)" % (width, height, ILLUSTRATION_SIZE, ILLUSTRATION_SIZE))
    expected = "res://assets/ui/items/upgrades/%s.png" % card
    if not entry or entry.get("image") != expected:
        errors.append("entrée « upgrade.%s » absente du catalogue" % card)
    return errors


def main() -> int:
    failed = False
    catalog = json.loads((ITEMS / "catalog.json").read_text(encoding="utf-8"))
    rows = [("effet", e, VFX / e / "violet.png", check_effect(e, s)) for e, s in EFFECTS.items()]
    rows += [("illustration", c, ITEMS / "upgrades" / (c + ".png"), check_illustration(c, catalog))
             for c in ILLUSTRATIONS]
    for kind, name, path, errors in rows:
        if errors:
            failed = True
            print("ERREUR     %-12s %-26s %s" % (kind, name, " ; ".join(errors)))
        elif path.exists():
            print("livré      %-12s %s" % (kind, name))
        else:
            print("en attente %-12s %-26s (repli conservé)" % (kind, name))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
