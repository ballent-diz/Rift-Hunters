"""Découpe technique des planches pilotes, conserve les originaux et leur empreinte."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

from PIL import Image


def prepare(job_path, original):
    folder = Path(job_path).parent
    source = folder / "source" / "sheet.png"
    shutil.copyfile(original, source)
    image = Image.open(source).convert("RGBA")
    width, height = image.size
    assert image.getchannel("A").getextrema()[0] == 0, "Fond non transparent"
    report = {"source_size": list(image.size), "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
              "rows": {}, "grid": [6, 3]}
    for row, name in enumerate(("move", "attack", "death")):
        strip = image.crop((0, round(row * height / 3), width, round((row + 1) * height / 3)))
        strip.save(folder / (name + ".png"))
        bounds = []
        for column in range(6):
            frame = strip.crop((round(column * width / 6), 0, round((column + 1) * width / 6), strip.height))
            box = frame.getchannel("A").point(lambda value: 255 if value >= 128 else 0).getbbox()
            assert box, f"Frame vide : {name} {column}"
            bounds.append(list(box))
        report["rows"][name] = bounds
    (folder / "source" / "SHA256.txt").write_text(report["sha256"] + "  sheet.png\n", encoding="utf-8")
    (folder / "source" / "decoupage.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    prepare(sys.argv[1], sys.argv[2])
