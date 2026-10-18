#!/usr/bin/env python3
"""Importe les illustrations C5-bis présentes et conserve leurs empreintes de source."""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROLES = ("might", "focus", "spell_base", "spell_alt", "signature")


def mipmaps(resource):
    target = ROOT / resource.removeprefix("res://")
    settings = Path(str(target) + ".import")
    if settings.exists():
        text = settings.read_text(encoding="utf-8")
        text = text.replace("mipmaps/generate=false", "mipmaps/generate=true")
    else:
        template = ROOT / "assets/ui/icons/skills/echo_ashblade_spell_alt.png.import"
        text = template.read_text(encoding="utf-8")
        old = "res://assets/ui/icons/skills/echo_ashblade_spell_alt.png"
        old_hash = hashlib.md5(old.encode()).hexdigest()
        new_hash = hashlib.md5(resource.encode()).hexdigest()
        text = text.replace("echo_ashblade_spell_alt.png-" + old_hash, target.name + "-" + new_hash)
        text = text.replace(old, resource)
        text = re.sub(r'^uid=".*"\n', "", text, flags=re.MULTILINE)
    settings.write_text(text, encoding="utf-8")


def main():
    specs = json.loads((ROOT / "assets/vfx/echoes/catalog.json").read_text(encoding="utf-8"))
    imported = []
    missing = []
    for spec in specs:
        for role in ROLES:
            identity = f"icon.echo.{spec['id']}_{role}"
            folder = ROOT / "assets/concepts/incoming" / identity
            source = folder / "source/icon.png"
            if not source.exists():
                missing.append(identity)
                continue
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            (folder / "source/SHA256.txt").write_text(f"{digest}  icon.png\n", encoding="utf-8")
            subprocess.run([sys.executable, str(ROOT / "tools/art/import_sheet.py"), str(folder / "job.json")], check=True)
            manifest = json.loads((ROOT / "assets/asset_manifest.json").read_text(encoding="utf-8"))
            entry = manifest["entries"][identity]
            mipmaps(entry["icon"])
            mipmaps(entry["sheet"])
            imported.append(identity)
    print(f"Icônes importées : {len(imported)} ; absentes : {len(missing)}.")
    if missing:
        print("En attente : " + ", ".join(missing))


if __name__ == "__main__":
    main()
