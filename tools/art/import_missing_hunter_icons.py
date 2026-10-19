#!/usr/bin/env python3
"""Import commun, contrôle alpha et planche 112/48 des trente illustrations du Chasseur."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import import_sheet

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / 'assets/concepts/incoming/ui.hunter_passive_icons'
OUT = ROOT / 'docs/previews/c5-icones-chasseur'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--final', action='store_true', help='Après validation visuelle des trente images.')
    parser.add_argument('--mipmaps-only', action='store_true', help='Activer les mipmaps après le premier import Godot.')
    args = parser.parse_args()
    entries = json.loads((CATALOG / 'prompts.json').read_text(encoding='utf-8'))
    if args.mipmaps_only:
        for spec in entries:
            for path in [ROOT / f'assets/ui/icons/skills/hunter_{spec["id"]}.png.import',
                         ROOT / f'assets/sprites/skills/hunter/hunter_{spec["id"]}_sheet.png.import']:
                assert path.exists(), f'Importer dans Godot avant cette étape : {path}'
                path.write_text(path.read_text().replace('mipmaps/generate=false', 'mipmaps/generate=true'))
        print('Mipmaps activées pour les 30 icônes et leurs feuilles.')
        return
    audit = []
    OUT.mkdir(parents=True, exist_ok=True)
    for spec in entries:
        source = ROOT / spec['source']
        image = Image.open(source).convert('RGBA')
        alpha = np.asarray(image)[:, :, 3]
        assert alpha.max() > 128 and alpha.min() == 0, f'Alpha absent : {source}'
        assert max(alpha[0, 0], alpha[0, -1], alpha[-1, 0], alpha[-1, -1]) < 8, f'Coins opaques : {source}'
        folder = source.parent.parent
        job = json.loads((folder / 'job.json').read_text())
        job['status'] = 'final' if args.final else 'wip'
        (folder / 'job.json').write_text(json.dumps(job, indent=2) + '\n')
        imported = import_sheet.run(str(folder / 'job.json'), preview_dir=str(OUT / 'imports'))
        for field in ['icon', 'sheet']:
            path = ROOT / imported[field].removeprefix('res://')
            assert Image.open(path).size == (512, 512), f'Définition : {path}'
            options = Path(str(path) + '.import')
            if options.exists():
                options.write_text(options.read_text().replace('mipmaps/generate=false', 'mipmaps/generate=true'))
        audit.append(dict(id=spec['id'], source=spec['source'], prompt=spec['prompt'],
                          sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                          original_size=list(image.size), alpha=True, status=job['status']))
    (CATALOG / 'generation.json').write_text(json.dumps(dict(tool='imagegen intégré', date='2026-10-18',
                                           images=audit), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    font = ImageFont.truetype(str(ROOT / 'assets/fonts/inter/Inter-Variable.ttf'), 13)
    contact = Image.new('RGB', (6 * 224, 5 * 212), '#101326')
    draw = ImageDraw.Draw(contact)
    for index, spec in enumerate(entries):
        image = Image.open(ROOT / f'assets/ui/icons/skills/hunter_{spec["id"]}.png').convert('RGBA')
        x, y = (index % 6) * 224, (index // 6) * 212
        for size, left, top in [(112, x + 10, y + 10), (48, x + 150, y + 45)]:
            scaled = image.resize((size, size), Image.Resampling.LANCZOS)
            contact.paste(scaled, (left, top), scaled)
        draw.text((x + 22, y + 128), '112 px', font=font, fill='#a69ba9')
        draw.text((x + 152, y + 105), '48 px', font=font, fill='#a69ba9')
        draw.text((x + 10, y + 153), spec['name_fr'], font=font, fill='#f5dfc6')
        identity = spec['id'].replace('_', ' ')
        if len(identity) > 28:
            split = identity.rfind(' ', 0, 28)
            identity = identity[:split] + '\n' + identity[split + 1:]
        draw.text((x + 10, y + 173), identity, font=font, fill='#a69ba9')
    contact.save(OUT / 'planche-112-48.png')
    print('30 icônes 512 px importées ; planche 112/48 et empreintes sources enregistrées.')


if __name__ == '__main__':
    main()
