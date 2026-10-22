"""Ajoute les planches validées du Dévoreur au job d’import commun."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def package(scratch):
    folder = ROOT / "assets/concepts/incoming/boss.source_devourer"
    source = folder / "source"
    job_path = folder / "job.json"
    job = json.loads(job_path.read_text(encoding="utf-8"))
    job["animations"] = job["animations"][:3]
    job["aliases"] = {}
    job["isolate"] = True
    job["icon_size"] = 256
    job["preview_zoom"] = 1
    hashes = [hashlib.sha256((source / "sheet.png").read_bytes()).hexdigest() + "  sheet.png"]
    for label in "BCDE":
        metadata = json.loads((scratch / (label + ".json")).read_text(encoding="utf-8"))
        filename = "sheet_" + label.lower() + ".png"
        shutil.copyfile(scratch / filename, source / filename)
        shutil.copyfile(scratch / (label + ".json"), source / (label + ".json"))
        hashes.append(hashlib.sha256((source / filename).read_bytes()).hexdigest() + "  " + filename)
        image = Image.open(source / filename).convert("RGBA")
        for animation in metadata["animations"]:
            name, row = animation["name"], animation["row"]
            image.crop((0, round(row * image.height / 3), image.width,
                        round((row + 1) * image.height / 3))).save(folder / (name + ".png"))
            job["animations"].append({"name": name, "source": name + ".png",
                                      "sheet_source": "source/" + filename, "source_row": row,
                                      "frames": 6, "fps": 7 if "idle" in name else 9,
                                      "loop": "idle" in name, "layout": "grid", "grid": [6, 1]})
    (source / "SHA256.txt").write_text("\n".join(hashes) + "\n", encoding="utf-8")
    job_path.write_text(json.dumps(job, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("Dévoreur :", len(job["animations"]), "animations de six poses")


if __name__ == "__main__":
    package(Path(sys.argv[1]))
