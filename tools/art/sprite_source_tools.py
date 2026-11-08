"""Découpage et rangement des sources de sprites, sans redessiner les poses."""
import hashlib
import json
import numpy as np
from PIL import Image
from scipy import ndimage

def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")

def digest(path):
    content = path.read_bytes()
    if path.suffix in (".json", ".txt"):
        content = content.replace(b"\r\n", b"\n")
    return hashlib.sha256(content).hexdigest()

def split_source(path, rows):
    """Les composantes récupèrent aussi les pointes qui dépassent une limite de grille virtuelle."""
    source = Image.open(path).convert("RGBA")
    array = np.asarray(source).copy()
    opaque = array[:, :, 3] >= 128
    labels, _ = ndimage.label(opaque, np.ones((3, 3), bool))
    sizes = np.bincount(labels.ravel())
    boxes = ndimage.find_objects(labels)
    step_x, step_y = source.width / 6, source.height / rows
    groups = {}
    for label, box in enumerate(boxes, 1):
        if box is None or sizes[label] < 10:
            continue
        yy, xx = np.where(labels[box] == label)
        cx, cy = float(xx.mean()) + box[1].start, float(yy.mean()) + box[0].start
        col, row = min(5, int(cx / step_x)), min(rows - 1, int(cy / step_y))
        groups.setdefault((row, col), []).append((int(sizes[label]), label, box))
    poses, records = [], []
    for row in range(rows):
        for col in range(6):
            components = sorted(groups.get((row, col), []), reverse=True)
            assert components and components[0][0] >= 200, (path, row, col, components)
            main = components[0]
            # Les petits débris voulus sont conservés ; seuls les poussières et bouts de bord sont exclus.
            kept = [c for c in components if c[0] >= max(10, main[0] * .001)
                    and (c == main or (c[2][0].start > 0 and c[2][1].start > 0
                                      and c[2][0].stop < source.height and c[2][1].stop < source.width))]
            y0 = min(c[2][0].start for c in kept)
            y1 = max(c[2][0].stop for c in kept)
            x0 = min(c[2][1].start for c in kept)
            x1 = max(c[2][1].stop for c in kept)
            crop = array[y0:y1, x0:x1].copy()
            mask = np.isin(labels[y0:y1, x0:x1], [c[1] for c in kept])
            crop[:, :, 3] = np.where(mask, 255, 0)
            crop[~mask, :3] = 0
            poses.append(Image.fromarray(crop))
            records.append({"row": row, "column": col, "original_bounds": [x0, y0, x1, y1],
                            "components_kept": len(kept), "source_pixels": int(mask.sum())})
    return poses, {"source": path.name, "sha256": digest(path), "size": list(source.size),
                   "alpha_threshold": 128, "grid": [6, rows], "poses": records}

def pack(poses, rows, destination):
    side = max(max(p.width, p.height) for p in poses) + 32
    canvas = Image.new("RGBA", (side * 6, side * rows))
    for i, frame in enumerate(poses):
        canvas.paste(frame, ((i % 6) * side + (side - frame.width) // 2,
                            (i // 6 + 1) * side - 16 - frame.height))
    canvas.save(destination, lossless=True, exact=True, method=4)
