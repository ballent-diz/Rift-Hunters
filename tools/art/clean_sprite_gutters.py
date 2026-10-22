"""Retire uniquement les fragments de cellules voisines coupés aux bords de la grille.

Les PNG sources restent intacts. Ne redessine, ne recolore et ne modifie aucune pose principale.
"""
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image
from scipy import ndimage


def clean(job_path):
    folder = Path(job_path).parent
    job = json.loads(Path(job_path).read_text(encoding="utf-8"))
    report = {}
    for animation in job["animations"]:
        path = folder / animation["source"]
        image = Image.open(path).convert("RGBA")
        pixels = np.array(image)
        width = image.width // 6
        removed = 0
        for column in range(6):
            frame = pixels[:, column * width:(column + 1) * width]
            labels, _ = ndimage.label(frame[:, :, 3] >= 128)
            sizes = np.bincount(labels.ravel())
            if len(sizes) <= 1:
                continue
            main = 1 + int(np.argmax(sizes[1:]))
            for identifier, region in enumerate(ndimage.find_objects(labels), 1):
                if region is None or identifier == main:
                    continue
                ys, xs = region
                edge = xs.start == 0 or ys.start == 0 or xs.stop == width or ys.stop == image.height
                if edge and sizes[identifier] < sizes[main] * 0.25:
                    frame[labels == identifier, 3] = 0
                    removed += int(sizes[identifier])
        Image.fromarray(pixels).save(path)
        report[animation["name"]] = {"removed_neighbor_pixels": removed}
    (folder / "source/gutter_cleanup.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(job["visual_id"], sum(item["removed_neighbor_pixels"] for item in report.values()), "pixels voisins retirés")


if __name__ == "__main__":
    for job in sys.argv[1:]:
        clean(job)
