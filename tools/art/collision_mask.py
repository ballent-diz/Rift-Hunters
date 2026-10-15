#!/usr/bin/env python3
"""Collisions détourées à la main : un masque noir et blanc devient la carte de distance du jeu (field.png).

Mode d'emploi complet : docs/maps/DE_L_IMAGE_AU_NIVEAU.md

  python3 tools/art/collision_mask.py export three_rifts   # prépare le dossier de travail (à faire une fois)
  python3 tools/art/collision_mask.py build three_rifts    # masque -> field.png + manifeste + aperçu

Dossier de travail : assets/concepts/incoming/map.<arène>/collision/
  reference.jpg : la carte complète, 1 pixel = 1 unité du monde (fond pour peindre, non versionné) ;
  collision.png : le masque, même taille. BLANC = praticable, NOIR = bloqué. C'est lui qui fait foi ;
  preview.jpg   : contrôle après « build » (rouge = bloqué, magenta = îlot praticable isolé).
Coordonnées : pixel (x, y) du masque = point (x - largeur/2, y - hauteur/2) du jeu, comme dans l'éditeur de niveau.
Nécessite numpy, Pillow et scipy.
"""
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "asset_manifest.json"
# Carte de distance : 2 unités du monde par pixel, 2 unités par niveau de gris (comme les Ruines des Cascades).
FIELD_UNIT = 2
FIELD_STEP = 2.0
Image.MAX_IMAGE_PIXELS = None


def arena_info(arena_id):
    """Taille du monde et entrée de décor d'après data/arenas/<id>.tres."""
    text = (ROOT / "data" / "arenas" / f"{arena_id}.tres").read_text(encoding="utf-8")
    size = re.search(r"^size = Vector2\(([\d.]+), ([\d.]+)\)", text, re.M)
    env = re.search(r'^environment_id = &"([^"]+)"', text, re.M)
    if not size or not env:
        sys.exit(f"{arena_id}.tres : taille ou environment_id introuvable")
    return (int(float(size.group(1))), int(float(size.group(2)))), env.group(1)


def res_path(path):
    return ROOT / path.removeprefix("res://")


def work_dir(arena_id):
    folder = ROOT / "assets" / "concepts" / "incoming" / f"map.{arena_id}" / "collision"
    folder.mkdir(parents=True, exist_ok=True)
    return folder


def full_map(entry, world):
    """Carte complète (tuiles côte à côte, comme ArenaGround) ramenée à 1 pixel par unité du monde."""
    paths = entry.get("map_tiles") or [entry["map"]]
    tiles = [Image.open(res_path(p)).convert("RGB") for p in paths]
    tile_w = world[0] // len(tiles)
    out = Image.new("RGB", world)
    for i, tile in enumerate(tiles):
        out.paste(tile.resize((tile_w, world[1]), Image.Resampling.LANCZOS), (i * tile_w, 0))
    return out


def export(arena_id):
    world, env_id = arena_info(arena_id)
    entry = json.loads(MANIFEST.read_text(encoding="utf-8"))["entries"][env_id]
    folder = work_dir(arena_id)
    full_map(entry, world).save(folder / "reference.jpg", quality=88)
    mask = folder / "collision.png"
    if mask.exists():
        print(f"{mask.relative_to(ROOT)} existe déjà : conservé")
    else:
        # Départ : les collisions actuelles du jeu (praticable = niveau >= 128).
        field = np.array(Image.open(res_path(entry["field"])).convert("L"))
        walk = Image.fromarray(((field >= 128) * 255).astype(np.uint8)).resize(world, Image.Resampling.NEAREST)
        walk.convert("1").save(mask, optimize=True)
        print(f"masque initial tiré des collisions actuelles : {mask.relative_to(ROOT)}")
    print(f"fond pour peindre : {(folder / 'reference.jpg').relative_to(ROOT)} ({world[0]} x {world[1]})")


def build(arena_id):
    world, env_id = arena_info(arena_id)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entry = manifest["entries"][env_id]
    folder = work_dir(arena_id)
    mask_img = Image.open(folder / "collision.png").convert("L")
    if mask_img.size != world:
        print(f"attention : masque {mask_img.size}, monde {world} ; le masque est étiré")
    field_size = (world[0] // FIELD_UNIT, world[1] // FIELD_UNIT)
    walk = np.array(mask_img.resize(field_size, Image.Resampling.BOX)) >= 128
    inside = ndimage.distance_transform_edt(walk) * FIELD_UNIT
    outside = ndimage.distance_transform_edt(~walk) * FIELD_UNIT
    signed = np.where(walk, inside, -outside)
    field = np.clip(np.round(signed / FIELD_STEP) + 128, 0, 255).astype(np.uint8)
    out = res_path(entry["field"])
    Image.fromarray(field, "L").save(out)
    entry["field_step"] = FIELD_STEP
    entry["generated_by"] = "tools/art/collision_mask.py"
    MANIFEST.write_text(json.dumps(manifest, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
    # Contrôle : îlots praticables détachés de la grande zone (un ennemi pourrait y apparaître et rester coincé).
    labels, count = ndimage.label(walk)
    sizes = ndimage.sum(np.ones_like(labels), labels, range(1, count + 1)) if count else np.array([])
    main = 1 + int(np.argmax(sizes)) if count else 0
    preview = Image.open(folder / "reference.jpg").convert("RGB") if (folder / "reference.jpg").exists() \
        else full_map(entry, world)
    preview = preview.resize(field_size, Image.Resampling.BOX)
    pixels = np.array(preview).astype(float)
    pixels[~walk] = pixels[~walk] * 0.5 + np.array([255, 0, 0]) * 0.5
    islands = walk & (labels != main)
    pixels[islands] = pixels[islands] * 0.3 + np.array([255, 0, 255]) * 0.7
    Image.fromarray(pixels.astype(np.uint8)).save(folder / "preview.jpg", quality=85)
    print(f"écrit : {out.relative_to(ROOT)} ({field_size[0]} x {field_size[1]}), praticable {walk.mean() * 100:.0f} %")
    for i, size in enumerate(sizes, start=1):
        if i != main and size * FIELD_UNIT ** 2 >= 400:
            ys, xs = np.nonzero(labels == i)
            center = (int(xs.mean() * FIELD_UNIT - world[0] / 2), int(ys.mean() * FIELD_UNIT - world[1] / 2))
            print(f"  îlot isolé de {int(size * FIELD_UNIT ** 2)} unités² autour de {center} (normal s'il est voulu)")
    print(f"contrôle : {(folder / 'preview.jpg').relative_to(ROOT)} ; puis touche L dans l'éditeur de niveau")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("export", "build"):
        sys.exit(__doc__)
    {"export": export, "build": build}[sys.argv[1]](sys.argv[2])
