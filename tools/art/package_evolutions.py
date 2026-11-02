#!/usr/bin/env python3
"""Import des formes évoluées avec les animations et l'échelle de leur forme de base."""
import hashlib
import json
from pathlib import Path
import shutil
import sys
from statistics import median

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/art'))
import import_sheet  # noqa: E402


def body_height(image, column, row, columns, rows):
    frame = image.crop((round(column*image.width/columns), round(row*image.height/rows),
                        round((column+1)*image.width/columns), round((row+1)*image.height/rows)))
    labels, count = ndimage.label(np.asarray(frame.convert('RGBA'))[:, :, 3] >= 128)
    if count == 0:
        raise ValueError('Pose de référence vide')
    sizes = np.bincount(labels.ravel())
    y = np.nonzero(labels == 1 + np.argmax(sizes[1:]))[0]
    return int(y.max() - y.min() + 1)


def main(scratch):
    plans = json.loads((scratch / 'evolution-plans.json').read_text())
    catalog = []
    for identifier in dict.fromkeys(p['id'] for p in plans):
        group = [p for p in plans if p['id'] == identifier]
        meta = group[0]
        incoming = ROOT / 'assets/concepts/incoming' / ('monster.' + identifier)
        source = incoming / 'source'
        source.mkdir(parents=True, exist_ok=True)
        first = Image.open(scratch / 'generated-evolutions' / identifier / 'sheet_a.png').convert('RGBA')
        reference = median(body_height(first, col, 0, meta['columns'], meta['rows'])
                           for col in range(meta['columns']))
        animations, normalization, hashes = [], {}, {}
        for p in group:
            filename = 'sheet_' + p['sheet'] + '.png'
            path = scratch / 'generated-evolutions' / identifier / filename
            image = Image.open(path).convert('RGBA')
            assert image.getchannel('A').getextrema()[0] == 0, identifier + ': alpha absent'
            # La récupération de l'attaque/technique correspond au repos de A.
            # La mort ne sert jamais de référence : une pose affaissée doit rester basse.
            living_row = next(i for i, a in enumerate(p['sheet_animations']) if a['name'] != 'death')
            living_count = p['sheet_animations'][living_row]['data']['frames']
            factor = 1.0 if p['sheet'] == 'a' else reference / body_height(
                image, living_count - 1, living_row, p['columns'], p['rows'])
            normalization[filename] = round(factor, 6)
            shutil.copyfile(path, source / filename)
            (source / ('prompt_' + p['sheet'] + '.txt')).write_text(p['prompt'].rstrip() + '\n', encoding='utf-8')
            hashes[filename] = hashlib.sha256(path.read_bytes()).hexdigest()
            for row, anim in enumerate(p['sheet_animations']):
                data = anim['data']
                animations.append({'name': anim['name'], 'source': 'source/' + filename,
                                   'grid': [p['columns'], p['rows']], 'row': row,
                                   'frames': data['frames'], 'fps': data['fps'], 'loop': data['loop'],
                                   'source_scale': round(factor, 6)})
        job = {'visual_id': 'monster.' + identifier, 'cell': [256, 256], 'anchor': [128, 238],
               'scale': meta['scale'], 'target_height': meta['target_height'], 'hover': meta['hover'],
               'status': 'final', 'background': 'alpha', 'tolerance': 0, 'colors': 32,
               'outline': True, 'anchor_mode': 'mass', 'resample': 'lanczos', 'isolate': True,
               'preview_zoom': 1, 'icon_size': 128, 'animations': animations, 'aliases': meta['aliases']}
        (incoming / 'job.json').write_text(json.dumps(job, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        (source / 'SHA256.json').write_text(json.dumps(hashes, indent=2)+'\n')
        (source / 'normalization.json').write_text(json.dumps(normalization, indent=2)+'\n')
        entry = import_sheet.run(str(incoming / 'job.json'), preview_dir=str(scratch / 'evolution-import-previews'))
        assert set(entry['animations']) == set(meta['animations']), identifier + ': animations différentes'
        for name, data in meta['animations'].items():
            for key in ('frames', 'fps', 'loop'):
                assert entry['animations'][name][key] == data[key], (identifier, name, key)
        catalog.append({'visual_id': job['visual_id'], 'base': 'monster.' + meta['base'],
                        'name': meta['name'], 'target_height': meta['target_height'], 'scale': meta['scale'],
                        'animations': [{'name': a['name']} for a in meta['unique']]})
        print(identifier, len(animations), 'animations peintes', normalization, flush=True)
    (ROOT / 'docs/art/evolutions_catalogue.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n')
    # Grouper seulement les nouvelles formes près des Échos existants ; conserver
    # l'ordre des autres entrées et éviter le même point d'insertion que les autres lots.
    path = ROOT / 'assets/asset_manifest.json'
    manifest = json.loads(path.read_text())
    identifiers = {item['visual_id'] for item in catalog}
    added = {item['visual_id']: manifest['entries'][item['visual_id']] for item in catalog}
    ordered = {}
    for key, value in manifest['entries'].items():
        if key == 'enemy.skitterling':
            ordered.update(added)
        if key not in identifiers:
            ordered[key] = value
    assert identifiers.issubset(ordered)
    manifest['entries'] = ordered
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent='\t')+'\n')


if __name__ == '__main__':
    main(Path(sys.argv[1]))
