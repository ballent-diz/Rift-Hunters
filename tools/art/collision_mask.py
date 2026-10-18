#!/usr/bin/env python3
"""Collisions détourées à la main : un masque noir et blanc devient la carte de distance du jeu (field.png).

Mode d'emploi complet : docs/maps/DE_L_IMAGE_AU_NIVEAU.md

  python3 tools/art/collision_mask.py export three_rifts   # prépare le dossier de travail (à faire une fois)
  python3 tools/art/collision_mask.py build three_rifts    # masque -> field.png + manifeste + aperçu
  python3 tools/art/collision_mask.py overlay three_rifts carte_peinte.png   # carte peinte en rouge -> masque

Dossier de travail : assets/concepts/incoming/map.<arène>/collision/
  reference.jpg : la carte complète, 1 pixel = 1 unité du monde (fond pour peindre, non versionné) ;
  collision.png : le masque, même taille. BLANC = praticable, NOIR = bloqué. C'est lui qui fait foi ;
  preview.jpg   : contrôle après « build » (rouge = bloqué, magenta = îlot praticable isolé).
« overlay » : la carte (à n'importe quelle échelle, même cadrage) avec le bloqué peint en ROUGE translucide par-dessus.
Les traits d'annotation (noir, bleu, rouge foncé : barrières, numéros de zone) sont ignorés : ils prennent la valeur
de leur voisinage. L'eau de la carte est toujours bloquée. Seule la plus grande région praticable est gardée (pas
d'îlot où un ennemi resterait coincé).
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


# Écart de couleur minimal avec la carte d'origine pour qu'un pixel compte comme peint (bruit de compression).
OVERLAY_NOISE = 14.0


def painted_mask(pixels, original):
    """Pixels recouverts de peinture rouge translucide. On estime l'opacité de la peinture sur les pixels sans
    ambiguïté, puis chaque pixel est rangé du côté de l'hypothèse la plus proche : décor seul, ou décor + peinture
    (fiable aussi sur les décors déjà rouges : lave, feuillage d'automne)."""
    delta = pixels - original
    obvious = (delta[..., 0] - (delta[..., 1] + delta[..., 2]) / 2 > 100) & (original[..., 1] > 60)
    alpha = float(np.median(1 - pixels[..., 1][obvious] / original[..., 1][obvious])) if obvious.sum() > 500 else 0.5
    alpha = min(max(alpha, 0.2), 0.9)
    expected = (1 - alpha) * original + alpha * np.array([255.0, 0.0, 0.0])
    to_paint = np.linalg.norm(pixels - expected, axis=-1)
    to_original = np.linalg.norm(delta, axis=-1)
    return (to_paint < to_original) & (to_original > OVERLAY_NOISE)


def annotation_mask(pixels):
    """Traits d'annotation : quasi noir, bleu franc ou rouge foncé (plus sombre que la peinture rouge)."""
    r, g, b = pixels[..., 0], pixels[..., 1], pixels[..., 2]
    black = (r < 45) & (g < 45) & (b < 45)
    blue = (b > r + 60) & (b > g + 30) & (b > 120)
    dark_red = (r > 90) & (r < 175) & (g < 30) & (b < 40)
    return black | blue | dark_red


def water_mask(pixels, min_size=150):
    """Grandes étendues bleues de la carte d'origine (lacs, rivières, cascades)."""
    r, g, b = pixels[..., 0], pixels[..., 1], pixels[..., 2]
    water = (b > r + 25) & (b > g - 5) & (b > 110)
    labels, count = ndimage.label(ndimage.binary_closing(water, iterations=2))
    if not count:
        return water
    sizes = ndimage.sum(np.ones_like(labels), labels, range(1, count + 1))
    return np.isin(labels, 1 + np.nonzero(sizes >= min_size)[0])


def overlay(arena_id, image_path):
    world, env_id = arena_info(arena_id)
    entry = json.loads(MANIFEST.read_text(encoding="utf-8"))["entries"][env_id]
    folder = work_dir(arena_id)
    painted = Image.open(image_path).convert("RGB")
    reference = Image.open(folder / "reference.jpg").convert("RGB") if (folder / "reference.jpg").exists() \
        else full_map(entry, world)
    reference = reference.resize(painted.size, Image.Resampling.LANCZOS)
    pixels = np.asarray(painted).astype(float)
    original = np.asarray(reference).astype(float)
    blocked = painted_mask(pixels, original)
    # Rouge franc : la teinte de la peinture elle-même (le décor non peint n'en contient presque pas).
    blocked |= (pixels[..., 0] > 185) & (pixels[..., 1] < 80) & (pixels[..., 2] < 80)
    # Les bords adoucis des traits (anticrénelage) font aussi partie de l'annotation. Un trait barre un passage ou
    # numérote une zone : il est praticable, sauf là où il déborde dans une zone surtout bloquée (falaise).
    notes = ndimage.binary_dilation(annotation_mask(pixels), iterations=2)
    known = (~notes).astype(float)
    window = 15
    share = ndimage.uniform_filter((blocked & ~notes).astype(float), window) / \
        np.maximum(ndimage.uniform_filter(known, window), 1e-6)
    blocked = np.where(notes, share >= 0.8, blocked)
    # L'eau n'est jamais praticable, même là où la peinture s'arrête (bord de carte, cascades).
    blocked |= water_mask(np.asarray(reference).astype(float))
    blocked = ndimage.binary_closing(ndimage.binary_opening(blocked), iterations=2)
    # Le bord de la carte n'est jamais praticable (la peinture s'arrête souvent un pixel avant).
    blocked[:3, :] = blocked[-3:, :] = True
    blocked[:, :3] = blocked[:, -3:] = True
    labels, count = ndimage.label(~blocked)
    if count:
        sizes = ndimage.sum(np.ones_like(labels), labels, range(1, count + 1))
        blocked = labels != 1 + int(np.argmax(sizes))
    soft = ndimage.gaussian_filter((~blocked).astype(float), 0.8)
    big = Image.fromarray((soft * 255).astype(np.uint8)).resize(world, Image.Resampling.BILINEAR)
    walk = np.asarray(big) >= 128
    labels, count = ndimage.label(walk)
    if count > 1:
        walk = labels == 1 + int(np.argmax(ndimage.sum(np.ones_like(labels), labels, range(1, count + 1))))
    Image.fromarray((walk * 255).astype(np.uint8)).convert("1").save(folder / "collision.png", optimize=True)
    print(f"masque écrit : {(folder / 'collision.png').relative_to(ROOT)} ({world[0]} x {world[1]}), "
          f"praticable {walk.mean() * 100:.0f} % ; lancer ensuite « build {arena_id} »")


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
    if len(sys.argv) == 4 and sys.argv[1] == "overlay":
        overlay(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 3 and sys.argv[1] in ("export", "build"):
        {"export": export, "build": build}[sys.argv[1]](sys.argv[2])
    else:
        sys.exit(__doc__)
