#!/usr/bin/env python3
"""Install the Sifflants art archive without overwriting existing game assets.

Usage: python3 tools/art/install_sifflants.py <archive.zip> [--repo .] [--dry-run]
Requires only the Python standard library. Run Godot import afterward.
"""
import argparse
import json
import sys
from pathlib import Path
from zipfile import ZipFile

FRAGMENT = "assets/manifest_sifflants_fragment.json"
ROOTS = (
    "assets/sprites/enemies/", "assets/sprites/bosses/",
    "assets/ui/icons/", "assets/vfx/pixelfx/",
    "docs/previews/sifflants/",
    "docs/art/SIFFLANTS_CHAPITRE7.md",
    "docs/design/SIFFLANTS_COMPETENCES.md",
    "data/sifflants_skills.json",
)

def install(archive: Path, repo: Path, dry_run: bool = False) -> None:
    manifest = repo / "assets/asset_manifest.json"
    if not manifest.is_file():
        raise RuntimeError("Pass a Rift Hunters project root with --repo")
    current = json.loads(manifest.read_text(encoding="utf-8"))
    entries = current.setdefault("entries", {})
    with ZipFile(archive) as z:
        fragment = json.loads(z.read(FRAGMENT).decode("utf-8"))["entries"]
        conflicts = [k for k in fragment if k in entries and entries[k] != fragment[k]]
        if conflicts:
            raise RuntimeError("Existing manifest IDs differ: " + ", ".join(conflicts))
        to_copy = []
        for info in z.infolist():
            name = info.filename
            if info.is_dir() or name == FRAGMENT:
                continue
            if not any(name.startswith(prefix) for prefix in ROOTS):
                continue
            target = (repo / name).resolve()
            if not target.is_relative_to(repo.resolve()):
                raise RuntimeError("Unsafe ZIP path: " + name)
            if target.exists():
                if target.read_bytes() != z.read(info):
                    if name.startswith(("docs/art/", "docs/design/", "data/")):
                        continue  # retain already-committed documentation
                    raise RuntimeError("Refusing to overwrite: " + name)
                continue
            to_copy.append((name, target))
        print(f"Validated {len(fragment)} entities and {len(to_copy)} new files")
        if dry_run:
            return
        for name, target in to_copy:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(z.read(name))
        entries.update(fragment)
        manifest.write_text(json.dumps(current, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("Installed. Run Godot import and tests, then open a separate art PR.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--repo", type=Path, default=Path("."))
    parser.add_argument("--dry-run", action="store_true")
    a = parser.parse_args()
    try:
        install(a.archive, a.repo, a.dry_run)
    except (RuntimeError, OSError, KeyError, ValueError) as e:
        print("INSTALL FAILED:", e, file=sys.stderr)
        sys.exit(1)
