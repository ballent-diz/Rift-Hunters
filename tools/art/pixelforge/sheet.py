"""Assemblage des feuilles de sprites, icônes, aperçus et entrées du manifeste d'assets."""
import os
import numpy as np
from PIL import Image, ImageDraw
from .render import render_frame

CATEGORY_FOLDERS = {"player": "players", "monster": "monsters", "enemy": "enemies", "boss": "bosses"}


class EntitySpec:
    """Ce qu'il faut produire pour un identifiant visuel du manifeste (ex. « monster.ashblade »)."""

    def __init__(self, visual_id, build, cell, anchor, remap=None, scale=1.0):
        self.visual_id = visual_id
        self.build = build
        self.cell = cell
        self.anchor = anchor
        self.remap = remap or {}
        self.scale = scale

    @property
    def category(self):
        return self.visual_id.split(".")[0]

    def paths(self):
        parts = self.visual_id.split(".")
        folder = CATEGORY_FOLDERS[parts[0]]
        base = parts[1]
        stem = "_".join(parts[1:])
        sheet = f"assets/sprites/{folder}/{base}/{stem}_sheet.png"
        icon = f"assets/ui/icons/{folder}/{stem}.png"
        return sheet, icon


def build_entity(spec, repo_root, preview_dir=None):
    creature = spec.build()
    cw, ch = spec.cell
    cols = max(a.frames for a in creature.anims)
    sheet = np.zeros((ch * len(creature.anims), cw * cols, 4), dtype=np.uint8)
    animations = {}
    rows = []
    for row, anim in enumerate(creature.anims):
        frames = [render_frame(creature, anim, i, spec.cell, spec.anchor, spec.remap) for i in range(anim.frames)]
        for i, frame in enumerate(frames):
            sheet[row * ch:(row + 1) * ch, i * cw:(i + 1) * cw] = frame
        animations[anim.name] = {"row": row, "frames": anim.frames, "fps": anim.fps, "loop": anim.loop}
        rows.append((anim.name, frames))
    sheet_rel, icon_rel = spec.paths()
    _save(Image.fromarray(sheet, "RGBA"), os.path.join(repo_root, sheet_rel))
    _save(make_icon(rows[0][1][0]), os.path.join(repo_root, icon_rel))
    if preview_dir:
        _save(make_preview(spec.visual_id, rows, spec.cell), os.path.join(preview_dir, spec.visual_id.replace(".", "_") + ".png"))
    return {
        "status": "wip",
        "generated_by": "tools/art/build.py",
        "sheet": "res://" + sheet_rel,
        "cell": [cw, ch],
        "anchor": [int(spec.anchor[0]), int(spec.anchor[1])],
        "scale": spec.scale,
        "animations": animations,
        "icon": "res://" + icon_rel,
    }


def make_icon(frame, size=64):
    alpha = frame[:, :, 3] > 0
    ys, xs = np.nonzero(alpha)
    crop = frame[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    factor = max(1, min((size - 4) // crop.shape[1], (size - 4) // crop.shape[0]))
    img = Image.fromarray(crop, "RGBA").resize((crop.shape[1] * factor, crop.shape[0] * factor), Image.NEAREST)
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.paste(img, ((size - img.width) // 2, (size - img.height) // 2), img)
    return icon


def make_preview(title, rows, cell, zoom=4):
    cw, ch = cell
    cols = max(len(f) for _, f in rows)
    label_w = 110
    img = Image.new("RGBA", (label_w + cols * cw * zoom + 8, len(rows) * (ch * zoom + 6) + 30), (26, 29, 46, 255))
    draw = ImageDraw.Draw(img)
    draw.text((6, 6), title, fill=(160, 230, 255, 255))
    for r, (name, frames) in enumerate(rows):
        y = 26 + r * (ch * zoom + 6)
        draw.text((6, y + ch * zoom // 2 - 6), name, fill=(220, 225, 240, 255))
        for i, frame in enumerate(frames):
            tile = Image.fromarray(frame, "RGBA").resize((cw * zoom, ch * zoom), Image.NEAREST)
            x = label_w + i * cw * zoom
            draw.rectangle((x, y, x + cw * zoom - 1, y + ch * zoom - 1), fill=(34, 38, 58, 255))
            img.paste(tile, (x, y), tile)
    return img


def _save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
