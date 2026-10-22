"""Planches et GIF de contrôle à partir des frames importées, sans retouche graphique."""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/previews/chapter2-monsters"
IDS = ["cinder_crawler", "ash_hound", "char_golem", "smoke_wisp", "pyre_brute", "ashen_widow", "cinder_knight"]


def run():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((ROOT / "assets/asset_manifest.json").read_text(encoding="utf-8"))["entries"]
    board = Image.new("RGB", (1400, 650), "#252b35")
    draw = ImageDraw.Draw(board)
    report = {}
    for index, identifier in enumerate(IDS):
        key = "enemy." + identifier
        entry = manifest[key]
        sheet = Image.open(ROOT / entry["sheet"].removeprefix("res://")).convert("RGBA")
        cw, ch = entry["cell"]
        anchor = entry["anchor"]
        first = sheet.crop((0, 0, cw, ch))
        box = first.getbbox()
        sprite = first.crop(box)
        sprite = sprite.resize((sprite.width * 2, sprite.height * 2), Image.Resampling.NEAREST)
        x = (index % 4) * 350 + 175
        y = (index // 4) * 310 + 270
        board.paste(sprite, (x - sprite.width // 2, y - sprite.height), sprite)
        draw.text((x - 110, y + 10), identifier, fill="white")
        report[key] = {"cell": entry["cell"], "scale": entry["scale"], "animations": {}, "status": "wip"}
        for name, animation in entry["animations"].items():
            if name == "idle":
                continue
            frames, boxes = [], []
            for column in range(animation["frames"]):
                row = animation["row"]
                frame = sheet.crop((column * cw, row * ch, (column + 1) * cw, (row + 1) * ch))
                boxes.append(frame.getbbox())
                canvas = Image.new("RGB", (600, 570), "#252b35")
                frame = frame.resize((cw * 2, ch * 2), Image.Resampling.NEAREST)
                canvas.paste(frame, (300 - anchor[0] * 2, 510 - anchor[1] * 2), frame)
                ImageDraw.Draw(canvas).text((25, 20), identifier + " / " + name, fill="white")
                frames.append(canvas)
            frames[0].save(OUT / (identifier + "_" + name + ".gif"), save_all=True,
                           append_images=frames[1:], duration=round(1000 / animation["fps"]), loop=0)
            report[key]["animations"][name] = {"frames": len(frames), "bounds": boxes,
                "touches_cell_edge": any(b and (b[0] == 0 or b[1] == 0 or b[2] == cw or b[3] == ch) for b in boxes)}
    board.save(OUT / "calcines_roster.png")
    boss = manifest.get("boss.source_devourer")
    if boss:
        sheet = Image.open(ROOT / boss["sheet"].removeprefix("res://")).convert("RGBA")
        cw, ch = boss["cell"]
        contact = Image.new("RGB", (1600, 1100), "#252b35")
        for index, (name, animation) in enumerate(boss["animations"].items()):
            frames = []
            for column in range(animation["frames"]):
                row = animation["row"]
                frame = sheet.crop((column * cw, row * ch, (column + 1) * cw, (row + 1) * ch))
                canvas = Image.new("RGB", (600, 570), "#252b35")
                canvas.paste(frame, (300 - boss["anchor"][0], 510 - boss["anchor"][1]), frame)
                ImageDraw.Draw(canvas).text((25, 20), "Devoreur / " + name, fill="white")
                frames.append(canvas)
                if column == 3:
                    frame = frame.crop(frame.getbbox())
                    frame.thumbnail((290, 175), Image.Resampling.NEAREST)
                    x, y = (index % 5) * 320, (index // 5) * 360
                    contact.paste(frame, (x + 10, y + 40), frame)
                    ImageDraw.Draw(contact).text((x + 12, y + 12), name, fill="white")
            frames[0].save(OUT / ("devourer_" + name + ".gif"), save_all=True,
                           append_images=frames[1:], duration=round(1000 / animation["fps"]), loop=0)
        contact.save(OUT / "devourer_animations.png")
    (OUT / "import_report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("Planches, GIF et rapport :", OUT)


if __name__ == "__main__":
    run()
