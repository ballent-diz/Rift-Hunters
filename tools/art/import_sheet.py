#!/usr/bin/env python3
"""Importe des images générées (IA ou dessin) et produit une feuille de sprites conforme au jeu.

Usage : python3 tools/art/import_sheet.py assets/concepts/incoming/<dossier>/job.json [--preview-only]

job.json :
{
  "visual_id": "monster.ashblade",          identifiant du manifeste
  "cell": [64, 64], "anchor": [32, 54],     cellule et point des pieds (voir docs/ART_BIBLE.md)
  "scale": 0.5,                             unités du monde par pixel d'art
  "target_height": 46,                      hauteur de la créature (pixels d'art) dans l'animation de référence
  "keep_size": false,                       true : garde la taille d'origine (images déjà en pixel art à la bonne échelle)
  "status": "final",                        "final" (protégé de la génération procédurale) ou "wip"
  "background": "auto",                     "auto" (couleur des bords), "#00ff00", ou "alpha" (déjà transparent)
  "tolerance": 60,                          tolérance du détourage (0-255)
  "holes": 0,                               > 0 : retire aussi le fond enfermé (ex. dans un arc de sabre), tolérance stricte
  "colors": 32,                             couleurs max de la palette commune (0 = pas de réduction)
  "outline": true,                          ajoute un contour sombre d'1 pixel
  "flip": false,                            true si les images regardent vers la gauche
  "hover": 0,                               créatures volantes : pixels entre le bas du corps et l'ancre (ombre au sol)
  "animations": [
    {"name": "idle", "source": "idle.png", "frames": 6, "fps": 8, "loop": true,
     "layout": "auto" | "row" | "grid", "grid": [6, 1]}
  ],
  "aliases": {"technique": "attack"}       animations manquantes réutilisant une autre ligne (optionnel)
}
"""
import json
import os
import sys
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from pixelforge.sheet import EntitySpec, make_icon, make_preview, _save  # noqa: E402
from pixelforge.palette import OUTLINE, hexrgb  # noqa: E402


def remove_background(img: Image.Image, mode: str, tolerance: int, holes: int = 0) -> Image.Image:
    rgba = img.convert("RGBA")
    arr = np.array(rgba)
    if mode == "alpha":
        arr[arr[:, :, 3] < 128, 3] = 0
        return Image.fromarray(arr, "RGBA")
    if mode == "auto":
        border = np.concatenate([arr[0, :, :3], arr[-1, :, :3], arr[:, 0, :3], arr[:, -1, :3]])
        colors, counts = np.unique(border.reshape(-1, 3) // 8, axis=0, return_counts=True)
        bg = colors[counts.argmax()] * 8 + 4
    else:
        bg = np.array(hexrgb(mode))
    dist = np.abs(arr[:, :, :3].astype(int) - bg.astype(int)).max(axis=2)
    candidate = (dist <= tolerance) | (arr[:, :, 3] < 128)
    # Seul le fond relié aux bords est retiré : les zones de même couleur à l'intérieur du sprite restent.
    # copy() : une image créée depuis numpy est en lecture seule et ignorerait le remplissage.
    mask = Image.fromarray((candidate * 255).astype(np.uint8), "L").copy()
    h, w = candidate.shape
    seeds = [(x, 0) for x in range(0, w, 4)] + [(x, h - 1) for x in range(0, w, 4)] + \
            [(0, y) for y in range(0, h, 4)] + [(w - 1, y) for y in range(0, h, 4)]
    for x, y in seeds:
        if mask.getpixel((x, y)) == 255:
            ImageDraw.floodfill(mask, (x, y), 128)
    background = np.array(mask) == 128
    arr[background, 3] = 0
    # Liseré : pixels presque fond collés au fond → transparents (évite le halo vert/magenta).
    near = (dist <= tolerance * 1.6) & ~background
    halo = near & _touches(background)
    arr[halo, 3] = 0
    if holes > 0:
        # Fond enfermé dans le dessin (non relié aux bords) : seulement les zones assez grandes et très proches
        # de la couleur du fond, pour ne pas trouer les parties sombres du personnage.
        strict = (dist <= holes) & ~background
        labels, count = _label(strict)
        for i in range(1, count + 1):
            zone = labels == i
            if zone.sum() >= 8:
                arr[zone, 3] = 0
    return Image.fromarray(arr, "RGBA")


def _label(mask):
    """Zones connexes (4 voisins) d'un masque booléen. Retourne (étiquettes, nombre)."""
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=int)
    count = 0
    for y, x in zip(*np.nonzero(mask)):
        if labels[y, x]:
            continue
        count += 1
        labels[y, x] = count
        stack = [(y, x)]
        while stack:
            cy, cx = stack.pop()
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = count
                    stack.append((ny, nx))
    return labels, count


def _touches(mask):
    out = np.zeros_like(mask)
    out[1:, :] |= mask[:-1, :]
    out[:-1, :] |= mask[1:, :]
    out[:, 1:] |= mask[:, :-1]
    out[:, :-1] |= mask[:, 1:]
    return out


def split_frames(img: Image.Image, count: int, layout: str, grid=None) -> list:
    arr = np.array(img)
    alpha = arr[:, :, 3] > 0
    if layout == "grid" or (layout == "auto" and grid):
        cols, rows = grid or (count, 1)
        cw, ch = img.width / cols, img.height / rows
        frames = []
        for r in range(rows):
            for c in range(cols):
                if len(frames) < count:
                    frames.append(img.crop((int(c * cw), int(r * ch), int((c + 1) * cw), int((r + 1) * ch))))
        return frames
    # Découpage par colonnes vides (images posées côte à côte).
    cols_used = alpha.any(axis=0)
    segments, start = [], None
    for x, used in enumerate(list(cols_used) + [False]):
        if used and start is None:
            start = x
        elif not used and start is not None:
            if x - start > 2:
                segments.append((start, x))
            start = None
    # Petits morceaux détachés (étincelles, traînée de sabre) : rattachés au voisin le plus proche.
    while len(segments) > count:
        k = min(range(len(segments)), key=lambda i: segments[i][1] - segments[i][0])
        gap_left = segments[k][0] - segments[k - 1][1] if k > 0 else 10 ** 9
        gap_right = segments[k + 1][0] - segments[k][1] if k + 1 < len(segments) else 10 ** 9
        j = k - 1 if gap_left <= gap_right else k + 1
        a, b = sorted((k, j))
        segments[a:b + 1] = [(segments[a][0], segments[b][1])]
    if len(segments) != count:
        # Repli : grille régulière d'une ligne.
        return split_frames(img, count, "grid", (count, 1))
    return [img.crop((a, 0, b, img.height)) for a, b in segments]


def crop_alpha(frame: Image.Image) -> Image.Image:
    bbox = frame.getbbox()
    return frame.crop(bbox) if bbox else frame


def feet_point(arr: np.ndarray) -> tuple:
    """Point d'appui : centre des pixels opaques des 3 rangées les plus basses."""
    alpha = arr[:, :, 3] > 0
    rows = np.nonzero(alpha.any(axis=1))[0]
    bottom = rows.max()
    xs = np.nonzero(alpha[max(bottom - 2, 0):bottom + 1].any(axis=0))[0]
    return float(xs.mean()), float(bottom)


def place_in_cell(arr: np.ndarray, cell_size: tuple, anchor: tuple, hover: int = 0) -> np.ndarray:
    """Pose la frame dans la cellule : le point d'appui sur l'ancre (relevé de `hover` pixels pour les volants)."""
    cw, ch = cell_size
    ax, ay = anchor
    fx, fy = feet_point(arr)
    cell = np.zeros((ch, cw, 4), dtype=np.uint8)
    ox, oy = int(round(ax - fx)), int(round(ay - hover - fy))
    # Garde la créature entière dans la cellule quand elle y tient (ancrage décalé si nécessaire).
    if arr.shape[1] <= cw:
        ox = min(max(ox, 0), cw - arr.shape[1])
    if arr.shape[0] <= ch:
        oy = min(max(oy, 0), ch - arr.shape[0])
    ys = slice(max(oy, 0), min(oy + arr.shape[0], ch))
    xs = slice(max(ox, 0), min(ox + arr.shape[1], cw))
    src = arr[ys.start - oy:ys.stop - oy, xs.start - ox:xs.stop - ox]
    cell[ys, xs] = np.where(src[:, :, 3:4] > 0, src, cell[ys, xs])
    return cell


def add_outline(arr: np.ndarray) -> np.ndarray:
    alpha = arr[:, :, 3] > 0
    ring = _touches(alpha) & ~alpha
    arr[ring, :3] = hexrgb(OUTLINE)
    arr[ring, 3] = 255
    return arr


def run(job_path: str, preview_only: bool = False, preview_dir: str = "") -> dict:
    job_dir = os.path.dirname(os.path.abspath(job_path))
    with open(job_path, encoding="utf-8") as f:
        job = json.load(f)
    cw, ch = job["cell"]
    ax, ay = job["anchor"]
    animations = job["animations"]
    sources = []
    for anim in animations:
        img = Image.open(os.path.join(job_dir, anim["source"]))
        img = remove_background(img, job.get("background", "auto"), int(job.get("tolerance", 60)), int(job.get("holes", 0)))
        if job.get("flip"):
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        frames = [crop_alpha(fr) for fr in split_frames(img, int(anim["frames"]), anim.get("layout", "auto"), anim.get("grid"))]
        sources.append((anim, frames))
    # Échelle commune : la hauteur médiane de l'animation de référence devient target_height.
    reference = sources[0][1]
    heights = sorted(fr.height for fr in reference)
    factor = 1.0 if job.get("keep_size") else float(job.get("target_height", ch * 0.75)) / heights[len(heights) // 2]
    scaled = []
    for anim, frames in sources:
        out = []
        for fr in frames:
            if factor == 1.0:
                out.append(fr)
                continue
            size = (max(1, round(fr.width * factor)), max(1, round(fr.height * factor)))
            out.append(fr.resize(size, Image.BOX))
        scaled.append((anim, out))
    # Palette commune à toutes les images (cohérence entre frames).
    colors = int(job.get("colors", 32))
    all_frames = [fr for _, frs in scaled for fr in frs]
    palette_img = None
    if colors > 0:
        strip_w = sum(fr.width for fr in all_frames)
        strip = Image.new("RGB", (strip_w, max(fr.height for fr in all_frames)), (0, 0, 0))
        x = 0
        for fr in all_frames:
            strip.paste(fr.convert("RGB"), (x, 0), fr)
            x += fr.width
        # FASTOCTREE conserve les petits accents saturés (braises, yeux) que la coupe médiane efface.
        palette_img = strip.quantize(colors=colors + 1, method=Image.Quantize.FASTOCTREE)
    rows_out = []
    sheet_cols = max(len(frs) for _, frs in scaled)
    sheet = np.zeros((ch * len(scaled), cw * sheet_cols, 4), dtype=np.uint8)
    entry_anims = {}
    for row, (anim, frames) in enumerate(scaled):
        rendered = []
        for i, fr in enumerate(frames):
            arr = np.array(fr)
            alpha = arr[:, :, 3] >= 128
            if palette_img is not None:
                rgb = fr.convert("RGB").quantize(palette=palette_img, dither=Image.Dither.NONE).convert("RGB")
                arr[:, :, :3] = np.array(rgb)
            arr[:, :, 3] = np.where(alpha, 255, 0)
            cell = place_in_cell(arr, (cw, ch), (ax, ay), int(job.get("hover", 0)))
            if job.get("outline", True):
                cell = add_outline(cell)
            sheet[row * ch:(row + 1) * ch, i * cw:(i + 1) * cw] = cell
            rendered.append(cell)
        entry_anims[anim["name"]] = {"row": row, "frames": len(frames), "fps": anim.get("fps", 10), "loop": anim.get("loop", True)}
        rows_out.append((anim["name"], rendered))
    for missing, existing in job.get("aliases", {}).items():
        if existing in entry_anims and missing not in entry_anims:
            entry_anims[missing] = dict(entry_anims[existing])
    spec = EntitySpec(job["visual_id"], None, (cw, ch), (ax, ay), scale=job.get("scale", 1.0))
    sheet_rel, icon_rel = spec.paths()
    preview_dir = preview_dir or os.path.join(REPO, "assets", "concepts", "previews")
    _save(make_preview(job["visual_id"] + " (import)", rows_out, (cw, ch)),
          os.path.join(preview_dir, job["visual_id"].replace(".", "_") + "_import.png"))
    entry = {
        "status": job.get("status", "final"),
        "imported_from": os.path.relpath(job_path, REPO),
        "sheet": "res://" + sheet_rel,
        "cell": [cw, ch],
        "anchor": [ax, ay],
        "scale": job.get("scale", 1.0),
        "animations": entry_anims,
        "icon": "res://" + icon_rel,
    }
    if preview_only:
        return entry
    _save(Image.fromarray(sheet, "RGBA"), os.path.join(REPO, sheet_rel))
    _save(make_icon(rows_out[0][1][0]), os.path.join(REPO, icon_rel))
    manifest_path = os.path.join(REPO, "assets", "asset_manifest.json")
    with open(manifest_path, encoding="utf-8") as f:
        manifest = json.load(f)
    manifest["entries"][job["visual_id"]] = entry
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent="\t", ensure_ascii=False)
        f.write("\n")
    return entry


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    result = run(sys.argv[1], "--preview-only" in sys.argv)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    print("Ensuite : godot --headless --import --path .  puis  tools/run_tests.sh assets")
